# 联机同步重构专项计划

## 一、当前架构概述

服务端权威 + 客户端镜像状态机 + 快照插值。
- 服务端：跑物理、AI、碰撞判定，广播快照(20Hz unreliable) + 状态切换(reliable RPC)
- 客户端：接收快照做插值，接收 RPC 做状态切换，跑 visual_process（动画/特效）


## 二、问题清单

### P0 — 球闪烁/抖动

**现象**：球在飞行过程中前后闪烁，位置不稳定。

**原因**：
1. 固定延迟缓冲插值的边界情况：`render_time` 超过最新快照时，降级到 `_apply_snapshot_direct` 直接跳到快照位置，下一帧又回到插值路径，位置在两条路径间跳变。
2. 快照频率 20Hz（50ms/帧），渲染 60Hz（16ms/帧），两个快照之间有 3 帧没有新数据，插值 t 值推进到 1.0 后球停住，新快照到来后又跳到新位置。
3. `_apply_snapshot_direct` 里直接写 `ball.position = b["pos"]`，没有平滑过渡。

**涉及文件**：
- `scenes/network/sync_manager.gd` — `_client_interpolate_remote_entities()`, `_apply_snapshot_direct()`

**修复方向**：
- `render_time` 超过最新快照时，用最近两个快照做外推（extrapolate），t 允许超过 1.0（最多 2.0）
- `_apply_snapshot_direct` 改为 lerp 平滑而不是直接赋值
- 或者去掉固定延迟缓冲，改为简单的"最近两个快照插值"模式


### P0 — 绝招动画在客户端只播一瞬间

**现象**：客户端收到绝招状态后动画播放一下就消失，球以 FREEFORM 的 roll 动画飞向球门。

**原因**：
服务端绝招进球后立刻切 FREEFORM（`goal.gd` → `on_ball_enter_back_net`），reliable RPC 到达客户端时球视觉上还在半路（因为快照插值有延迟），客户端收到 FREEFORM 后状态切换，绝招动画被覆盖。

**涉及文件**：
- `scenes/goal/goal.gd` — `on_ball_enter_back_net()`
- `scenes/network/sync_manager.gd` — `_rpc_sync_ball_state()`

**修复方向**：
- 方案 A：进球后服务端延迟切 FREEFORM（比如 500ms），让绝招动画有时间在客户端播完
- 方案 B：客户端收到 FREEFORM 时，如果当前是绝招状态，延迟执行状态切换（等球视觉位置到达球门区域）
- 方案 C：进球后球不切 FREEFORM，保持绝招状态飞入球网，由 `team_reset` 统一重置


### P0 — 高亮特效残留

**现象**：绝招结束后球的高亮颜色没有恢复。

**原因**：
`BallStatePowerShotStrong` 的 `visual_process` 每帧调 `add_highlight_effect()` 修改 `sprite.modulate`。状态切换时旧状态 `queue_free()` 是异步的，`_exit_tree` 在帧末才执行 `remove_highlight_effect()`。但在帧末之前，旧状态的 `visual_process` 还跑了一次，又把颜色改回高亮。`_exit_tree` 执行后恢复，但如果新状态的 `on_enter_visual` 没有重置颜色，可能出现残留。

**涉及文件**：
- `scenes/ball/ball_states/ball_state_power_shot_normal.gd` — `_exit_tree()`, `visual_process()`
- `scenes/ball/ball_states/ball_state_power_shot_strong.gd` — `is_height_light_effect()`
- `scenes/ball/ball_states/ball_state_power_shot_curve.gd` — `visual_process()`, `_exit_tree()`
- `scenes/ball/ball_states/ball_state_power_shot_highlight.gd` — `visual_process()`, `_exit_tree()`

**修复方向**：
- 在 `Ball._do_switch_state` 里切换状态时主动重置 `sprite.modulate = Color(1,1,1,1)`，不依赖旧状态的 `_exit_tree`
- 或者在 `BallState` 基类的 `_exit_tree` 里统一调 `remove_highlight_effect()`


### P1 — 客户端 `on_enter_logic` 不应该执行

**现象**：客户端切换到绝招状态时，`on_enter_logic` 里访问 `carrier`（为 null），需要每个绝招状态单独加 `if carrier == null` 保护。

**原因**：
`BallState._enter_tree` 里 `on_enter_visual` 和 `on_enter_logic` 都执行。客户端不需要跑 `on_enter_logic`（物理初始化），velocity/height 已由 RPC extra 设置。

**涉及文件**：
- `scenes/ball/ball_states/ball_state.gd` — `_enter_tree()`
- `scenes/ball/ball_states/ball_state_power_shot_normal.gd` — `on_enter_logic()`
- `scenes/ball/ball_states/ball_state_power_shot_highlight.gd` — `on_enter_logic()`
- `scenes/ball/ball_states/ball_state_power_shot_curve.gd` — `on_enter_logic()`
- `scenes/ball/ball_states/ball_state_power_shot_jump.gd` — `on_enter_logic()`
- `scenes/ball/ball_states/ball_state_power_shot_invisible.gd` — `on_enter_logic()`

**修复方向**：
在 `BallState._enter_tree` 里加 `if SyncManager.is_client(): return` 跳过 `on_enter_logic`，去掉每个子类里的 `if carrier == null` 保护。保持 `on_enter_visual` 两端都执行。


### P1 — `BallStateCarried.visual_process` 客户端动画缺失

**现象**：客户端球被持有时没有滚动动画，因为 `visual_process` 有 `is_client()` 保护直接 return。

**原因**：
`BallStateCarried.visual_process` 里根据 `carrier.velocity` 更新动画（roll/idle），但客户端 carrier 可能为 null 或 velocity 不准确。当前直接跳过导致动画不更新。

**涉及文件**：
- `scenes/ball/ball_states/ball_state_carried.gd` — `visual_process()`

**修复方向**：
客户端 CARRIED 状态下，球跟随 carrier 位置（由快照驱动），动画可以根据快照里的 carrier velocity 更新。去掉 `is_client()` 保护，改为 `if carrier == null: return`。


### P1 — `BallStatePowerShotInvisible` 客户端隐形效果不工作

**现象**：客户端隐形射门时球不会消失/出现。

**原因**：
`_update_visibility()` 在 `physics_process` 里调用，客户端不跑 `physics_process`，所以隐形效果不执行。`_update_visibility` 是纯视觉逻辑（修改 `sprite.modulate.a`），应该在 `visual_process` 里执行。

另外客户端 `target_goal` 为 null（`on_enter_logic` 里 carrier 为 null 时没有设置 `target_goal`），`_update_visibility` 里 `if target_goal == null: return` 直接跳过。

**涉及文件**：
- `scenes/ball/ball_states/ball_state_power_shot_invisible.gd` — `physics_process()`, `on_enter_logic()`

**修复方向**：
- `_update_visibility()` 移到 `visual_process` 里
- 客户端 `on_enter_logic` 里从球的速度方向推算 target_goal（或者在 RPC extra 里传 target_goal 位置）


### P1 — 玩家状态里的 `ball_detection_area.body_entered` 在客户端也触发

**现象**：客户端的 `PlayerStateJumpingShot`、`PlayerStateBicycleKick`、`PlayerStateHeader`、`PlayerStateVolleyKick` 里 `on_enter_logic` 连接了 `ball_detection_area.body_entered`，客户端球位置由快照驱动移动，可能触发 Area2D 碰撞信号。

**原因**：
`PlayerState._enter_tree` 里 `_is_remote_on_client()` 只对 `ONLINE_REMOTE` 和 `CPU` 返回 true，`ONLINE_LOCAL` 的玩家在客户端会执行 `on_enter_logic`，连接 `body_entered` 信号。虽然 `ball.shoot()` 有 `is_client()` 保护不会执行，但 `AudioPlayer.play(POWERSHOT)` 会在客户端重复播放。

**涉及文件**：
- `scenes/characters/player_state_jumping_shot.gd` — `on_enter_logic()`, `_on_ball_entered()`
- `scenes/characters/player_state_bicycle_kick.gd` — `on_enter_logic()`, `_on_ball_entered()`
- `scenes/characters/player_state_header.gd` — `on_enter_logic()`, `_on_ball_entered()`
- `scenes/characters/player_state_volley_kick.gd` — `on_enter_logic()`, `_on_ball_entered()`

**修复方向**：
在 `_on_ball_entered` 回调里加 `if SyncManager.is_client(): return`，或者客户端不连接 `body_entered` 信号。


### P1 — `PlayerStateHurt.on_enter_logic` 客户端执行了物理逻辑

**现象**：客户端本地玩家受伤时，`on_enter_logic` 里设置了 `player.height_velocity` 和 `player.height`。

**原因**：
`ONLINE_LOCAL` 玩家在客户端 `_is_remote_on_client()` 返回 false，所以 `on_enter_logic` 会执行。虽然 `ball.tumble()` 有 `is_client()` 保护，但 `player.height_velocity = HURT_HEIGHT_VELOCITY` 和 `player.height = 0.1` 在客户端也执行了，可能和快照数据冲突。

**涉及文件**：
- `scenes/characters/player_state_hurt.gd` — `on_enter_logic()`

**修复方向**：
`ONLINE_LOCAL` 玩家的物理属性（height, height_velocity）应该由快照和解驱动，`on_enter_logic` 里的物理初始化在联机模式下应该跳过。


### P2 — 快照和 RPC 的 `"st"` 字段职责重叠

**现象**：快照里带了 `ball["st"]` 球状态枚举，插值代码用它判断"状态不一致时只平滑位置"。但球状态切换完全由 reliable RPC 驱动，快照的 `"st"` 和 RPC 的到达时序不一致。

**原因**：
unreliable 快照可能比 reliable RPC 先到或后到。如果快照先到且 `st` 已经变了，插值代码进入"状态不一致"分支只做轻微平滑，球位置更新变慢。如果 RPC 先到，客户端状态已经切换，但快照的 `st` 还是旧值，又进入不一致分支。

**涉及文件**：
- `scenes/network/sync_manager.gd` — `_client_interpolate_remote_entities()`, `_collect_world_snapshot()`

**修复方向**：
- 方案 A：去掉快照里的 `"st"` 字段，插值始终正常执行，不做状态一致性判断
- 方案 B：保留 `"st"` 但只用于 debug，不影响插值逻辑


### P2 — 本地玩家预测没有回滚机制

**现象**：本地玩家操作有时会"拉回去"，手感不好。

**原因**：
`_reconcile_local_player` 只做简单的 lerp 和解（偏差超阈值就拉回 50%），没有保存输入历史和重放。服务端确认的位置和客户端预测的位置有偏差时，玩家会看到角色被拉回。

**涉及文件**：
- `scenes/network/sync_manager.gd` — `_reconcile_local_player()`

**修复方向**：
- 短期：调大 `RECONCILIATION_THRESHOLD`（当前 3px），减少和解频率
- 长期：保存输入历史，收到服务端确认后回滚到服务端位置并重放未确认的输入


### P2 — `BallStateFreeForm.on_player_enter` 客户端设置了 carrier

**现象**：客户端球进入 FREEFORM 后，`player_detection_area.body_entered` 信号在客户端也触发，`on_player_enter` 里 `ball.carrier = body` 在客户端执行了。

**原因**：
虽然 `state_transition_requested.emit(CARRIED)` 有 `is_client()` 保护不会触发状态切换，但 `ball.carrier = body` 和 `body.control_ball()` 在客户端也执行了，可能和快照里的 carrier 数据冲突。

**涉及文件**：
- `scenes/ball/ball_states/ball_state_freeform.gd` — `on_player_enter()`

**修复方向**：
客户端不应该自己设置 `ball.carrier`，carrier 应该完全由快照驱动。在 `on_player_enter` 开头加 `if SyncManager.is_client(): return`。


### P2 — `GameStateInPlay.on_team_scored` 客户端也会触发

**现象**：`GameStateInPlay._enter_tree` 连接了 `GameEvents.team_scored`，客户端也连接了。

**原因**：
`GameEvents.team_scored` 在 `goal.gd` 的 `on_ball_enter_scoring_area` 里发出，有 `is_client()` 保护，客户端不会发出。但如果未来有其他地方发出这个信号（没有保护），客户端就会触发 `on_team_scored` → `transition_state(SCORED)` → `GameManager.switch_state` 里有 `is_online() and not is_server(): return` 保护，不会执行。

**涉及文件**：
- `scenes/game_manager/game_state/game_state_in_play.gd` — `_enter_tree()`, `on_team_scored()`

**修复方向**：
当前有保护，暂不需要修改。但建议在 `on_team_scored` 里加 `if SyncManager.is_client(): return` 作为防御性编程。


### P2 — `GameEvents.impact_received` 在客户端触发暂停

**现象**：`GameManager.on_impact_received` 里 `get_tree().paused = true`，客户端也会执行。

**原因**：
`GameEvents.impact_received` 在多个地方发出：
- `ball_state_shot.gd` 的 `on_enter_visual` — 两端都执行
- `ball_state_power_shot_rising.gd` 的 `on_enter_visual` — 两端都执行
`GameManager.on_impact_received` 收到后暂停游戏树，客户端也暂停了。服务端和客户端的暂停时机不同步。

**涉及文件**：
- `scenes/game_manager/game_manager.gd` — `on_impact_received()`
- `scenes/ball/ball_states/ball_state_shot.gd` — `on_enter_visual()`
- `scenes/ball/ball_states/ball_state_power_shot_rising.gd` — `on_enter_visual()`

**修复方向**：
联机模式下不在客户端暂停游戏树，或者暂停由服务端 RPC 统一控制。


### P3 — `PlayerStateShooting.on_animation_complete` 客户端时序问题

**现象**：客户端和服务端的射门动画播放速度可能不同（帧率差异），`on_animation_complete` 触发时机不一致。

**原因**：
客户端 `PlayerStateShooting.on_animation_complete` 里 `transition_state(MOVING)` 会在客户端执行（`ONLINE_LOCAL` 玩家），但服务端可能还没播完动画，两边的玩家状态不同步。虽然服务端会广播正确的状态，但中间有短暂的不一致。

**涉及文件**：
- `scenes/characters/player_state_shooting.gd` — `on_animation_complete()`

**修复方向**：
客户端 `ONLINE_LOCAL` 玩家的状态切换也应该等服务端 RPC，不自己 `transition_state`。或者接受这个短暂不一致（服务端 RPC 会很快纠正）。


## 三、修复优先级排序

| 优先级 | 问题 | 影响 | 工作量 |
|--------|------|------|--------|
| P0 | 球闪烁/抖动 | 视觉体验极差 | 中 |
| P0 | 绝招动画一瞬间消失 | 核心玩法体验 | 小 |
| P0 | 高亮特效残留 | 视觉 bug | 小 |
| P1 | 客户端 on_enter_logic 不应执行 | 架构清晰度 | 小 |
| P1 | CARRIED 状态客户端动画缺失 | 视觉体验 | 小 |
| P1 | 隐形射门客户端不工作 | 功能缺失 | 中 |
| P1 | 玩家状态 body_entered 客户端重复触发 | 音效重复 | 小 |
| P1 | PlayerStateHurt 客户端物理冲突 | 潜在 bug | 小 |
| P2 | 快照 st 字段职责重叠 | 架构清晰度 | 小 |
| P2 | 本地玩家预测无回滚 | 手感 | 大 |
| P2 | FREEFORM on_player_enter 客户端设 carrier | 数据冲突 | 小 |
| P2 | impact_received 客户端暂停 | 时序不同步 | 小 |
| P3 | 射门动画完成时序不一致 | 短暂不一致 | 中 |


## 四、核心原则（重构时遵循）

1. **客户端只跑视觉**：`on_enter_visual` + `visual_process` 两端执行，`on_enter_logic` + `physics_process` 只在服务端执行
2. **状态切换只由 RPC 驱动**：客户端不自己触发 `switch_state`/`state_transition_requested`
3. **快照只同步连续量**：位置、速度、高度、carrier，不触发状态切换
4. **RPC 只同步离散事件**：状态切换、射门、传球、进球
5. **`on_enter_visual` 负责初始动画**：状态进入时一次性设置，不依赖 `visual_process` 每帧更新
6. **`visual_process` 里的每帧动画更新**：只在服务端执行（FREEFORM 的 roll 动画除外，因为客户端需要根据快照 velocity 更新方向）
7. **所有球操作方法（shoot/tumble/pass_to）在客户端直接 return**：已实现
8. **GameEvents 信号在客户端的处理**：涉及状态切换的回调加 `is_client()` 保护