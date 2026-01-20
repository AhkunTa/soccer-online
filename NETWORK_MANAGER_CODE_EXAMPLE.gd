# network/network_manager.gd
# NetworkManager 完整实现代码
# 这是一个可以直接使用的实现示例

class_name NetworkManager1

extends Node

# ============ 常量 ============
const SERVER_PORT := 9999
const MAX_PLAYERS := 10
const HEARTBEAT_INTERVAL := 5.0
const HEARTBEAT_TIMEOUT := 15.0

# ============ 枚举 ============
enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	CONNECTED_AS_SERVER,
	CONNECTED_AS_CLIENT
}

enum MessageType {
	# 连接相关
	PLAYER_JOIN,
	PLAYER_LEAVE,
	ASSIGN_ROLE,
	
	# 游戏状态
	GAME_START,
	GAME_END,
	GAME_STATE_UPDATE,
	
	# 玩家动作
	PLAYER_ACTION,
	PLAYER_POSITION,
	PLAYER_STATE_CHANGE,
	
	# 球的状态
	BALL_POSITION,
	BALL_STATE_CHANGE,
	GOAL_SCORED,
	
	# 其他
	PING,
	PONG
}

# ============ 信号 ============
signal connection_state_changed(new_state: ConnectionState)
signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal game_started
signal game_ended
signal message_received(message_type: MessageType, data: Dictionary)
signal server_error(error_message: String)

# ============ 变量 ============
var connection_state := ConnectionState.DISCONNECTED
var local_peer_id := 0
var is_server := false
var is_client := false

var connected_players: Dictionary = {}
var heartbeat_timers: Dictionary = {}
var heartbeat_check_timer := 0.0

# ============ 生命周期 ============
func _ready() -> void:
	name = "NetworkManager"
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	print("[NetworkManager] 初始化完成")

func _process(delta: float) -> void:
	if is_server:
		heartbeat_check_timer += delta
		if heartbeat_check_timer >= HEARTBEAT_INTERVAL:
			heartbeat_check_timer = 0.0
			_check_heartbeats()

# ============ 服务器相关 ============
func start_server(port: int = SERVER_PORT) -> bool:
	print("[NetworkManager] 启动服务器，端口: %d" % port)
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)
	
	if error != OK:
		var error_msg = "无法启动服务器: %s" % error_string(error)
		print("[NetworkManager] 错误: " + error_msg)
		server_error.emit(error_msg)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_client = false
	local_peer_id = 1
	
	_set_connection_state(ConnectionState.CONNECTED_AS_SERVER)
	print("[NetworkManager] 服务器启动成功")
	return true

# ============ 客户端相关 ============
func connect_to_server(server_ip: String, port: int = SERVER_PORT) -> bool:
	print("[NetworkManager] 连接到服务器: %s:%d" % [server_ip, port])
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(server_ip, port)
	
	if error != OK:
		var error_msg = "无法连接到服务器: %s" % error_string(error)
		print("[NetworkManager] 错误: " + error_msg)
		server_error.emit(error_msg)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_server = false
	is_client = true
	
	_set_connection_state(ConnectionState.CONNECTING)
	print("[NetworkManager] 正在连接...")
	return true

func disconnect_from_server() -> void:
	print("[NetworkManager] 断开连接")
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	
	connected_players.clear()
	heartbeat_timers.clear()
	is_server = false
	is_client = false
	local_peer_id = 0
	
	_set_connection_state(ConnectionState.DISCONNECTED)

# ============ 玩家管理 ============
func register_player(player_name: String, team: String = "") -> void:
	var player_info = {
		"peer_id": local_peer_id,
		"name": player_name,
		"team": team,
		"role": "",
		"position": Vector2.ZERO,
		"connected_at": Time.get_ticks_msec()
	}
	
	connected_players[local_peer_id] = player_info
	
	if is_client:
		rpc_id(1, "_on_player_registered", player_info)
	elif is_server:
		_broadcast_player_joined(player_info)

func get_player_info(peer_id: int) -> Dictionary:
	return connected_players.get(peer_id, {})

func get_all_players() -> Array:
	return connected_players.values()

func get_players_by_team(team: String) -> Array:
	return connected_players.values().filter(
		func(p): return p.get("team") == team
	)

func assign_player_role(peer_id: int, role: String) -> void:
	if connected_players.has(peer_id):
		connected_players[peer_id]["role"] = role
		rpc("_on_player_role_assigned", peer_id, role)

# ============ 消息系统 ============
func send_message(message_type: MessageType, data: Dictionary, target_peer_id: int = 0) -> void:
	var message = {
		"type": message_type,
		"data": data,
		"sender_id": local_peer_id,
		"timestamp": Time.get_ticks_msec()
	}
	
	if target_peer_id == 0:
		rpc("_on_message_received", message)
	else:
		rpc_id(target_peer_id, "_on_message_received", message)

@rpc("any_peer", "call_local")
func _on_message_received(message: Dictionary) -> void:
	var message_type = message.get("type")
	var data = message.get("data", {})
	
	print("[NetworkManager] 收到消息: %s from %d" % [MessageType.keys()[message_type], message.get("sender_id")])
	
	message_received.emit(message_type, data)

# ============ 心跳检测 ============
func send_heartbeat() -> void:
	if is_client:
		rpc_id(1, "_on_heartbeat_received", local_peer_id)
	elif is_server:
		for peer_id in connected_players.keys():
			if peer_id != 1:
				rpc_id(peer_id, "_on_heartbeat_received", 1)

@rpc("any_peer")
func _on_heartbeat_received(peer_id: int) -> void:
	heartbeat_timers[peer_id] = Time.get_ticks_msec()

func _check_heartbeats() -> void:
	var current_time = Time.get_ticks_msec()
	var timeout_ms = int(HEARTBEAT_TIMEOUT * 1000)
	
	for peer_id in heartbeat_timers.keys():
		var last_heartbeat = heartbeat_timers[peer_id]
		if current_time - last_heartbeat > timeout_ms:
			print("[NetworkManager] 玩家 %d 心跳超时，断开连接" % peer_id)
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)

# ============ 内部回调 ============
func _on_peer_connected(peer_id: int) -> void:
	print("[NetworkManager] 玩家连接: %d" % peer_id)
	heartbeat_timers[peer_id] = Time.get_ticks_msec()
	
	if is_server:
		rpc_id(peer_id, "_on_receive_player_list", connected_players)

func _on_peer_disconnected(peer_id: int) -> void:
	print("[NetworkManager] 玩家断开连接: %d" % peer_id)
	
	if connected_players.has(peer_id):
		connected_players.erase(peer_id)
	
	heartbeat_timers.erase(peer_id)
	player_disconnected.emit(peer_id)

func _on_connected_to_server() -> void:
	print("[NetworkManager] 已连接到服务器")
	local_peer_id = multiplayer.get_unique_id()
	_set_connection_state(ConnectionState.CONNECTED_AS_CLIENT)

func _on_connection_failed() -> void:
	print("[NetworkManager] 连接失败")
	server_error.emit("连接到服务器失败")
	_set_connection_state(ConnectionState.DISCONNECTED)

func _on_server_disconnected() -> void:
	print("[NetworkManager] 服务器断开连接")
	server_error.emit("服务器断开连接")
	_set_connection_state(ConnectionState.DISCONNECTED)

@rpc("any_peer")
func _on_player_registered(player_info: Dictionary) -> void:
	var peer_id = player_info.get("peer_id")
	connected_players[peer_id] = player_info
	
	if is_server:
		_broadcast_player_joined(player_info)
	
	player_connected.emit(peer_id, player_info)

@rpc("any_peer")
func _on_player_role_assigned(peer_id: int, role: String) -> void:
	if connected_players.has(peer_id):
		connected_players[peer_id]["role"] = role

@rpc("any_peer")
func _on_receive_player_list(player_list: Dictionary) -> void:
	connected_players = player_list.duplicate()
	print("[NetworkManager] 收到玩家列表: %d 个玩家" % connected_players.size())

func _broadcast_player_joined(player_info: Dictionary) -> void:
	rpc("_on_player_joined_broadcast", player_info)

@rpc("any_peer", "call_local")
func _on_player_joined_broadcast(player_info: Dictionary) -> void:
	var peer_id = player_info.get("peer_id")
	if not connected_players.has(peer_id):
		connected_players[peer_id] = player_info
		player_connected.emit(peer_id, player_info)

# ============ 工具方法 ============
func _set_connection_state(new_state: ConnectionState) -> void:
	if connection_state != new_state:
		connection_state = new_state
		connection_state_changed.emit(new_state)

func get_connection_state_name() -> String:
	return ConnectionState.keys()[connection_state]

# func is_connected() -> bool:
# 	return connection_state in [
# 		ConnectionState.CONNECTED_AS_SERVER,
# 		ConnectionState.CONNECTED_AS_CLIENT
# 	]

func get_peer_count() -> int:
	return connected_players.size()

func get_local_peer_id() -> int:
	return local_peer_id

func is_local_server() -> bool:
	return is_server
