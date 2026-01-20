# NetworkManager API 参考

## 核心 API

### 连接管理

```gdscript
# 启动服务器
NetworkManager.start_server(port: int = 9999) -> bool

# 连接到服务器
NetworkManager.connect_to_server(server_ip: String, port: int = 9999) -> bool

# 断开连接
NetworkManager.disconnect_from_server() -> void

# 检查连接状态
NetworkManager.is_connected() -> bool
NetworkManager.get_connection_state_name() -> String
```

### 玩家管理

```gdscript
# 注册本地玩家
NetworkManager.register_player(player_name: String, team: String = "") -> void

# 获取玩家信息
NetworkManager.get_player_info(peer_id: int) -> Dictionary
NetworkManager.get_all_players() -> Array
NetworkManager.get_players_by_team(team: String) -> Array

# 分配玩家角色
NetworkManager.assign_player_role(peer_id: int, role: String) -> void

# 获取玩家数量
NetworkManager.get_peer_count() -> int
```

### 消息系统

```gdscript
# 发送消息
NetworkManager.send_message(
	message_type: MessageType,
	data: Dictionary,
	target_peer_id: int = 0  # 0=广播, 1=服务器, >1=特定客户端
) -> void
```

### 工具方法

```gdscript
# 获取本地 Peer ID
NetworkManager.get_local_peer_id() -> int

# 检查是否为服务器
NetworkManager.is_local_server() -> bool

# 获取连接状态
NetworkManager.connection_state -> ConnectionState
```

---

## 信号

```gdscript
# 连接状态改变
signal connection_state_changed(new_state: ConnectionState)

# 玩家连接
signal player_connected(peer_id: int, player_info: Dictionary)

# 玩家断开连接
signal player_disconnected(peer_id: int)

# 游戏开始/结束
signal game_started
signal game_ended

# 收到消息
signal message_received(message_type: MessageType, data: Dictionary)

# 服务器错误
signal server_error(error_message: String)
```

---

## 枚举

### ConnectionState
```gdscript
enum ConnectionState {
	DISCONNECTED,              # 未连接
	CONNECTING,                # 正在连接
	CONNECTED_AS_SERVER,       # 作为服务器连接
	CONNECTED_AS_CLIENT        # 作为客户端连接
}
```

### MessageType
```gdscript
enum MessageType {
	# 连接相关
	PLAYER_JOIN,               # 玩家加入
	PLAYER_LEAVE,              # 玩家离开
	ASSIGN_ROLE,               # 分配角色
	
	# 游戏状态
	GAME_START,                # 游戏开始
	GAME_END,                  # 游戏结束
	GAME_STATE_UPDATE,         # 游戏状态更新
	
	# 玩家动作
	PLAYER_ACTION,             # 玩家动作
	PLAYER_POSITION,           # 玩家位置
	PLAYER_STATE_CHANGE,       # 玩家状态变化
	
	# 球的状态
	BALL_POSITION,             # 球位置
	BALL_STATE_CHANGE,         # 球状态变化
	GOAL_SCORED,               # 进球
	
	# 其他
	PING,                      # 心跳
	PONG                       # 心跳响应
}
```

---

## 常见使用模式

### 模式 1: 启动服务器并等待玩家

```gdscript
func _ready() -> void:
	# 启动服务器
	NetworkManager.start_server()
	
	# 监听玩家连接
	NetworkManager.player_connected.connect(_on_player_connected)
	
	# 注册服务器玩家
	NetworkManager.register_player("Server", "home")

func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
	print("玩家加入: %s" % player_info.name)
	
	# 分配角色
	NetworkManager.assign_player_role(peer_id, "midfielder")
```

### 模式 2: 连接到服务器

```gdscript
func _ready() -> void:
	# 连接到服务器
	NetworkManager.connect_to_server("127.0.0.1")
	
	# 监听连接状态
	NetworkManager.connection_state_changed.connect(_on_connection_state_changed)

func _on_connection_state_changed(new_state: int) -> void:
	if new_state == NetworkManager.ConnectionState.CONNECTED_AS_CLIENT:
		# 注册玩家
		NetworkManager.register_player("Player1", "away")
```

### 模式 3: 发送和接收消息

```gdscript
func _ready() -> void:
	NetworkManager.message_received.connect(_on_message_received)

func send_player_action(action: String, direction: Vector2) -> void:
	var data = {
		"action": action,
		"direction": direction,
		"timestamp": Time.get_ticks_msec()
	}
	
	# 发送给服务器
	NetworkManager.send_message(
		NetworkManager.MessageType.PLAYER_ACTION,
		data,
		1  # 服务器的 peer_id
	)

func _on_message_received(message_type: int, data: Dictionary) -> void:
	match message_type:
		NetworkManager.MessageType.PLAYER_ACTION:
			print("收到玩家动作: ", data)
		NetworkManager.MessageType.BALL_POSITION:
			print("收到球位置: ", data)
```

### 模式 4: 广播消息给所有玩家

```gdscript
func broadcast_game_state(score_home: int, score_away: int) -> void:
	var data = {
		"score_home": score_home,
		"score_away": score_away,
		"timestamp": Time.get_ticks_msec()
	}
	
	# 广播给所有玩家（target_peer_id = 0）
	NetworkManager.send_message(
		NetworkManager.MessageType.GAME_STATE_UPDATE,
		data,
		0
	)
```

### 模式 5: 发送消息给特定玩家

```gdscript
func send_role_assignment(peer_id: int, role: String) -> void:
	var data = {"role": role}
	
	# 发送给特定玩家
	NetworkManager.send_message(
		NetworkManager.MessageType.ASSIGN_ROLE,
		data,
		peer_id
	)
```

---

## 玩家信息结构

```gdscript
{
	"peer_id": 2,                          # 玩家的网络 ID
	"name": "Player1",                     # 玩家名称
	"team": "away",                        # 队伍 (home/away)
	"role": "midfielder",                  # 角色 (goalkeeper/defender/midfielder/forward)
	"position": Vector2(100, 200),         # 当前位置
	"connected_at": 1699999999999          # 连接时间戳
}
```

---

## 消息数据结构示例

### PLAYER_ACTION
```gdscript
{
	"action": "move",                      # 动作类型
	"direction": Vector2(1, 0),            # 方向
	"position": Vector2(100, 200),         # 当前位置
	"timestamp": 1699999999999             # 时间戳
}
```

### PLAYER_POSITION
```gdscript
{
	"position": Vector2(100, 200),         # 位置
	"velocity": Vector2(5, 0),             # 速度
	"heading": Vector2(1, 0),              # 朝向
	"timestamp": 1699999999999             # 时间戳
}
```

### BALL_POSITION
```gdscript
{
	"position": Vector2(500, 300),         # 球位置
	"velocity": Vector2(10, 5),            # 球速度
	"height": 0.0,                         # 球高度
	"carrier_peer_id": 2,                  # 持球者 (-1 = 无人持球)
	"timestamp": 1699999999999             # 时间戳
}
```

### GOAL_SCORED
```gdscript
{
	"team": "home",                        # 进球队伍
	"scorer_peer_id": 2,                   # 进球者
	"timestamp": 1699999999999             # 时间戳
}
```

### GAME_STATE_UPDATE
```gdscript
{
	"score_home": 2,                       # 主队比分
	"score_away": 1,                       # 客队比分
	"match_time": 1800,                    # 比赛时间（秒）
	"timestamp": 1699999999999             # 时间戳
}
```

---

## 调试技巧

### 打印连接信息
```gdscript
print("连接状态: %s" % NetworkManager.get_connection_state_name())
print("本地 Peer ID: %d" % NetworkManager.get_local_peer_id())
print("是否为服务器: %s" % NetworkManager.is_local_server())
print("连接玩家数: %d" % NetworkManager.get_peer_count())
```

### 打印玩家列表
```gdscript
for player_info in NetworkManager.get_all_players():
	print("玩家: %s (ID: %d, 队伍: %s)" % [
		player_info.get("name"),
		player_info.get("peer_id"),
		player_info.get("team")
	])
```

### 监听所有消息
```gdscript
NetworkManager.message_received.connect(func(msg_type, data):
	print("消息: %s, 数据: %s" % [
		NetworkManager.MessageType.keys()[msg_type],
		data
	])
)
```

---

## 常见问题

### Q: 如何区分服务器和客户端？
```gdscript
if NetworkManager.is_local_server():
	print("我是服务器")
else:
	print("我是客户端")
```

### Q: 如何获取本地玩家的 Peer ID？
```gdscript
var my_peer_id = NetworkManager.get_local_peer_id()
```

### Q: 如何发送消息给服务器？
```gdscript
NetworkManager.send_message(message_type, data, 1)  # 1 是服务器的 peer_id
```

### Q: 如何广播消息给所有玩家？
```gdscript
NetworkManager.send_message(message_type, data, 0)  # 0 表示广播
```

### Q: 如何监听特定的消息类型？
```gdscript
NetworkManager.message_received.connect(func(msg_type, data):
	if msg_type == NetworkManager.MessageType.PLAYER_ACTION:
		# 处理玩家动作
		pass
)
```

---

## 性能考虑

- **消息频率**: 默认每秒 20 次同步（可配置）
- **心跳间隔**: 5 秒检查一次，15 秒超时
- **最大玩家数**: 10 人（5v5）
- **带宽**: 取决于消息大小和频率

---

## 下一步

1. 实现 **SyncManager** - 处理游戏状态同步
2. 实现 **GameServer** - 服务器游戏逻辑
3. 改造 **Player** - 支持网络控制
4. 改造 **Ball** - 支持网络同步
