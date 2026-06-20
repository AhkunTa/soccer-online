class_name  GameStateOverTime
extends  GameState

func _enter_tree() -> void:
	GameEvents.team_scored.connect(on_team_scored.bind())


func on_team_scored(country_scored_on: String) -> void:
	if SyncManager.is_client():
		return
	manager.increase_score(country_scored_on)
	if manager.current_match.is_tied():
		# 防御性处理：仍为平局时继续加时，不提前判定赢家。
		return
	transition_state(GameManager.State.GAMEOVER)

