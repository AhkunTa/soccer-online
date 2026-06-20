class_name GameStateGameOver
extends GameState

func _enter_tree() -> void:
	if manager.current_match.is_tied():
		# 服务端若收到异常的平局结束请求，恢复到加时赛继续比赛。
		if not SyncManager.is_client():
			transition_state(GameManager.State.OVERTIME)
		return
	var country_winner: String = manager.get_winner_country()
	GameEvents.game_over.emit(country_winner)
