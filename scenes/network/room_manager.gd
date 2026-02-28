extends Node

signal room_list_updated(rooms: Array)
signal room_created(room_id: int)
signal room_joined(room_id: int)
signal connection_status_changed(status: String)
signal connection_failed
signal server_disconnected
signal error_occurred(message: String)

const PORT := 7000
const MAX_CONNECTIONS := 20

enum State {OFFLINE, HOSTING, CONNECTED}

var state: State = State.OFFLINE
var rooms_cache: Array = []
var my_room_id: int = -1

# Server-only
var _rooms: Dictionary = {}
var _next_room_id: int = 1
var _player_room: Dictionary = {}


func _ready() -> void:
	print("[RoomManager] _ready called, DisplayServer=%s, feature:server=%s" % [
		DisplayServer.get_name(), str(OS.has_feature("server"))
	])
	# 三种方式均可触发专用服务器模式：
	# 1. --headless        导出后真实无头运行（云服务器）
	# 2. 特性标签 "server"  编辑器多实例测试（Customize Run Instances → 特性标签填 server）
	# 3. --server          命令行手动指定
	var is_dedicated: bool = DisplayServer.get_name() == "headless" \
		or OS.has_feature("server") \
		or "--server" in OS.get_cmdline_args()
	if is_dedicated:
		print("[Server] Dedicated server mode — starting on port %d" % PORT)
		var err := start_as_host()
		if err != OK:
			print("[Server] Failed to bind port %d, error: %d" % [PORT, err])
			get_tree().quit(1)


func start_as_host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CONNECTIONS)
	if err != OK:
		error_occurred.emit("Failed to start server (port %d may be in use)" % PORT)
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(func(id: int) -> void:
		print("[Server] peer_connected: id=%d" % id))
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	state = State.HOSTING
	connection_status_changed.emit("Hosting on port %d" % PORT)
	print("[Server] ENet server bound on port %d, max_conn=%d" % [PORT, MAX_CONNECTIONS])
	return OK


func connect_to_host(ip: String) -> Error:
	print("[Client] connect_to_host called, ip=%s port=%d" % [ip, PORT])
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	print("[Client] create_client result: %d (OK=0)" % err)
	if err != OK:
		error_occurred.emit("Cannot connect to %s" % ip)
		return err
	# 先挂信号，再赋值 peer，避免信号在赋值后立刻触发时被遗漏
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.multiplayer_peer = peer
	print("[Client] peer assigned, peer_id=%d, waiting for connected/failed signal..." % multiplayer.get_unique_id())
	connection_status_changed.emit("Connecting to %s..." % ip)
	return OK


func disconnect_network() -> void:
	_try_disconnect(multiplayer.peer_disconnected, _on_peer_disconnected)
	_try_disconnect(multiplayer.server_disconnected, _on_server_disconnected)
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	state = State.OFFLINE
	rooms_cache.clear()
	my_room_id = -1
	_rooms.clear()
	_player_room.clear()
	_next_room_id = 1
	connection_status_changed.emit("Offline")


func _try_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func request_rooms(filter: String = "") -> void:
	if state == State.OFFLINE:
		return
	if multiplayer.is_server():
		_deliver_room_list(1, filter)
	else:
		_rpc_request_rooms.rpc_id(1, filter)


func create_room(title: String, max_players: int) -> void:
	if state == State.OFFLINE:
		return
	if multiplayer.is_server():
		_server_create_room(1, title, max_players)
	else:
		_rpc_create_room.rpc_id(1, title, max_players)


func join_room(room_id: int) -> void:
	if state == State.OFFLINE:
		return
	if multiplayer.is_server():
		_server_join_room(1, room_id)
	else:
		_rpc_join_room.rpc_id(1, room_id)


# ── Client → Server RPCs ─────────────────────────────────────────────────────

@rpc("any_peer", "reliable")
func _rpc_request_rooms(filter: String) -> void:
	if not multiplayer.is_server():
		return
	_deliver_room_list(multiplayer.get_remote_sender_id(), filter)


@rpc("any_peer", "reliable")
func _rpc_create_room(title: String, max_players: int) -> void:
	if not multiplayer.is_server():
		return
	_server_create_room(multiplayer.get_remote_sender_id(), title, max_players)


@rpc("any_peer", "reliable")
func _rpc_join_room(room_id: int) -> void:
	if not multiplayer.is_server():
		return
	_server_join_room(multiplayer.get_remote_sender_id(), room_id)


# ── Server logic ─────────────────────────────────────────────────────────────

func _deliver_room_list(requester_id: int, filter: String) -> void:
	var result: Array = []
	for room_id: int in _rooms:
		var room: Dictionary = _rooms[room_id]
		if filter.is_empty() or room["title"].to_lower().contains(filter.to_lower()):
			result.append({
				"id": room_id,
				"title": room["title"],
				"players": room["players"].size(),
				"max_players": room["max_players"]
			})
	if requester_id == 1:
		_local_receive_room_list(result)
	else:
		_rpc_recv_room_list.rpc_id(requester_id, result)


func _server_create_room(creator_id: int, title: String, max_players: int) -> void:
	if _player_room.has(creator_id):
		_remove_player_from_room(creator_id)
	var room_id := _next_room_id
	_next_room_id += 1
	_rooms[room_id] = {"title": title, "max_players": max_players, "players": [creator_id]}
	_player_room[creator_id] = room_id
	if creator_id == 1:
		_local_room_created(room_id)
	else:
		_rpc_recv_room_created.rpc_id(creator_id, room_id)
	_broadcast_room_update()


func _server_join_room(joiner_id: int, room_id: int) -> void:
	if not _rooms.has(room_id):
		if joiner_id != 1:
			_rpc_recv_error.rpc_id(joiner_id, "Room does not exist")
		return
	var room: Dictionary = _rooms[room_id]
	if room["players"].size() >= room["max_players"]:
		if joiner_id != 1:
			_rpc_recv_error.rpc_id(joiner_id, "Room is full")
		return
	if _player_room.has(joiner_id):
		_remove_player_from_room(joiner_id)
	room["players"].append(joiner_id)
	_player_room[joiner_id] = room_id
	if joiner_id == 1:
		_local_room_joined(room_id)
	else:
		_rpc_recv_room_joined.rpc_id(joiner_id, room_id)
	_broadcast_room_update()


func _remove_player_from_room(peer_id: int) -> void:
	if not _player_room.has(peer_id):
		return
	var room_id: int = _player_room[peer_id]
	_player_room.erase(peer_id)
	if _rooms.has(room_id):
		_rooms[room_id]["players"].erase(peer_id)
		if _rooms[room_id]["players"].is_empty():
			_rooms.erase(room_id)
	_broadcast_room_update()


## 向所有已连接的 peer 广播最新房间列表（不含搜索过滤）
func _broadcast_room_update() -> void:
	var result: Array = []
	for room_id: int in _rooms:
		var room: Dictionary = _rooms[room_id]
		result.append({
			"id": room_id,
			"title": room["title"],
			"players": room["players"].size(),
			"max_players": room["max_players"]
		})
	# 推送给服务端自身（如果服务端也在显示大厅）
	if state == State.HOSTING:
		_local_receive_room_list(result)
	# 推送给所有客户端
	for peer_id: int in multiplayer.get_peers():
		_rpc_recv_room_list.rpc_id(peer_id, result)


# ── Server → Client RPCs ──────────────────────────────────────────────────────

@rpc("authority", "reliable")
func _rpc_recv_room_list(rooms: Array) -> void:
	_local_receive_room_list(rooms)


@rpc("authority", "reliable")
func _rpc_recv_room_created(room_id: int) -> void:
	_local_room_created(room_id)


@rpc("authority", "reliable")
func _rpc_recv_room_joined(room_id: int) -> void:
	_local_room_joined(room_id)


@rpc("authority", "reliable")
func _rpc_recv_error(message: String) -> void:
	error_occurred.emit(message)


# ── Local handlers ────────────────────────────────────────────────────────────

func _local_receive_room_list(rooms: Array) -> void:
	rooms_cache = rooms
	room_list_updated.emit(rooms_cache)


func _local_room_created(room_id: int) -> void:
	my_room_id = room_id
	room_created.emit(room_id)


func _local_room_joined(room_id: int) -> void:
	my_room_id = room_id
	room_joined.emit(room_id)


# ── Multiplayer event handlers ────────────────────────────────────────────────

func _on_connected_to_server() -> void:
	print("[RoomManager] connected_to_server fired, peer id=", multiplayer.get_unique_id())
	state = State.CONNECTED
	connection_status_changed.emit("Connected")
	request_rooms()


func _on_connection_failed() -> void:
	print("[RoomManager] connection_failed fired — server unreachable or refused")
	state = State.OFFLINE
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_status_changed.emit("Connection failed")
	error_occurred.emit("Could not connect to server")
	connection_failed.emit()


func _on_server_disconnected() -> void:
	state = State.OFFLINE
	rooms_cache.clear()
	my_room_id = -1
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_status_changed.emit("Server disconnected")
	server_disconnected.emit()


func _on_peer_disconnected(peer_id: int) -> void:
	_remove_player_from_room(peer_id)
