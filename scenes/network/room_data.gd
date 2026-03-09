## RoomData — 联机房间相关数据结构
##
## 全局可用类名：RoomData
## 内部类（通过 RoomData.XYZ 访问）：
##   RoomData.PlayerSelection  — 队伍选择阶段每位玩家的状态快照
##   RoomData.MatchConfig      — 服务端广播的对局配置
## 所有类均提供 from_dict() ↔ to_dict() 与裸 Dictionary 互转，
## 保持与现有 RPC 传输格式的兼容性。
class_name RoomData

# ── 字段 ──────────────────────────────────────────────────────────────────────

var id: int = -1
var title: String = ""
var current_players: int = 0
var max_players: int = 4
var host_name: String = ""
## 房间状态："waiting" | "in_selection" | "in_game"
var status: String = "waiting"
## 当前房间内所有玩家数据（由服务端广播填充）
var players: Array[PlayerSelection] = []

# ── Builder ───────────────────────────────────────────────────────────────────

static func build() -> RoomData:
	return RoomData.new()


func with_id(v: int) -> RoomData:
	id = v
	return self


func with_title(v: String) -> RoomData:
	title = v
	return self


func with_players(current: int, maximum: int) -> RoomData:
	current_players = current
	max_players = maximum
	return self


func with_host_name(v: String) -> RoomData:
	host_name = v
	return self


func with_status(v: String) -> RoomData:
	status = v
	return self

func update_data(context_id: int, context_current_players: int, context_max: int, context_status: String, context_host_name: String, context_title: String, context_players: Array[PlayerSelection] = []) -> RoomData:
	id = context_id
	current_players = context_current_players
	max_players = context_max
	status = context_status
	host_name = context_host_name
	title = context_title
	players = context_players
	return self

## 从裸 Dictionary 转换（兼容 RPC 传输格式）
static func from_dict(d: Dictionary) -> RoomData:
	var player_list: Array[PlayerSelection] = []
	for p in d.get("players", []):
		player_list.append(PlayerSelection.from_dict(p))
	return RoomData.build().update_data(
		d.get("id", -1),
		d.get("current_players", 0),
		d.get("max_players", 4),
		d.get("status", "waiting"),
		d.get("host_name", ""),
		d.get("title", ""),
		player_list
	)


## 转换回裸 Dictionary（用于 RPC 序列化）
func to_dict() -> Dictionary:
	var raw_players: Array = []
	for p: PlayerSelection in players:
		raw_players.append(p.to_dict())
	return {
		"id": id,
		"title": title,
		"current_players": current_players,
		"max_players": max_players,
		"host_name": host_name,
		"status": status,
		"players": raw_players,
	}


func is_full() -> bool:
	return current_players >= max_players


func is_joinable() -> bool:
	return status == "waiting" and not is_full()


# ─────────────────────────────────────────────────────────────────────────────
# 内部类（通过 RoomData.PlayerSelection / RoomData.MatchConfig 访问）
# ─────────────────────────────────────────────────────────────────────────────

## 队伍选择阶段每位玩家的状态快照
##
## 对应 RoomManager._team_selections 中的每条条目，
## 由 RoomManager.team_selection_updated 信号携带数组传递。
class PlayerSelection:
	var peer_id: int = -1
	var name: String = ""
	var team: int = -1 ## 0=Home, 1=Away, -1=未选
	var slot: int = -1 ## 球员位置编号，-1=未选
	var is_ready: bool = false
	var country: String = ""
	## 由客户端在 _on_match_config_received 中填充，服务端不设置
	var position: Vector2 = Vector2.ZERO

	static func from_dict(d: Dictionary) -> PlayerSelection:
		var sel := PlayerSelection.new()
		sel.peer_id = d.get("peer_id", -1)
		sel.name = d.get("name", "")
		sel.team = d.get("team", -1)
		sel.slot = d.get("slot", -1)
		sel.is_ready = d.get("is_ready", false)
		sel.country = d.get("country", "")
		sel.position = d.get("position", Vector2.ZERO)
		return sel

	func to_dict() -> Dictionary:
		return {
		"peer_id": peer_id,
		"name": name,
		"team": team,
		"slot": slot,
		"is_ready": is_ready,
		"country": country,
		"position": position,
		}


## 服务端广播的对局配置
##
## 由 RoomManager._server_launch_match 填充并发送，
## 客户端在 OnlineTeamSelectionScreen._on_match_config_received 中接收，
## 随后传给 GameManager.apply_online_match_config。
class MatchConfig:
	var room_id: int = -1
	var home_country: String = ""
	var away_country: String = ""
	## Array[RoomData.PlayerSelection]
	var assignments: Array = []

	# static func from_dict(d: Dictionary) -> MatchConfig:
	# 	var cfg := MatchConfig.new()
	# 	cfg.room_id = d.get("room_id", -1)
	# 	cfg.home_country = d.get("home_country", "")
	# 	cfg.away_country = d.get("away_country", "")
	# 	cfg.assignments.clear()
	# 	for entry in d.get("assignments", []):
	# 		cfg.assignments.append(PlayerSelection.from_dict(entry))
	# 		return cfg

	func to_dict() -> Dictionary:
		var raw: Array = []
		for sel: PlayerSelection in assignments:
			raw.append(sel.to_dict())
			return {
				"room_id": room_id,
				"home_country": home_country,
				"away_country": away_country,
				"assignments": raw,
			}
		return {}

	## 找到指定 peer_id 的分配信息，未找到返回 null
	func get_assignment_for(peer_id: int) -> PlayerSelection:
		for sel: PlayerSelection in assignments:
			if sel.peer_id == peer_id:
				return sel
		return null
