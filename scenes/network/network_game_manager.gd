## NetworkGameManager
## 游戏内多人同步管理器（AutoLoad: NetworkGameManager）
## 职责：match_config 接收后的整个游戏内同步生命周期
## 连接本身由 RoomManager 持有，本节点不创建/销毁 ENet peer。
extends Node

# ── 信号 ──────────────────────────────────────────────────────────────────────

## 所有客户端完成加载、游戏正式开始
signal match_started
## 服务端广播进球事件
signal goal_scored(scoring_team: int)
## 服务端广播比赛结束
signal match_ended(home_score: int, away_score: int)
## 通知 UI 层返回大厅
signal return_to_lobby_requested

# ── 常量 ──────────────────────────────────────────────────────────────────────

## 客户端发送输入快照的间隔（帧）
const INPUT_SEND_INTERVAL := 1
## 服务端发送球位置的间隔（帧）
const BALL_SYNC_INTERVAL := 2

# ── 运行时状态 ────────────────────────────────────────────────────────────────

## 当前比赛配置（由 RoomManager.match_config_received 写入）
var match_config: Dictionary = {}

## 本地玩家的 peer_id / team / slot（从 match_config 解析）
var local_peer_id: int = -1
var local_team: int = -1
var local_slot: int = -1

## 记录哪些 peer 已完成场景加载（服务端专用）
var _peers_loaded: Array[int] = []
## 比赛是否正在进行
var _match_running: bool = false

var _frame_counter: int = 0

# ── 生命周期 ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_process(false) # 仅在比赛进行时启用


func _process(_delta: float) -> void:
	_frame_counter += 1

	# 客户端每隔 INPUT_SEND_INTERVAL 帧上报一次输入
	if not multiplayer.is_server() and _frame_counter % INPUT_SEND_INTERVAL == 0:
		_send_local_input()

	# 服务端每隔 BALL_SYNC_INTERVAL 帧广播球的状态
	if multiplayer.is_server() and _frame_counter % BALL_SYNC_INTERVAL == 0:
		_broadcast_ball_state()


# ── 外部入口（由 OnlineTeamSelectionScreen._on_match_config_received 调用）────

## 初始化比赛上下文，然后通知服务端"本地已准备好加载"
func prepare_match(config: Dictionary, p_local_peer_id: int) -> void:
	match_config = config
	local_peer_id = p_local_peer_id

	# 从 assignments 中解析本地 team / slot
	for entry: Dictionary in config.get("assignments", []):
		if entry["peer_id"] == local_peer_id:
			local_team = entry["team"]
			local_slot = entry["slot"]
			break

	print("[NetworkGameManager] prepare_match: peer=%d team=%d slot=%d" % [
		local_peer_id, local_team, local_slot
	])

	# 告知服务端本地已就绪
	if multiplayer.is_server():
		_on_peer_scene_loaded(1)
	else:
		_rpc_scene_loaded.rpc_id(1)


# ── 场景加载同步 ──────────────────────────────────────────────────────────────

## 客户端 → 服务端：本地游戏场景加载完毕
@rpc("any_peer", "reliable")
func _rpc_scene_loaded() -> void:
	if not multiplayer.is_server():
		return
	_on_peer_scene_loaded(multiplayer.get_remote_sender_id())


func _on_peer_scene_loaded(peer_id: int) -> void:
	if peer_id not in _peers_loaded:
		_peers_loaded.append(peer_id)
		print("[Server] peer %d scene loaded (%d/%d)" % [
			peer_id,
			_peers_loaded.size(),
			match_config.get("assignments", []).size()
		])

	var total: int = match_config.get("assignments", []).size()
	if _peers_loaded.size() >= total:
		# 所有人都加载完毕，正式开始比赛
		_rpc_start_match.rpc()           # 广播给所有客户端
		_do_start_match()                 # 服务端自身也执行


## 服务端 → 所有人：正式开始比赛
@rpc("authority", "reliable", "call_remote")
func _rpc_start_match() -> void:
	_do_start_match()


func _do_start_match() -> void:
	_match_running = true
	_frame_counter = 0
	set_process(true)
	print("[NetworkGameManager] match started")
	match_started.emit()


# ── 输入同步（客户端 → 服务端 → 广播）───────────────────────────────────────

## 收集本地输入快照并发给服务端
## input_snapshot 格式：{ "move": Vector2, "shoot": bool, "pass": bool, "tackle": bool }
func _send_local_input() -> void:
	var snapshot := _collect_local_input()
	_rpc_recv_input.rpc_id(1, local_team, local_slot, snapshot)


func _collect_local_input() -> Dictionary:
	# TODO：接入实际 InputManager，目前返回空快照占位
	return {
		"move": Vector2.ZERO,
		"shoot": false,
		"pass": false,
		"tackle": false,
	}


## 客户端 → 服务端：上报输入
@rpc("any_peer", "unreliable")
func _rpc_recv_input(team: int, slot: int, snapshot: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	# TODO：写入服务端权威输入缓冲，由游戏逻辑消费
	_apply_player_input(multiplayer.get_remote_sender_id(), team, slot, snapshot)


func _apply_player_input(_peer_id: int, _team: int, _slot: int, _snapshot: Dictionary) -> void:
	# TODO：将输入转发给对应 Player 节点
	pass


# ── 球状态同步（服务端 → 所有人）─────────────────────────────────────────────

func _broadcast_ball_state() -> void:
	# TODO：从 Ball 节点读取 position / velocity
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	_rpc_sync_ball.rpc(ball_pos, ball_vel)


## 服务端 → 所有人：同步球的位置和速度
@rpc("authority", "unreliable")
func _rpc_sync_ball(_pos: Vector2, _vel: Vector2) -> void:
	if multiplayer.is_server():
		return
	# TODO：写入客户端 Ball 节点
	pass


# ── 进球事件（服务端判定 → 广播）────────────────────────────────────────────

## 由服务端游戏逻辑调用（如 Goal 区域检测到球入网）
func server_notify_goal(scoring_team: int) -> void:
	assert(multiplayer.is_server(), "server_notify_goal must be called on server")
	_rpc_on_goal_scored.rpc(scoring_team)
	_handle_goal(scoring_team)


@rpc("authority", "reliable")
func _rpc_on_goal_scored(scoring_team: int) -> void:
	_handle_goal(scoring_team)


func _handle_goal(scoring_team: int) -> void:
	print("[NetworkGameManager] goal scored by team %d" % scoring_team)
	goal_scored.emit(scoring_team)


# ── 比赛结束（服务端判定 → 广播）────────────────────────────────────────────

## 由服务端游戏逻辑调用（时间到 / 加时结束）
func server_end_match(home_score: int, away_score: int) -> void:
	assert(multiplayer.is_server(), "server_end_match must be called on server")
	_rpc_on_match_ended.rpc(home_score, away_score)
	_handle_match_end(home_score, away_score)


@rpc("authority", "reliable")
func _rpc_on_match_ended(home_score: int, away_score: int) -> void:
	_handle_match_end(home_score, away_score)


func _handle_match_end(home_score: int, away_score: int) -> void:
	_match_running = false
	set_process(false)
	print("[NetworkGameManager] match ended %d:%d" % [home_score, away_score])
	match_ended.emit(home_score, away_score)


# ── 返回大厅 ─────────────────────────────────────────────────────────────────

## 服务端通知所有人返回大厅（比赛结束后调用）
func server_request_return_to_lobby() -> void:
	assert(multiplayer.is_server())
	_rpc_return_to_lobby.rpc()
	_do_return_to_lobby()


@rpc("authority", "reliable")
func _rpc_return_to_lobby() -> void:
	_do_return_to_lobby()


func _do_return_to_lobby() -> void:
	_peers_loaded.clear()
	match_config = {}
	local_peer_id = -1
	local_team = -1
	local_slot = -1
	_frame_counter = 0
	return_to_lobby_requested.emit()
