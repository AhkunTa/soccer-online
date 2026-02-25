class_name TournamentScreen
extends Screen


const STAGE_TEXTURES := {
	Tournament.Stage.QUARTER_FINALS: preload('res://assets/art/ui/teamselection/quarters-label.png'),
	Tournament.Stage.SEMI_FINALS: preload('res://assets/art/ui/teamselection/semis-label.png'),
	Tournament.Stage.FINAL: preload('res://assets/art/ui/teamselection/finals-label.png'),
	Tournament.Stage.COMPLETE: preload('res://assets/art/ui/teamselection/winner-label.png'),
}

@onready var flag_containers: Dictionary = {
	Tournament.Stage.QUARTER_FINALS: [%QFLeftContainer, %QFRightContainer],
	Tournament.Stage.SEMI_FINALS: [%SFLeftContainer, %SFRightContainer],
	Tournament.Stage.FINAL: [%FinalLeftContainer, %FinalRightContainer],
	Tournament.Stage.COMPLETE: [%WinnerContainer]
}

@onready var stage_texture_node: TextureRect = %StageTexture

var player_country: String = GameManager.player_setup[0]
var tournament: Tournament = null

func _ready() -> void:
	tournament = Tournament.new()
	refresh_brackets()

func _process(_delta: float) -> void:
	if KeyUtils.is_action_just_pressed(Player.ControlScheme.P1, KeyUtils.Action.SHOOT):
		tournament.advance()
		refresh_brackets()

func refresh_brackets() -> void:
	stage_texture_node.texture = STAGE_TEXTURES[tournament.current_stage]
	for stage in range(tournament.current_stage + 1):
		refresh_bracket_stage(stage)

func refresh_bracket_stage(stage: Tournament.Stage) -> void:
	var flag_nodes := get_flag_nodes_for_stage(stage)
	if stage < Tournament.Stage.COMPLETE:
		var matches: Array = tournament.matches[stage]
		assert(flag_nodes.size() == matches.size() * 2, 'Number of flag nodes should be twice the number of matches')
		for i in range(matches.size()):
			var match: Match = matches[i]
			var flag_node_home := flag_nodes[i * 2] as BracketFlag
			var flag_node_away := flag_nodes[i * 2 + 1] as BracketFlag
			flag_node_home.texture = FlagHelper.get_texture(match.country_home)
			flag_node_away.texture = FlagHelper.get_texture(match.country_away)
			if not match.winner.is_empty():
					var flag_winner := flag_node_home if match.winner == match.country_home else flag_node_away
					var flag_loser := flag_node_home if flag_winner == flag_node_away else flag_node_away
					flag_winner.set_as_winner(match.final_score)
					flag_loser.set_as_loser()
			elif [match.country_home, match.country_away].has(player_country) and stage == tournament.current_stage:
				var player_flag := flag_node_home if match.country_home == player_country else flag_node_away
				player_flag.set_as_current_team()
				GameManager.current_match = match
	else:
		var winner_flag_node := flag_nodes[0] as BracketFlag
		winner_flag_node.texture = FlagHelper.get_texture(tournament.winner)


func get_flag_nodes_for_stage(stage: Tournament.Stage) -> Array[BracketFlag]:
	var flag_nodes: Array[BracketFlag] = []
	for container in flag_containers[stage]:
		for child in container.get_children():
			if child is BracketFlag:
				flag_nodes.append(child)
	return flag_nodes
