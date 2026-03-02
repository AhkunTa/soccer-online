class_name ScreenData

var tournament: Tournament = null

# 联机队伍选择界面所需上下文
var room_id: int = -1
var player_count: int = 0
var peer_id: int = -1
var is_online: bool = false

static func build() -> ScreenData:
		return ScreenData.new()

func set_tournament(context_tournament: Tournament) -> ScreenData:
	tournament = context_tournament
	return self

func set_online_context(r_id: int, p_count: int, p_id: int) -> ScreenData:
	room_id = r_id
	player_count = p_count
	peer_id = p_id
	is_online = true
	return self
