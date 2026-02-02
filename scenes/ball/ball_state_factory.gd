class_name BallStateFactory

var states: Dictionary
func _init() -> void:
	states = {
		Ball.State.CARRIED: BallStateCarried,
		Ball.State.SHOT: BallStateShot,
		Ball.State.FREEFORM: BallStateFreeForm,
		Ball.State.POWER_SHOT: BallStatePowerShot,
	}

func get_fresh_state(state: Ball.State) ->BallState:
	assert(states.has(state), "state not find")
	return states.get(state).new()
