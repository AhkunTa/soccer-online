extends Node

signal room_list_updated(rooms: Array[RoomData])
signal room_created(room_id: int)
signal room_joined(room_id: int)
signal connection_status_changed(status: String)
signal connection_failed
signal server_disconnected
signal error_occurred(message: String)
# 联机队伍选择相关信号
signal room_ready(room_id: int, player_ids: Array)
signal team_selection_updated(selections: Array)
signal match_config_received(config: Dictionary)

const PORT := 7000
const MAX_CONNECTIONS := 20

enum State {OFFLINE, HOSTING, CONNECTED}

var state: State = State.OFFLINE
var rooms_cache: Array[RoomData] = []
var my_room_id: int = -1
## 本地玩家当前所在房间（加入或创建后自动更新，离开后置 null）
var current_room: RoomData = null
## 本地玩家昵称（upload_player_name 时同步保存）
var local_player_name: String = ""

# Server-only
var _rooms: Dictionary = {}
var _next_room_id: int = 1
var _player_room: Dictionary = {}
# 队伍选择阶段：room_id → Array[{ peer_id, name, team, slot, is_ready, country }]
var _team_selections: Dictionary = {}
# 玩家信息（服务端专用）：peer_id → { "name": String }
var _player_info: Dictionary = {}


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
	_player_info[1] = {"name": "Host"}  # 初始化服务端自身
	multiplayer.peer_connected.connect(func(id: int) -> void:
		print("[Server] peer_connected: id=%d" % id)
		_player_info[id] = {"name": "P%d" % id})  # 默认昵称，等待客户端上传覆盖
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
	current_room = null
	_rooms.clear()
	_player_room.clear()
	_player_info.clear()
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
	var result: Array[Dictionary] = []
	for room_id: int in _rooms:
		var room: Dictionary = _rooms[room_id]
		if filter.is_empty() or room["title"].to_lower().contains(filter.to_lower()):
			var player_list: Array = []
			for pid: int in room["players"]:
				player_list.append({"peer_id": pid, "name": get_player_name(pid)})
			result.append({
				"id": room_id,
				"title": room["title"],
				"current_players": room["players"].size(),
				"max_players": room["max_players"],
				"host_name": get_player_name(room.get("host_id", 0)),
				"status": room.get("status", "waiting"),
				"players": player_list,
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
	_rooms[room_id] = {"title": title, "max_players": max_players, "players": [creator_id], "host_id": creator_id, "status": "waiting"}
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
	if room.get("status", "waiting") != "waiting":
		if joiner_id != 1:
			_rpc_recv_error.rpc_id(joiner_id, "Room is not open for joining")
		return
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
	# 人数为偶数且 >= 2 时进入队伍选择阶段
	var players: Array = room["players"]
	if players.size() >= room["max_players"] and players.size() % 2 == 0:
		print("[Server] Room %d reached player count %d, starting team selection" % [room_id, players.size()])
		_server_start_team_selection(room_id)


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
	var result: Array[Dictionary] = []
	for room_id: int in _rooms:
		var room: Dictionary = _rooms[room_id]
		var player_list: Array = []
		for pid: int in room["players"]:
			player_list.append({"peer_id": pid, "name": get_player_name(pid)})
		result.append({
			"id": room_id,
			"title": room["title"],
			"current_players": room["players"].size(),
			"max_players": room["max_players"],
			"host_name": get_player_name(room.get("host_id", 0)),
			"status": room.get("status", "waiting"),
			"players": player_list,
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
	rooms_cache.clear()
	for d: Dictionary in rooms:
		rooms_cache.append(RoomData.from_dict(d))
	# 同步更新当前房间数据（人数、状态等可能变化）
	if my_room_id != -1:
		for r: RoomData in rooms_cache:
			if r.id == my_room_id:
				current_room = r
				break
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
	_player_info.erase(peer_id)


# ── 玩家信息 ──────────────────────────────────────────────────────────────────

## 获取昵称（服务端有完整数据；客户端返回默认值）
func get_player_name(peer_id: int) -> String:
	if _player_info.has(peer_id):
		return _player_info[peer_id]["name"]
	return "P%d" % peer_id


## 客户端上传自己的昵称（连接后自动调用，也可由 UI 主动调用覆盖）
func upload_player_name(name: String) -> void:
	local_player_name = name
	if multiplayer.is_server():
		_server_store_player_info(1, name)
	else:
		_rpc_upload_player_info.rpc_id(1, name)


@rpc("any_peer", "reliable")
func _rpc_upload_player_info(name: String) -> void:
	if not multiplayer.is_server():
		return
	_server_store_player_info(multiplayer.get_remote_sender_id(), name)


func _server_store_player_info(peer_id: int, name: String) -> void:
	if _player_info.has(peer_id):
		_player_info[peer_id]["name"] = name
	else:
		_player_info[peer_id] = {"name": name}
	# 若该玩家已在某个房间，广播更新让所有客户端看到最新名字
	if _player_room.has(peer_id):
		_broadcast_room_update()


# ── 队伍选择：服务端逻辑 ──────────────────────────────────────────────────────

## 初始化该房间的队伍选择状态，并广播 room_ready 给房间内所有玩家
func _server_start_team_selection(room_id: int) -> void:
	var room: Dictionary = _rooms[room_id]
	room["status"] = "in_selection"
	var players: Array = room["players"]
	# 初始化每位玩家的选择状态（team=-1 表示未选，slot=-1 表示未选）
	var selections: Array = []
	for pid: int in players:
		selections.append({"peer_id": pid, "name": get_player_name(pid), "team": -1, "slot": -1, "is_ready": false, "country": ""})
	_team_selections[room_id] = selections
	# 广播给房间内所有客户端
	for pid: int in players:
		if pid == 1:
			_local_room_ready(room_id, players)
		else:
			_rpc_recv_room_ready.rpc_id(pid, room_id, players)


## Client → Server：玩家请求选择队伍 (team: 0=Home, 1=Away)
@rpc("any_peer", "reliable")
func _rpc_select_team(team: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_server_select_team(sender_id, team)


func _server_select_team(peer_id: int, team: int) -> void:
	if not _player_room.has(peer_id):
		return
	var room_id: int = _player_room[peer_id]
	if not _team_selections.has(room_id):
		return
	var selections: Array = _team_selections[room_id]
	for entry: Dictionary in selections:
		if entry["peer_id"] == peer_id:
			entry["team"] = team
			entry["slot"] = -1 # 换队时清空 slot
			break
	_broadcast_team_selection(room_id)


## Client → Server：玩家请求占用 slot
@rpc("any_peer", "reliable")
func _rpc_select_slot(slot: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_server_select_slot(sender_id, slot)


func _server_select_slot(peer_id: int, slot: int) -> void:
	if not _player_room.has(peer_id):
		return
	var room_id: int = _player_room[peer_id]
	if not _team_selections.has(room_id):
		return
	var selections: Array = _team_selections[room_id]
	# 找到当前玩家的 team
	var my_team := -1
	for entry: Dictionary in selections:
		if entry["peer_id"] == peer_id:
			my_team = entry["team"]
			break
	if my_team == -1:
		return # 还没选队伍，忽略
	# 检查该 slot 是否已被同队其他人占用
	for entry: Dictionary in selections:
		if entry["peer_id"] != peer_id and entry["team"] == my_team and entry["slot"] == slot:
			# slot 冲突，拒绝
			if peer_id != 1:
				_rpc_recv_error.rpc_id(peer_id, "Slot already taken")
			return
	# 写入 slot
	for entry: Dictionary in selections:
		if entry["peer_id"] == peer_id:
			entry["slot"] = slot
			break
	_broadcast_team_selection(room_id)


## Client → Server：玩家确认就绪
@rpc("any_peer", "reliable")
func _rpc_confirm_ready() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_server_confirm_ready(sender_id)


func _server_confirm_ready(peer_id: int) -> void:
	if not _player_room.has(peer_id):
		return
	var room_id: int = _player_room[peer_id]
	if not _team_selections.has(room_id):
		return
	var selections: Array = _team_selections[room_id]
	for entry: Dictionary in selections:
		if entry["peer_id"] == peer_id:
			# 必须已选队伍和 slot 才能就绪
			if entry["team"] == -1 or entry["slot"] == -1:
				if peer_id != 1:
					_rpc_recv_error.rpc_id(peer_id, "Select team and player slot first")
				return
			entry["is_ready"] = true
			break
	_broadcast_team_selection(room_id)
	# 检查所有人是否就绪
	var all_ready := true
	for entry: Dictionary in selections:
		if not entry["is_ready"]:
			all_ready = false
			break
	if all_ready:
		_server_launch_match(room_id)


## 所有人就绪后构建 match_config 并广播
func _server_launch_match(room_id: int) -> void:
	var room: Dictionary = _rooms[room_id]
	room["status"] = "in_game"
	var selections: Array = _team_selections[room_id]
	# 从 selections 中提取 home/away 国家（取各队第一个非空 country）
	var home_country := ""
	var away_country := ""
	for entry: Dictionary in selections:
		var c: String = entry.get("country", "")
		if c == "":
			continue
		if entry["team"] == 0 and home_country == "":
			home_country = c
		elif entry["team"] == 1 and away_country == "":
			away_country = c
	var config: Dictionary = {
		"room_id": room_id,
		"assignments": selections,
		"home_country": home_country,
		"away_country": away_country,
	}
	for pid: int in room["players"]:
		if pid == 1:
			_local_match_config(config)
		else:
			_rpc_recv_match_config.rpc_id(pid, config)
	_team_selections.erase(room_id)


## 向房间内所有人广播当前选择快照
func _broadcast_team_selection(room_id: int) -> void:
	if not _rooms.has(room_id) or not _team_selections.has(room_id):
		return
	var selections: Array = _team_selections[room_id]
	for pid: int in _rooms[room_id]["players"]:
		if pid == 1:
			_local_team_selection_updated(selections)
		else:
			_rpc_recv_team_selection.rpc_id(pid, selections)


# ── 队伍选择：Server → Client RPCs ───────────────────────────────────────────

@rpc("authority", "reliable")
func _rpc_recv_room_ready(room_id: int, player_ids: Array) -> void:
	_local_room_ready(room_id, player_ids)


@rpc("authority", "reliable")
func _rpc_recv_team_selection(selections: Array) -> void:
	_local_team_selection_updated(selections)


@rpc("authority", "reliable")
func _rpc_recv_match_config(config: Dictionary) -> void:
	_local_match_config(config)


# ── 队伍选择：客户端 API（供 OnlineTeamSelectionScreen 调用）──────────────────

## 本地玩家选择队伍
func select_team(team: int) -> void:
	if multiplayer.is_server():
		_server_select_team(1, team)
	else:
		_rpc_select_team.rpc_id(1, team)


## Client → Server：玩家请求选择国家
@rpc("any_peer", "reliable")
func _rpc_select_country(country: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_server_select_country(sender_id, country)


func _server_select_country(peer_id: int, country: String) -> void:
	if not _player_room.has(peer_id):
		return
	var room_id: int = _player_room[peer_id]
	if not _team_selections.has(room_id):
		return
	var selections: Array = _team_selections[room_id]
	for entry: Dictionary in selections:
		if entry["peer_id"] == peer_id:
			entry["country"] = country
			break
	_broadcast_team_selection(room_id)


## 本地玩家选择国家
func select_country(country: String) -> void:
	if multiplayer.is_server():
		_server_select_country(1, country)
	else:
		_rpc_select_country.rpc_id(1, country)


## 本地玩家选择球员 slot
func select_slot(slot: int) -> void:
	if multiplayer.is_server():
		_server_select_slot(1, slot)
	else:
		_rpc_select_slot.rpc_id(1, slot)


## 本地玩家确认就绪
func confirm_ready() -> void:
	if multiplayer.is_server():
		_server_confirm_ready(1)
	else:
		_rpc_confirm_ready.rpc_id(1)


# ── 队伍选择：本地 handlers ───────────────────────────────────────────────────

func _local_room_ready(room_id: int, player_ids: Array) -> void:
	room_ready.emit(room_id, player_ids)


func _local_team_selection_updated(selections: Array) -> void:
	team_selection_updated.emit(selections)


func _local_match_config(config: Dictionary) -> void:
	match_config_received.emit(config)
