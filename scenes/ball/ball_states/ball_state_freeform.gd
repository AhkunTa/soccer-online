class_name BallStateFreeForm

extends BallState

const  MAX_CAPTURE_HEIGHT := 25

func _enter_tree() -> void:
	player_detection_area.body_entered.connect(on_player_enter.bind())
	
func on_player_enter(body: Player) -> void:
	#	TODO 守门员出门
	if body.can_carry_ball() and ball.height < MAX_CAPTURE_HEIGHT:
		ball.carrier = body
		body.control_ball()
		state_transition_requested.emit(Ball.State.CARRIED)

func _process(delta: float) -> void:
	# TODO  height_velocity 处理有问题
	set_ball_animation_from_velocity()
	var friction := ball.friction_air if ball.height > 0 else ball.friction_ground
	ball.velocity = ball.velocity.move_toward(Vector2.ZERO, friction * delta)
	
	process_gravity(delta, BOUNCINESS)
	move_and_bounce(delta)

func can_air_interact() -> bool:
	return true
