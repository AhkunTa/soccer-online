# # 网络管理器使用示例
# # 这些示例展示如何在实际游戏中使用 NetworkManager

# # ============ 示例 1: 服务器启动脚本 ============
# # 文件: scenes/network/server_launcher.gd

# extends Node

# func _ready() -> void:
# 	print("=== 服务器启动 ===")
	
# 	# 启动网络管理器
# 	if not has_node("/root/NetworkManager"):
# 		var network_manager = preload("res://network/network_manager.gd").new()
# 		get_tree().root.add_child(network_manager)
	
# 	# 启动服务器
# 	if NetworkManager.start_server(9999):
# 		print("✓ 服务器启动成功")
# 		NetworkManager.register_player("Server", "home")
		
# 		# 监听事件
# 		NetworkManager.player_connected.connect(_on_player_connected)
# 		NetworkManager.player_disconnected.connect(_on_player_disconnected)
# 		NetworkManager.message_received.connect(_on_message_received)
# 	else:
# 		print("✗ 服务器启动失败")

# func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
# 	print("✓ 玩家加入: %s (ID: %d, 队伍: %s)" % [
# 		player_info.get("name"),
# 		peer_id,
# 		player_info.get("team")
# 	])
	
# 	# 分配角色
# 	if peer_id != 1:  # 不是服务器
# 		NetworkManager.assign_player_role(peer_id, "midfielder")

# func _on_player_disconnected(peer_id: int) -> void:
# 	print("✗ 玩家离开: %d" % peer_id)

# func _on_message_received(message_type: int, data: Dictionary) -> void:
# 	match message_type:
# 		NetworkManager.MessageType.PLAYER_ACTION:
# 			print("收到玩家动作: ", data)
# 		NetworkManager.MessageType.PLAYER_POSITION:
# 			print("收到玩家位置: ", data)

# # ============ 示例 2: 客户端连接脚本 ============
# # 文件: scenes/network/client_launcher.gd

# extends Node

# @export var server_ip: String = "127.0.0.1"
# @export var player_name: String = "Player1"
# @export var team: String = "away"

# func _ready() -> void:
# 	print("=== 客户端启动 ===")
	
# 	# 启动网络管理器
# 	if not has_node("/root/NetworkManager"):
# 		var network_manager = preload("res://network/network_manager.gd").new()
# 		get_tree().root.add_child(network_manager)
	
# 	# 连接到服务器
# 	if NetworkManager.connect_to_server(server_ip):
# 		print("正在连接到 %s..." % server_ip)
		
# 		# 监听连接状态
# 		NetworkManager.connection_state_changed.connect(_on_connection_state_changed)
# 		NetworkManager.player_connected.connect(_on_player_connected)
# 		NetworkManager.server_error.connect(_on_server_error)
# 	else:
# 		print("✗ 连接失败")

# func _on_connection_state_changed(new_state: int) -> void:
# 	var state_name = NetworkManager.ConnectionState.keys()[new_state]
# 	print("连接状态: %s" % state_name)
	
# 	if new_state == NetworkManager.ConnectionState.CONNECTED_AS_CLIENT:
# 		print("✓ 已连接到服务器")
# 		# 注册玩家
# 		NetworkManager.register_player(player_name, team)

# func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
# 	print("✓ 玩家加入: %s (ID: %d)" % [player_info.get("name"), peer_id])

# func _on_server_error(error_message: String) -> void:
# 	print("✗ 服务器错误: %s" % error_message)

# # ============ 示例 3: 玩家动作发送 ============
# # 文件: scenes/charcaters/player_network.gd

# extends Node

# class_name PlayerNetworkController

# var player: Node2D
# var network_manager: NetworkManager

# func _ready() -> void:
# 	network_manager = get_node("/root/NetworkManager")
# 	player = get_parent()

# func _process(_delta: float) -> void:
# 	if not network_manager.is_connected():
# 		return
	
# 	# 获取本地输入
# 	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
# 	if input_direction != Vector2.ZERO:
# 		_send_player_action("move", input_direction)
	
# 	if Input.is_action_just_pressed("ui_accept"):
# 		_send_player_action("shoot", player.heading)

# func _send_player_action(action: String, direction: Vector2) -> void:
# 	var data = {
# 		"action": action,
# 		"direction": direction,
# 		"position": player.position,
# 		"timestamp": Time.get_ticks_msec()
# 	}
	
# 	# 发送给服务器
# 	network_manager.send_message(
# 		NetworkManager.MessageType.PLAYER_ACTION,
# 		data,
# 		1  # 服务器的 peer_id
# 	)

# # ============ 示例 4: 游戏状态管理 ============
# # 文件: scenes/world/game_state_manager.gd

# extends Node

# class_name GameStateManager

# var network_manager: NetworkManager
# var score_home: int = 0
# var score_away: int = 0
# var match_time: int = 0

# func _ready() -> void:
# 	network_manager = get_node("/root/NetworkManager")
	
# 	if network_manager.is_local_server():
# 		# 服务器：定期广播游戏状态
# 		var timer = Timer.new()
# 		add_child(timer)
# 		timer.timeout.connect(_broadcast_game_state)
# 		timer.start(0.1)  # 每 100ms 广播一次
	
# 	# 监听消息
# 	network_manager.message_received.connect(_on_message_received)

# func _broadcast_game_state() -> void:
# 	var data = {
# 		"score_home": score_home,
# 		"score_away": score_away,
# 		"match_time": match_time,
# 		"timestamp": Time.get_ticks_msec()
# 	}
	
# 	network_manager.send_message(
# 		NetworkManager.MessageType.GAME_STATE_UPDATE,
# 		data,
# 		0  # 广播给所有客户端
# 	)

# func _on_message_received(message_type: int, data: Dictionary) -> void:
# 	match message_type:
# 		NetworkManager.MessageType.GOAL_SCORED:
# 			var team = data.get("team")
# 			if team == "home":
# 				score_home += 1
# 			else:
# 				score_away += 1
# 			print("进球! 比分: %d-%d" % [score_home, score_away])

# func goal_scored(team: String) -> void:
# 	var data = {"team": team, "timestamp": Time.get_ticks_msec()}
# 	network_manager.send_message(
# 		NetworkManager.MessageType.GOAL_SCORED,
# 		data,
# 		0  # 广播
# 	)

# # ============ 示例 5: 调试 UI ============
# # 文件: scenes/ui/network_debug_ui.gd

# extends CanvasLayer

# class_name NetworkDebugUI

# var network_manager: NetworkManager
# var label: Label

# func _ready() -> void:
# 	network_manager = get_node("/root/NetworkManager")
	
# 	# 创建调试标签
# 	label = Label.new()
# 	add_child(label)
# 	label.position = Vector2(10, 10)
# 	label.add_theme_font_size_override("font_size", 14)

# func _process(_delta: float) -> void:
# 	var text = ""
	
# 	# 连接状态
# 	text += "连接状态: %s\n" % network_manager.get_connection_state_name()
# 	text += "本地 Peer ID: %d\n" % network_manager.get_local_peer_id()
# 	text += "是否为服务器: %s\n" % network_manager.is_local_server()
# 	text += "连接玩家数: %d\n" % network_manager.get_peer_count()
	
# 	# 玩家列表
# 	text += "\n=== 玩家列表 ===\n"
# 	for player_info in network_manager.get_all_players():
# 		text += "%s (ID: %d, 队伍: %s, 角色: %s)\n" % [
# 			player_info.get("name"),
# 			player_info.get("peer_id"),
# 			player_info.get("team"),
# 			player_info.get("role")
# 		]
	
# 	label.text = text

# # ============ 示例 6: 完整的游戏场景初始化 ============
# # 文件: scenes/world/world_network.gd

# extends Node2D

# class_name WorldNetwork

# @onready var actors_container = $ActorsContainer
# @onready var camera = $Camera2D

# var network_manager: NetworkManager
# var game_state_manager: GameStateManager

# func _ready() -> void:
# 	# 初始化网络管理器
# 	if not has_node("/root/NetworkManager"):
# 		var nm = preload("res://network/network_manager.gd").new()
# 		get_tree().root.add_child(nm)
	
# 	network_manager = get_node("/root/NetworkManager")
	
# 	# 初始化游戏状态管理器
# 	game_state_manager = GameStateManager.new()
# 	add_child(game_state_manager)
	
# 	# 监听网络事件
# 	network_manager.player_connected.connect(_on_player_connected)
# 	network_manager.player_disconnected.connect(_on_player_disconnected)
# 	network_manager.message_received.connect(_on_message_received)
	
# 	print("✓ 游戏世界初始化完成")

# func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
# 	print("玩家加入: %s" % player_info.get("name"))
	
# 	# 如果是服务器，为新玩家生成角色
# 	if network_manager.is_local_server():
# 		_spawn_player_for_peer(peer_id, player_info)

# func _on_player_disconnected(peer_id: int) -> void:
# 	print("玩家离开: %d" % peer_id)
	
# 	# 移除该玩家的角色
# 	_remove_player_for_peer(peer_id)

# func _on_message_received(message_type: int, data: Dictionary) -> void:
# 	match message_type:
# 		NetworkManager.MessageType.PLAYER_ACTION:
# 			_handle_player_action(data)
# 		NetworkManager.MessageType.GOAL_SCORED:
# 			game_state_manager.goal_scored(data.get("team"))

# func _spawn_player_for_peer(peer_id: int, player_info: Dictionary) -> void:
# 	# 在服务器上为新玩家生成角色
# 	print("为玩家 %d 生成角色" % peer_id)

# func _remove_player_for_peer(peer_id: int) -> void:
# 	# 移除玩家的角色
# 	print("移除玩家 %d 的角色" % peer_id)

# func _handle_player_action(data: Dictionary) -> void:
# 	var action = data.get("action")
# 	var direction = data.get("direction")
# 	print("处理玩家动作: %s, 方向: %s" % [action, direction])
