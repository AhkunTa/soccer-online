## SyncManager — 联机对战同步管理器 (Autoload)
##
## 职责：
##   1. 比赛生命周期管理（场景加载同步、开始、结束、返回大厅）
##   2. 输入上行：客户端采集 InputSnapshot → 发送到服务器
##   3. 世界快照下行：服务器收集 WorldSnapshot → 广播到客户端
##   4. 关键事件 RPC：射门、传球、进球等 reliable 事件
##   5. 客户端插值：远程实体平滑显示
##
## 连接本身由 RoomManager 持有，本节点不创建/销毁 ENet peer。
extends Node

# ── 信号 ──────────────────────────────────────────────────────────────────────

## 所有客户端完成加载、游戏正式开始
signal match_started
## 服务端广播进球事件
signal goal_scored(country_scored_on: String)
## 服务端广播比赛结束
signal match_ended(home_score: int, away_score: int)
## 通知 UI 层返回大厅
signal return_to_lobby_requested

# ── 常量 ──────────────────────────────────────────────────────────────────────

## 服务器每隔多少物理帧广播一次世界快照 (60Hz / 2 = 30Hz)
const SNAPSHOT_INTERVAL := 2
## 客户端插值系数
const INTERPOLATION_FACTOR := 0.4
## 服务器和解位置偏差阈值（像素）
const RECONCILIATION_THRESHOLD := 10.0
## 客户端持球显示偏移，和 BallStateCarried 的服务端逻辑保持一致
const CARRIED_BALL_OFFSET := Vector2(10, -10)
const CARRIED_BALL_DRIBBLE_FREQUENCY := 10.0
const CARRIED_BALL_DRIBBLE_INTENSITY := 3.0

# ── 运行时状态 ────────────────────────────────────────────────────────────────

## 是否处于联机比赛中
var is_online_match: bool = false

## 当前比赛配置（由 RoomManager.match_config_received 写入）
var match_config: Dictionary = {}

## 本地玩家信息（从 match_config 解析）
var local_peer_id: int = -1
var local_team: int = -1
var local_slot: int = -1

## 服务器物理帧计数器
var server_tick: int = 0

## 比赛是否正在进行
var _match_running: bool = false

## 记录哪些 peer 已完成场景加载（服务端专用）
var _peers_loaded: Array[int] = []

# ── 游戏实体引用（由 ActorsContainer 在 _ready 时注入）────────────────────────

## 所有玩家的有序数组：home[0-5] + away[6-11]
var all_players: Array[Player] = []
## 球引用
var ball: Ball = null

# ── 服务端：输入缓冲 ─────────────────────────────────────────────────────────

## peer_id → 最新 InputSnapshot（服务端每物理帧消费）
var _pending_inputs: Dictionary = {}

# ── 客户端：快照缓冲 ─────────────────────────────────────────────────────────

## 最近收到的世界快照（带时间戳，用于固定延迟插值）
var _snapshot_buffer: Array[Dictionary] = []
## 固定渲染延迟（毫秒）
const RENDER_DELAY_MS := 50
## 快照短暂中断时允许的最大外推时长（毫秒）
const MAX_EXTRAPOLATION_MS := 100

# ── 生命周期 ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_physics_process(false)
	# 确保 SyncManager 的 _process 在其他节点之前执行（设置 velocity/heading 后 PlayerState 才读取）
	process_priority = -10
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)


func _on_multiplayer_peer_disconnected(peer_id: int) -> void:
	on_peer_disconnected(peer_id)


func _physics_process(_delta: float) -> void:
	if not _match_running:
		return

	server_tick += 1

	if multiplayer.is_server():
		_server_tick()
	else:
		_client_tick()


# ══════════════════════════════════════════════════════════════════════════════
# 比赛生命周期
# ══════════════════════════════════════════════════════════════════════════════

## 外部入口：由 OnlineTeamSelectionScreen._on_match_config_received 调用
## 初始化比赛上下文，通知服务端本地已准备好加载
func prepare_match(config: Dictionary, p_local_peer_id: int) -> void:
	match_config = config
	local_peer_id = p_local_peer_id
	is_online_match = true

	# 从 assignments 中解析本地 team / slot
	for entry: Dictionary in config.get("assignments", []):
		if entry["peer_id"] == local_peer_id:
			local_team = entry["team"]
			local_slot = entry["slot"]
			break

	print("[SyncManager] prepare_match: peer=%d team=%d slot=%d" % [
		local_peer_id, local_team, local_slot
	])
	# 注意：不在这里发送 scene_loaded，等 WorldScreen._ready() 调用 notify_scene_loaded()


## 由 ActorsContainer._ready() 调用，注入游戏实体引用
func register_game_entities(players: Array[Player], game_ball: Ball) -> void:
	all_players = players
	ball = game_ball
	print("[SyncManager] registered %d players + ball" % players.size())


## 由 WorldScreen._ready() 调用，通知服务端本地场景加载完毕
func notify_scene_loaded() -> void:
	if multiplayer.is_server():
		_on_peer_scene_loaded(1)
	else:
		_rpc_scene_loaded.rpc_id(1)


## 客户端 → 服务端：本地游戏场景加载完毕
@rpc("any_peer", "reliable")
func _rpc_scene_loaded() -> void:
	if not multiplayer.is_server():
		return
	_on_peer_scene_loaded(multiplayer.get_remote_sender_id())


func _on_peer_scene_loaded(peer_id: int) -> void:
	if peer_id not in _peers_loaded:
		_peers_loaded.append(peer_id)
	var total: int = match_config.get("assignments", []).size()
	print("[SyncManager] peer %d loaded (%d/%d)" % [peer_id, _peers_loaded.size(), total])
	if _peers_loaded.size() >= total:
		# 所有人都加载完毕，正式开始比赛
		_rpc_start_match.rpc()
		_do_start_match()


## 服务端 → 所有客户端：正式开始比赛
@rpc("authority", "reliable", "call_remote")
func _rpc_start_match() -> void:
	_do_start_match()


func _do_start_match() -> void:
	_match_running = true
	server_tick = 0
	_snapshot_buffer.clear()
	_pending_inputs.clear()
	set_physics_process(true)
	print("[SyncManager] match started (is_server=%s)" % str(multiplayer.is_server()))
	match_started.emit()


# ══════════════════════════════════════════════════════════════════════════════
# 服务端 Tick
# ══════════════════════════════════════════════════════════════════════════════

func _server_tick() -> void:
	# 1. 消费所有待处理的客户端输入
	_server_consume_inputs()

	# 2. 每 SNAPSHOT_INTERVAL 帧广播一次世界快照
	if server_tick % SNAPSHOT_INTERVAL == 0:
		_server_broadcast_snapshot()


## 将 pending inputs 应用到对应的 Player
func _server_consume_inputs() -> void:
	for peer_id: int in _pending_inputs:
		var snapshot: Dictionary = (_pending_inputs[peer_id] as Dictionary).duplicate()
		var player := _find_player_by_peer(peer_id)
		if player == null:
			continue
		# 注入输入到 KeyUtils 供 PlayerStateMoving 消费
		KeyUtils.inject_network_input(player.network_index, snapshot)
		_clear_consumed_input_edges(peer_id)
	# 不清空方向/按住态——保留最新输入直到下一帧覆盖（应对丢包）


func _clear_consumed_input_edges(peer_id: int) -> void:
	if not _pending_inputs.has(peer_id):
		return
	var snapshot: Dictionary = _pending_inputs[peer_id]
	snapshot["sh_jp"] = false
	snapshot["sh_jr"] = false
	snapshot["pa_jp"] = false
	snapshot["jmp"] = false
	_pending_inputs[peer_id] = snapshot


## 收集世界快照并广播给所有客户端
func _server_broadcast_snapshot() -> void:
	if all_players.is_empty() or ball == null:
		return

	var snapshot := _collect_world_snapshot()
	# 广播给所有非服务器 peer
	for peer_id: int in multiplayer.get_peers():
		_rpc_receive_snapshot.rpc_id(peer_id, snapshot)


func _collect_world_snapshot() -> Dictionary:
	var players_data: Array[Dictionary] = []
	for player: Player in all_players:
		players_data.append({
			"pos": player.position,
			"vel": player.velocity,
			"hdg": player.heading,
			"hgt": player.height,
			"st": player.current_state_enum,
			"hp": player.current_hp,
		})

	var carrier_index := -1
	if ball.carrier != null:
		carrier_index = all_players.find(ball.carrier)

	return {
		"tick": server_tick,
		"ts": Time.get_ticks_msec(),
		"tl": GameManager.time_left,
		"ball": {
			"pos": ball.position,
			"vel": ball.velocity,
			"hgt": ball.height,
			"hv": ball.height_velocity,
			"st": ball.current_state_enum,
			"ci": carrier_index,
		},
		"players": players_data,
	}


# ══════════════════════════════════════════════════════════════════════════════
# 客户端 Tick
# ══════════════════════════════════════════════════════════════════════════════

func _client_tick() -> void:
	# 输入比快照更吃响应，尤其是松开方向键和 just_pressed/just_released 边沿。
	_client_send_input()


## 客户端插值在 _process 中执行（更平滑，不受物理帧率限制）
func _process(delta: float) -> void:
	if not _match_running or multiplayer.is_server():
		return
	_client_interpolate_remote_entities(delta)


## 采集本地输入并发送到服务器
func _client_send_input() -> void:
	var snapshot := _collect_local_input()
	_rpc_send_input.rpc_id(1, snapshot)


func _collect_local_input() -> Dictionary:
	# 根据本地玩家的实际控制方案采集输入
	var scheme := Player.ControlScheme.P1
	for player in all_players:
		if player.owner_peer_id == local_peer_id:
			scheme = player.control_scheme
			break

	KeyUtils._init_dicts()
	var direction := KeyUtils.get_input_vector(scheme)

	# 根据控制方案选择正确的 action 名称前缀
	var prefix := "p1" if scheme == Player.ControlScheme.P1 or scheme == Player.ControlScheme.ONLINE_LOCAL else "p2"
	var shoot_pressed := KeyUtils.is_action_pressed(scheme, KeyUtils.Action.SHOOT)
	var pass_pressed := KeyUtils.is_action_pressed(scheme, KeyUtils.Action.PASS)
	var shoot_just_pressed := Input.is_action_just_pressed(prefix + "_shoot")
	var shoot_just_released := Input.is_action_just_released(prefix + "_shoot")
	var pass_just_pressed := Input.is_action_just_pressed(prefix + "_pass")
	var jump_held := shoot_pressed and pass_pressed
	var jump_just_pressed := jump_held and (shoot_just_pressed or pass_just_pressed)

	return {
		"tick": server_tick,
		"dir": direction,
		"sh_p": shoot_pressed,
		"sh_jp": shoot_just_pressed and not jump_held,
		"sh_jr": shoot_just_released,
		"pa_jp": pass_just_pressed and not jump_held,
		"jmp": jump_just_pressed,
		"jmp_h": jump_held,
		"sh_dir": direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO,
	}


## 固定延迟缓冲插值：渲染时间 = 当前时间 - RENDER_DELAY_MS
## 在缓冲区里找到渲染时间点前后的两个快照做插值
func _client_interpolate_remote_entities(_delta: float) -> void:
	if _snapshot_buffer.is_empty():
		return
	if _snapshot_buffer.size() < 2:
		_apply_snapshot_direct(_snapshot_buffer[-1])
		return

	var render_time := Time.get_ticks_msec() - RENDER_DELAY_MS

	# 在缓冲区里找 render_time 前后的快照
	var prev: Dictionary = {}
	var next: Dictionary = {}
	var is_extrapolating := false
	for snap in _snapshot_buffer:
		var ts: int = snap.get("recv_ts", 0)
		if ts <= render_time:
			prev = snap
		elif next.is_empty():
			next = snap
			break

	if prev.is_empty():
		prev = _snapshot_buffer[0]
		next = _snapshot_buffer[1]
	elif next.is_empty():
		prev = _snapshot_buffer[-2]
		next = _snapshot_buffer[-1]
		is_extrapolating = true

	var prev_ts: int = prev.get("recv_ts", 0)
	var next_ts: int = next.get("recv_ts", 0)
	var span := next_ts - prev_ts
	var t := 0.0
	if span > 0:
		var max_t := 1.0
		if is_extrapolating:
			max_t += float(MAX_EXTRAPOLATION_MS) / float(span)
		t = clampf(float(render_time - prev_ts) / float(span), 0.0, max_t)

	# 插值远程玩家
	var prev_players: Array = prev["players"]
	var next_players: Array = next["players"]
	for i in range(mini(all_players.size(), mini(prev_players.size(), next_players.size()))):
		var player := all_players[i]
		var p_next: Dictionary = next_players[i]
		if player.owner_peer_id == local_peer_id:
			_reconcile_local_player(player, p_next)
			continue
		# 远程玩家：插值位置
		var p_prev: Dictionary = prev_players[i]
		player.position = (p_prev["pos"] as Vector2).lerp(p_next["pos"] as Vector2, t)
		player.velocity = p_next["vel"]
		player.heading = p_next["hdg"]
		player.height = lerpf(p_prev["hgt"], p_next["hgt"], t)
		player.current_hp = p_next["hp"]
		_apply_snapshot_player_state(player, p_next, false)
		if player.current_state_enum == Player.State.MOVING:
			player.set_movement_animation()
		player.flip_sprites()

	# 球：非持有状态由快照驱动；持有状态跟随当前显示中的 carrier，避免慢一拍。
	if ball != null:
		var b_prev: Dictionary = prev["ball"]
		var b_next: Dictionary = next["ball"]
		ball.velocity = b_next["vel"]
		ball.height_velocity = b_next["hv"]

		# carrier 同步
		var ci: int = b_next.get("ci", -1)
		if ci >= 0 and ci < all_players.size():
			ball.carrier = all_players[ci]
		elif ci == -1:
			ball.carrier = null
		_apply_snapshot_ball_state(b_next)
		if ball.carrier != null:
			_apply_carried_ball_visual_position()
		else:
			ball.position = (b_prev["pos"] as Vector2).lerp(b_next["pos"] as Vector2, t)
			ball.height = lerpf(b_prev["hgt"], b_next["hgt"], t)

	# 同步剩余时间
	GameManager.time_left = next["tl"]


## 直接应用快照（缓冲不足时的降级处理）
func _apply_snapshot_direct(snap: Dictionary) -> void:
	var snap_players: Array = snap["players"]
	for i in range(mini(all_players.size(), snap_players.size())):
		var player := all_players[i]
		var p: Dictionary = snap_players[i]
		if player.owner_peer_id == local_peer_id:
			_reconcile_local_player(player, p)
			continue
		player.position = p["pos"]
		player.velocity = p["vel"]
		player.heading = p["hdg"]
		player.height = p["hgt"]
		player.current_hp = p["hp"]
		_apply_snapshot_player_state(player, p, false)
		if player.current_state_enum == Player.State.MOVING:
			player.set_movement_animation()
		player.flip_sprites()

	if ball != null:
		var b: Dictionary = snap["ball"]
		ball.velocity = b["vel"]
		ball.height_velocity = b["hv"]
		var ci: int = b.get("ci", -1)
		ball.carrier = all_players[ci] if ci >= 0 and ci < all_players.size() else null
		_apply_snapshot_ball_state(b)
		if ball.carrier != null:
			_apply_carried_ball_visual_position()
		else:
			ball.position = ball.position.lerp(b["pos"] as Vector2, INTERPOLATION_FACTOR)
			ball.height = lerpf(ball.height, b["hgt"], INTERPOLATION_FACTOR)

	GameManager.time_left = snap["tl"]


## 本地玩家和解：比较服务器位置与预测位置
func _reconcile_local_player(player: Player, server_data: Dictionary) -> void:
	var server_pos: Vector2 = server_data["pos"]
	var error := player.position.distance_to(server_pos)
	if error > RECONCILIATION_THRESHOLD:
		player.position = player.position.lerp(server_pos, 0.5)
	var server_height: float = server_data.get("hgt", player.height)
	if absf(player.height - server_height) > 0.5:
		player.height = lerpf(player.height, server_height, 0.35)


## 客户端：用世界快照里的状态做兜底，避免 reliable 状态 RPC 时序异常后长期卡旧状态。
func _apply_snapshot_player_state(player: Player, snapshot_data: Dictionary, allow_local: bool) -> void:
	if not snapshot_data.has("st"):
		return
	if not allow_local and player.owner_peer_id == local_peer_id:
		return
	var state_value: int = snapshot_data.get("st", -1)
	if state_value < 0:
		return
	_apply_remote_player_state(player, state_value)


## 客户端：用球快照里的状态做兜底。状态细节仍以 reliable RPC 为准。
func _apply_snapshot_ball_state(ball_data: Dictionary) -> void:
	if ball == null or not ball_data.has("st"):
		return
	var state_value: int = ball_data.get("st", -1)
	if state_value < 0 or ball.current_state_enum == state_value:
		return
	var state: Ball.State = state_value as Ball.State
	var data := BallStateData.build()
	var power := maxf((ball_data.get("vel", Vector2.ZERO) as Vector2).length(), 150.0)
	var height: float = ball_data.get("hgt", ball.height)
	data.set_shot_normal_data(height, power, Ball.PowerShotType.NORMAL)
	ball._do_switch_state(state, data)


## 客户端持球状态下，球按当前画面中的持球人显示，不再显示延迟快照里的球位置。
func _apply_carried_ball_visual_position() -> void:
	var carrier := ball.carrier
	if carrier == null:
		return
	var vx := 0.0
	if carrier.velocity != Vector2.ZERO and carrier.velocity.x != 0:
		var time := Time.get_ticks_msec() / 1000.0
		vx = cos(CARRIED_BALL_DRIBBLE_FREQUENCY * time) * CARRIED_BALL_DRIBBLE_INTENSITY
	ball.position = carrier.position + Vector2(
		vx + carrier.heading.x * CARRIED_BALL_OFFSET.x,
		carrier.heading.y * CARRIED_BALL_OFFSET.y
	)
	ball.height = carrier.height
	ball.velocity = carrier.velocity
	ball.height_velocity = carrier.height_velocity
	if ball.current_state != null:
		ball.current_state.carrier = carrier

## 客户端：根据快照中的状态枚举同步远程玩家的状态
func _apply_remote_player_state(player: Player, remote_state: int) -> void:
	var state := remote_state as Player.State
	if player.current_state_enum == state:
		return
	match state:
		Player.State.SHOOTING:
			player.switch_state(state, PlayerStateData.build().set_shot_direction(player.heading))
		Player.State.HURT:
			player.switch_state(state, PlayerStateData.build().set_hurt_direction(Vector2.ZERO))
		Player.State.RESETTING:
			player.switch_state(state, PlayerStateData.build().set_reset_position(player.spawn_position))
		_:
			player.switch_state(state)


# ══════════════════════════════════════════════════════════════════════════════
# 输入 RPC（客户端 → 服务端）
# ══════════════════════════════════════════════════════════════════════════════

## 客户端每物理帧发送输入快照
@rpc("any_peer", "unreliable")
func _rpc_send_input(snapshot: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_pending_inputs[sender_id] = snapshot


# ══════════════════════════════════════════════════════════════════════════════
# 世界快照 RPC（服务端 → 客户端）
# ══════════════════════════════════════════════════════════════════════════════

## 服务端广播世界快照
@rpc("authority", "unreliable")
func _rpc_receive_snapshot(snapshot: Dictionary) -> void:
	if multiplayer.is_server():
		return
	var local_snapshot := snapshot.duplicate(true)
	local_snapshot["recv_ts"] = Time.get_ticks_msec()
	_snapshot_buffer.append(local_snapshot)
	# 保持缓冲区大小（保留足够覆盖 RENDER_DELAY_MS 的快照）
	# 30Hz 快照约 33ms/帧，50ms 延迟需要约 3 个快照，保留 8 个作为余量
	while _snapshot_buffer.size() > 8:
		_snapshot_buffer.pop_front()


# ══════════════════════════════════════════════════════════════════════════════
# 关键事件 RPC（reliable）
# ══════════════════════════════════════════════════════════════════════════════

# ── 射门 ─────────────────────────────────────────────────────────────────────

## 客户端请求射门（蓄力释放时调用）
func request_shoot(direction: Vector2, power: float) -> void:
	if multiplayer.is_server():
		_server_handle_shoot(local_peer_id, direction, power)
	else:
		_rpc_request_shoot.rpc_id(1, direction, power)


@rpc("any_peer", "reliable")
func _rpc_request_shoot(direction: Vector2, power: float) -> void:
	if not multiplayer.is_server():
		return
	_server_handle_shoot(multiplayer.get_remote_sender_id(), direction, power)


func _server_handle_shoot(peer_id: int, direction: Vector2, power: float) -> void:
	var player := _find_player_by_peer(peer_id)
	if player == null or ball.carrier != player:
		return
	# 服务器执行射门
	ball.shoot(direction * power, -1.0, power)
	# 广播给所有客户端
	var player_idx := all_players.find(player)
	_rpc_notify_shoot.rpc(player_idx, direction, power)


## 服务端 → 所有客户端：射门事件通知
@rpc("authority", "reliable")
func _rpc_notify_shoot(player_idx: int, direction: Vector2, power: float) -> void:
	if multiplayer.is_server():
		return
	if player_idx < 0 or player_idx >= all_players.size():
		return
	var player := all_players[player_idx]
	# 客户端播放射门动画（球位置由快照驱动）
	player.switch_state(Player.State.SHOOTING,
		PlayerStateData.build().set_shot_direction(direction).set_shot_power(power))
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT)

# ── 传球 ─────────────────────────────────────────────────────────────────────

## 客户端请求传球
func request_pass(destination: Vector2) -> void:
	if multiplayer.is_server():
		_server_handle_pass(local_peer_id, destination)
	else:
		_rpc_request_pass.rpc_id(1, destination)


@rpc("any_peer", "reliable")
func _rpc_request_pass(destination: Vector2) -> void:
	if not multiplayer.is_server():
		return
	_server_handle_pass(multiplayer.get_remote_sender_id(), destination)


func _server_handle_pass(peer_id: int, destination: Vector2) -> void:
	var player := _find_player_by_peer(peer_id)
	if player == null or ball.carrier != player:
		return
	ball.pass_to(destination)
	var player_idx := all_players.find(player)
	_rpc_notify_pass.rpc(player_idx)


@rpc("authority", "reliable")
func _rpc_notify_pass(player_idx: int) -> void:
	if multiplayer.is_server():
		return
	if player_idx < 0 or player_idx >= all_players.size():
		return
	var player := all_players[player_idx]
	player.switch_state(Player.State.PASSING)
	# 球位置由快照驱动，这里不调用 ball.pass_to()

# ── 玩家状态同步（即时 reliable）─────────────────────────────────────────────

## 服务端广播玩家状态切换（由 Player.switch_state 调用）
func server_sync_player_state(player_idx: int, state: Player.State) -> void:
	if not multiplayer.is_server():
		return
	print("[SyncManager] 广播玩家状态: idx=%d state=%d" % [player_idx, int(state)])
	_rpc_sync_player_state.rpc(player_idx, int(state))


@rpc("authority", "reliable")
func _rpc_sync_player_state(player_idx: int, state_value: int) -> void:
	if multiplayer.is_server():
		return
	if player_idx < 0 or player_idx >= all_players.size():
		return
	var player := all_players[player_idx]
	var state: Player.State = state_value as Player.State
	print("[SyncManager] 接受玩家状态: idx=%d state=%d current=%d" % [player_idx, state_value, player.current_state_enum])
	if player.current_state_enum == state:
		return
	_apply_remote_player_state(player, state)

# ── 球状态同步（即时 reliable）────────────────────────────────────────────────

## 服务端广播球状态切换（由 Ball.switch_state 调用）
func server_sync_ball_state(state: Ball.State, data: BallStateData) -> void:
	if not multiplayer.is_server():
		return
	print("[SyncManager] 广播足球状态: %d" % int(state))
	# 附带当前球的速度和高度，客户端用于初始化本地物理
	var extra := {
		"vel": ball.velocity if ball != null else Vector2.ZERO,
		"hgt": ball.height if ball != null else 0.0,
		"hv": ball.height_velocity if ball != null else 0.0,
	}
	_rpc_sync_ball_state.rpc(int(state), data.to_dict(), extra)


@rpc("authority", "reliable")
func _rpc_sync_ball_state(state_value: int, data_dict: Dictionary, extra: Dictionary) -> void:
	if multiplayer.is_server():
		return
	if ball == null:
		return
	var state: Ball.State = state_value as Ball.State
	var data := BallStateData.from_dict(data_dict)
	print("[SyncManager] 接受足球状态： %d" % state_value)
	# 先设置速度/高度，确保本地物理有正确的初始值
	ball.velocity = extra.get("vel", Vector2.ZERO)
	ball.height = extra.get("hgt", 0.0)
	ball.height_velocity = extra.get("hv", 0.0)
	ball._do_switch_state(state, data)


# ══════════════════════════════════════════════════════════════════════════════
# 游戏状态同步 RPC（服务端 → 客户端）
# ══════════════════════════════════════════════════════════════════════════════

## 服务端广播 GameManager 状态切换
func server_sync_game_state(state: GameManager.State, data_dict: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_rpc_sync_game_state.rpc(int(state), data_dict)


@rpc("authority", "reliable")
func _rpc_sync_game_state(state_value: int, data_dict: Dictionary) -> void:
	if multiplayer.is_server():
		return
	var state: GameManager.State = state_value as GameManager.State
	var data := GameStateData.build()
	if data_dict.has("country_scored_on"):
		data.set_country_scored_on(data_dict["country_scored_on"])
	GameManager._do_switch_state(state, data)


## 服务端广播比分变更
func server_sync_score(country_scored_on: String) -> void:
	if not multiplayer.is_server():
		return
	_rpc_sync_score.rpc(country_scored_on)


@rpc("authority", "reliable")
func _rpc_sync_score(country_scored_on: String) -> void:
	if multiplayer.is_server():
		return
	GameManager.current_match.increase_score(country_scored_on)
	GameEvents.score_changed.emit()


# ══════════════════════════════════════════════════════════════════════════════
# 进球事件（服务端判定 → 广播）
# ══════════════════════════════════════════════════════════════════════════════

## 由服务端游戏逻辑调用（Goal 区域检测到球入网）
func server_notify_goal(country_scored_on: String) -> void:
	assert(multiplayer.is_server(), "server_notify_goal must be called on server")
	print("[SyncManager] goal: %s scored on" % country_scored_on)
	goal_scored.emit(country_scored_on)
	# 比分和状态切换由 GameManager 处理，这里仅广播
	server_sync_score(country_scored_on)


# ══════════════════════════════════════════════════════════════════════════════
# 比赛结束（服务端判定 → 广播）
# ══════════════════════════════════════════════════════════════════════════════

func server_end_match(home_score: int, away_score: int) -> void:
	assert(multiplayer.is_server(), "server_end_match must be called on server")
	_rpc_on_match_ended.rpc(home_score, away_score)
	_handle_match_end(home_score, away_score)


@rpc("authority", "reliable")
func _rpc_on_match_ended(home_score: int, away_score: int) -> void:
	_handle_match_end(home_score, away_score)


func _handle_match_end(home_score: int, away_score: int) -> void:
	_match_running = false
	set_physics_process(false)
	print("[SyncManager] match ended %d:%d" % [home_score, away_score])
	match_ended.emit(home_score, away_score)


# ══════════════════════════════════════════════════════════════════════════════
# 返回大厅
# ══════════════════════════════════════════════════════════════════════════════

func server_request_return_to_lobby() -> void:
	assert(multiplayer.is_server())
	_rpc_return_to_lobby.rpc()
	_do_return_to_lobby()


@rpc("authority", "reliable")
func _rpc_return_to_lobby() -> void:
	_do_return_to_lobby()


func _do_return_to_lobby() -> void:
	reset_state()
	return_to_lobby_requested.emit()


# ══════════════════════════════════════════════════════════════════════════════
# 断线处理
# ══════════════════════════════════════════════════════════════════════════════

## 服务端：玩家断线时将其控制的 Player 切换为 CPU AI 接管
func on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server() or not _match_running:
		return
	for player: Player in all_players:
		if player.owner_peer_id == peer_id:
			player.owner_peer_id = -1
			player.control_scheme = Player.ControlScheme.CPU
			player.set_control_texture()
			print("[SyncManager] peer %d disconnected, player %s → CPU" % [peer_id, player.fullname])
	_pending_inputs.erase(peer_id)


# ══════════════════════════════════════════════════════════════════════════════
# 工具方法
# ══════════════════════════════════════════════════════════════════════════════

## 根据 peer_id 查找其控制的 Player
func _find_player_by_peer(peer_id: int) -> Player:
	for player: Player in all_players:
		if player.owner_peer_id == peer_id:
			return player
	return null


## 根据 network_index 查找 Player
func get_player_by_index(index: int) -> Player:
	if index >= 0 and index < all_players.size():
		return all_players[index]
	return null


## 重置所有同步状态（比赛结束或返回大厅时调用）
func reset_state() -> void:
	_match_running = false
	is_online_match = false
	match_config = {}
	local_peer_id = -1
	local_team = -1
	local_slot = -1
	server_tick = 0
	_peers_loaded.clear()
	_pending_inputs.clear()
	_snapshot_buffer.clear()
	all_players.clear()
	ball = null
	set_physics_process(false)


## 判断当前是否为联机模式且比赛正在进行
func is_match_running() -> bool:
	return is_online_match and _match_running

## 便捷判断：当前是否为联机服务端
func is_server() -> bool:
	return is_online_match and multiplayer.is_server()

## 便捷判断：当前是否为联机客户端
func is_client() -> bool:
	return is_online_match and not multiplayer.is_server()
