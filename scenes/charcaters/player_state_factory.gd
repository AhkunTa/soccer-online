class_name  PlayerStateFactory


var states :Dictionary


# 状态
# Moving Tackling Jumping FastMoving 


func _init() -> void:
	states = {
		Player.State.MOVING: PlayerStateMoving,
		Player.State.RECOVERING: PlayStateRevocering,
		Player.State.TACKLING: PlayerStateTackling,
		Player.State.SHOOTING: PlayerStateShooting,
		Player.State.PREPINGSHOT: PlayerStatePrepingShot,
		Player.State.PASSING: PlayerStatePassing,
		#TODO 跳跃 跳跃射击
		Player.State.JUMPING: PlayerStateJumping,
		Player.State.JUMPINGSHOTING: PlayerStateJumpingShot,
	}
	
func get_fresh_state(state: Player.State) -> PlayerState:
	assert(states.has(state), "state dons't exist!")
	return states.get(state).new()
