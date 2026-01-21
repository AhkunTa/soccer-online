extends Node


const DURATION_GAME_SEC := 2 * 60 # 2 minutes

enum State {IN_PLAY, SCORED, RESET, KICKOFF, OVERTIME, GAMEOVER}

var countries: Array[String] = ['FRANCE', "USA"]

var score: Array[int] = [0, 0]
var state_factory := GameStateFactory.new()
var time_left: float
var current_state: GameState = null
var player_setup: Array[String] = ['FRANCE', 'USA']


func _ready() -> void:
	time_left = DURATION_GAME_SEC
	switch_state(State.RESET)

func switch_state(state: State, data: GameStateData = GameStateData.build()) -> void:
	if current_state != null:
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self, data)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "GameStateMacheine: " + str(state)
	call_deferred('add_child', current_state)

func is_coop() -> bool:
	return player_setup[0] == player_setup[1]

func is_single_player() -> bool:
	return player_setup[1].is_empty()

func is_game_tied() -> bool:
	return score[0] == score[1]

func is_time_over() -> bool:
	return time_left <= 0

func get_winner_country() -> String:
	assert(not is_game_tied())
	return countries[0] if score[0] > score[1] else countries[1]

func increase_score(country_scored_on: String) -> void:
	var index_country_scoring := 1 if country_scored_on == countries[0] else 0
	score[index_country_scoring] += 1
	GameEvents.score_changed.emit()

func has_someone_scored() -> bool:
	return score[0] > 0 or score[1] > 0