class_name  GameStateScored
extends GameState

const DURATION_CELEBRATION := 3000
var time_since_celebration := Time.get_ticks_msec()

func _enter_tree() -> void:
	# 联机模式：比分已由服务端通过 SyncManager 广播，客户端不重复加分
	if not SyncManager.is_client():
		manager.increase_score(state_data.country_scored_on)
	time_since_celebration = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	# 联机模式：仅服务端驱动状态转换
	if SyncManager.is_client():
		return
	if Time.get_ticks_msec() - time_since_celebration > DURATION_CELEBRATION:
		transition_state(GameManager.State.RESET)
		
