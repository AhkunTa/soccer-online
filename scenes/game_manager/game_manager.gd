extends Node


const DURATION_GAME_SEC := 2 * 60 # 2 minutes
const DURATION_IMPACT_PAUSE := 100
enum State {IN_PLAY, SCORED, RESET, KICKOFF, OVERTIME, GAMEOVER}
enum GameMode {LOCAL, ONLINE}

# var current_match: Match = null
# DEBUG
var current_match: Match = Match.new("FRANCE", "USA")
var state_factory := GameStateFactory.new()
var time_left: float
var current_state: GameState = null
var player_setup: Array[String] = ['FRANCE', 'USA']
var time_since_pause := Time.get_ticks_msec()
var game_mode: GameMode = GameMode.LOCAL
# DEBUG
var field_condition: FieldCondition = FieldCondition.compose(FieldCondition.Surface.SNOW, FieldCondition.Weather.SNOW)
var field_seed := 0
# 联机模式中本地玩家的队伍与球员 slot 分配 { "team": int, "slot": int }
var online_slot_assignments: Dictionary = {}
# 联机模式中所有玩家的分配信息（完整 assignments 数组）
var online_all_assignments: Array = []

func _init() -> void:
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS

func _ready() -> void:
	GameEvents.impact_received.connect(on_impact_received.bind())
	field_seed = randi()
	# DEBUG 随机场景
	# random_field_condition()

func random_field_condition() -> void:
	var surfaces := FieldCondition.Surface.values()
	var weathers := FieldCondition.Weather.values()
	var surface: int = surfaces[randi() % surfaces.size()]
	var weather: int = weathers[randi() % weathers.size()]
	set_field_condition(FieldCondition.compose(surface, weather))

func _process(_delta: float) -> void:
	if get_tree().paused and Time.get_ticks_msec() - time_since_pause > DURATION_IMPACT_PAUSE:
		get_tree().paused = false

func start_game() -> void:
	time_left = DURATION_GAME_SEC
	_do_switch_state(State.RESET)


func switch_state(state: State, data: GameStateData = GameStateData.build()) -> void:
	# 联机模式：客户端不主动切换状态，等服务端广播
	if is_online() and not multiplayer.is_server():
		return
	_do_switch_state(state, data)
	# 联机模式：服务端广播状态切换给所有客户端
	if is_online() and multiplayer.is_server():
		var data_dict := {}
		if data.country_scored_on != null and data.country_scored_on != "":
			data_dict["country_scored_on"] = data.country_scored_on
		SyncManager.server_sync_game_state(state, data_dict)


## 内部状态切换（不含网络守卫，客户端收到广播后也走这里）
func _do_switch_state(state: State, data: GameStateData = GameStateData.build()) -> void:
	if current_state != null:
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self , data)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "GameStateMacheine: " + str(state)
	call_deferred('add_child', current_state)

func is_coop() -> bool:
	return player_setup[0] == player_setup[1]

func is_single_player() -> bool:
	return player_setup[1].is_empty()

## 联机模式：接收服务端广播的 match_config 并应用
## config 格式:
##   { "room_id": int,
##     "assignments": [{ "peer_id": int, "team": int, "slot": int, "is_ready": bool }, ...],
##     "home_country": String,   # 可选，若无则保持现有 player_setup
##     "away_country": String,
##     "field_seed": int }
func apply_online_match_config(config: Dictionary, local_peer_id: int) -> void:
	game_mode = GameMode.ONLINE
	field_seed = int(config.get("field_seed", field_seed))
	# 如果服务端携带了国旗信息则更新比赛
	if config.has("home_country") and config.has("away_country"):
		current_match = Match.new(config["home_country"], config["away_country"])

	# 保存完整 assignments 供 ActorsContainer 使用
	online_all_assignments = config.get("assignments", [])

	# 根据本地 peer 的 team 决定 player_setup 控制方案
	# team=0 (Home) 控制 P1 侧球员, team=1 (Away) 控制 P2 侧球员
	var assignments: Array = config.get("assignments", [])
	for entry: Dictionary in assignments:
		if entry["peer_id"] == local_peer_id:
			var team: int = entry["team"]
			var slot: int = entry["slot"]
			# online_slot_assignments: [team, slot] 供游戏内控制逻辑读取
			online_slot_assignments = {"team": team, "slot": slot, "position": entry.get("position", Vector2.ZERO)}
			break

func is_online() -> bool:
	return game_mode == GameMode.ONLINE

func set_field_condition(condition: FieldCondition) -> void:
	field_condition = condition

func set_field_condition_key(condition_key: String) -> void:
	field_condition = FieldCondition.from_key(condition_key)

func is_time_over() -> bool:
	return time_left <= 0

func get_winner_country() -> String:
	assert(not current_match.is_tied())
	return current_match.winner

func increase_score(country_scored_on: String) -> void:
	current_match.increase_score(country_scored_on)
	GameEvents.score_changed.emit()

func on_impact_received(_impact_position: Vector2, is_high_impact: bool) -> void:
	if SyncManager.is_client():
		return
	if is_high_impact:
		time_since_pause = Time.get_ticks_msec()
		get_tree().paused = true
