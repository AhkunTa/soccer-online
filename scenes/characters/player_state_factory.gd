class_name  PlayerStateFactory


var states :Dictionary


# 状态
# Moving Tackling Jumping FastMoving 


func _init() -> void:
	states = {
		Player.State.MOVING: PlayerStateMoving,
		Player.State.RECOVERING: PlayerStateRecovering,
		Player.State.CHEST_CONTROL: PlayerStateChestControl,
		Player.State.TACKLING: PlayerStateTackling,
		Player.State.SHOOTING: PlayerStateShooting,
		Player.State.PREPPING_SHOT: PlayerStatePreppingShot,
		Player.State.PASSING: PlayerStatePassing,
		Player.State.VOLLEY_KICK: PlayerStateVolleyKick,
		Player.State.HEADER: PlayerStateHeader,
		Player.State.BICYCLE_KICK: PlayerStateBicycleKick,
		Player.State.HURT: PlayerStateHurt,
		Player.State.DIVING: PlayerStateDiving,
		Player.State.CELEBRATING: PlayerStateCelebrating,
		Player.State.MOURNING: PlayerStateMourning,
		Player.State.RESETTING: PlayerStateResetting,
		#TODO 跳跃 跳跃射击
		Player.State.JUMPING: PlayerStateJumping,
		Player.State.JUMPING_SHOT: PlayerStateJumpingShot,
	}
	
func get_fresh_state(state: Player.State) -> PlayerState:
	assert(states.has(state), "state dons't exist!")
	return states.get(state).new()
