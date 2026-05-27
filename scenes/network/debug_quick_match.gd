## DebugQuickMatch — 跳过大厅/选队 UI，快速进入联机对战
##
## 用法：
##   1. 确保已在 project.godot [autoload] 中注册
##   2. 修改下方 ROLE 常量：
##      - "server" → 该实例作为服务端（自动 host + 等待客户端）
##      - "client" → 该实例作为客户端（自动连接 SERVER_IP）
##      - "off"    → 禁用，走正常大厅流程
##   3. 先启动 server 实例，再启动 client 实例
##   4. 测试完毕后改回 "off"
extends Node

# ══════════════════════════════════════════════════════════════════════════════
# 配置区 — 修改这里切换角色
# ══════════════════════════════════════════════════════════════════════════════

## 是否启用 debug 快速联机
const ENABLED := false

## 客户端连接的服务端 IP
const SERVER_IP := "127.0.0.1"

## 默认国家
const HOME_COUNTRY := "ARGENTINA"
const AWAY_COUNTRY := "USA"

## 服务端玩家 slot（0-5，对应球队中的第几个球员）
const SERVER_SLOT := 5
## 客户端玩家 slot
const CLIENT_SLOT := 5

# ══════════════════════════════════════════════════════════════════════════════

var _client_peer_id := -1
var _started := false

func _ready() -> void:
	if not ENABLED:
		return
	# 通过 Godot 编辑器 Customize Run Instances 的特性标签区分角色：
	#   实例 1: 特性标签填 "server"
	#   实例 2: 特性标签填 "client"
	var is_server := OS.has_feature("server")
	var is_client := OS.has_feature("client")
	if not is_server and not is_client:
		return
	print("[DebugQuickMatch] feature server=%s client=%s" % [is_server, is_client])
	if is_server:
		_setup_server()
	elif is_client:
		_setup_client()


func _setup_server() -> void:
	# RoomManager._ready() 中 is_dedicated 检测可能没触发，手动 host
	if RoomManager.state != RoomManager.State.HOSTING:
		var err := RoomManager.start_as_host()
		if err != OK:
			push_error("[DebugQuickMatch] Failed to host: %d" % err)
			return
	multiplayer.peer_connected.connect(_on_server_peer_connected)
	print("[DebugQuickMatch] Server waiting for client on port %d..." % RoomManager.PORT)


func _on_server_peer_connected(peer_id: int) -> void:
	if _started:
		return
	_started = true
	_client_peer_id = peer_id
	print("[DebugQuickMatch] Client connected: peer_id=%d" % peer_id)
	# 延迟 2 帧确保客户端 autoload 都 ready
	get_tree().create_timer(0.1).timeout.connect(_server_start_match)


func _server_start_match() -> void:
	var config := {
		"room_id": 999,
		"home_country": HOME_COUNTRY,
		"away_country": AWAY_COUNTRY,
		"field_seed": GameManager.randomize_field_seed(),
		"assignments": [
			{
				"peer_id": 1,
				"name": "Server",
				"team": 0,
				"slot": SERVER_SLOT,
				"is_ready": true,
				"country": HOME_COUNTRY,
			},
			{
				"peer_id": _client_peer_id,
				"name": "Client",
				"team": 1,
				"slot": CLIENT_SLOT,
				"is_ready": true,
				"country": AWAY_COUNTRY,
			},
		],
	}
	print("[DebugQuickMatch] Server: sending match config and entering game...")
	# 服务端应用配置
	GameManager.apply_online_match_config(config, 1)
	SyncManager.prepare_match(config, 1)
	# 发送给客户端
	_rpc_debug_match_config.rpc_id(_client_peer_id, config)
	# 切换到游戏场景
	_go_to_game()


@rpc("authority", "reliable")
func _rpc_debug_match_config(config: Dictionary) -> void:
	var my_peer_id := multiplayer.get_unique_id()
	print("[DebugQuickMatch] Client: received config, peer_id=%d" % my_peer_id)
	GameManager.apply_online_match_config(config, my_peer_id)
	SyncManager.prepare_match(config, my_peer_id)
	_go_to_game()


func _go_to_game() -> void:
	var soccer_game := _find_soccer_game()
	if soccer_game:
		soccer_game.switch_screen(SoccerGame.ScreenType.IN_GAME)
	else:
		push_error("[DebugQuickMatch] Cannot find SoccerGame root node!")


func _find_soccer_game() -> SoccerGame:
	var root := get_tree().current_scene
	if root is SoccerGame:
		return root as SoccerGame
	for child in get_tree().root.get_children():
		if child is SoccerGame:
			return child as SoccerGame
	return null


func _setup_client() -> void:
	# 等一帧让 RoomManager 初始化完成
	await get_tree().process_frame
	print("[DebugQuickMatch] Client: connecting to %s:%d..." % [SERVER_IP, RoomManager.PORT])
	var err := RoomManager.connect_to_host(SERVER_IP)
	if err != OK:
		push_error("[DebugQuickMatch] Failed to connect: %d" % err)
