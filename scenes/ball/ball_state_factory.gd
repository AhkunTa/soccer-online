class_name BallStateFactory

var states: Dictionary
func _init() -> void:
	states = {
		Ball.State.CARRIED: BallStateCarried,
		Ball.State.SHOT: BallStateShot,
		Ball.State.FREEFORM: BallStateFreeForm,
		Ball.State.POWER_SHOT_STRONG: BallStatePowerShotStrong,
		Ball.State.POWER_SHOT_RISING: BallStatePowerShotRising,
		Ball.State.POWER_SHOT_CURVE: BallStatePowerShotCurve,
		Ball.State.POWER_SHOT_NORMAL: BallStatePowerShotNormal,
		Ball.State.POWER_SHOT_HEIGHT_LIGHT: BallStatePowerShotHighlight,
		Ball.State.POWER_SHOT_INVISIBLE: BallStatePowerShotInvisible,
		Ball.State.POWER_SHOT_JUMP: BallStatePowerShotJump,
		# 添加更多绝招状态
	}

func get_fresh_state(state: Ball.State) ->BallState:
	assert(states.has(state), "state not find")
	return states.get(state).new()
