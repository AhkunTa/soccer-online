class_name PlayerStateBicycleKick
extends PlayerState

const BALL_HEIGHT_MIN := 10.0
const BALL_HEIGHT_MAX := 40.0
const BONUS_POWER := 2.0

func _enter_tree() -> void:
	animation_player.play("bicycle_kick")
	ball_detection_area.body_entered.connect(on_ball_entered.bind())
	
func on_animation_complete() -> void:
	transition_state(Player.State.RECOVERING)
	

func on_ball_entered(connect_ball: Ball) -> void:
	if connect_ball.can_air_connect(BALL_HEIGHT_MIN, BALL_HEIGHT_MAX):
		var destination := target_goal.get_random_target_position()
		var direction := ball.position.direction_to(destination)
		connect_ball.shoot(direction * player.power * BONUS_POWER)
