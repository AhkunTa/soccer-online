class_name BallStateFreeForm

extends BallState

const  MAX_CAPTURE_HEIGHT := 25

var time_scene_freeform := Time.get_ticks_msec()

func _enter_tree() -> void:
	player_detection_area.body_entered.connect(on_player_enter.bind())
	time_scene_freeform = Time.get_ticks_msec()
	
func on_player_enter(body: Player) -> void:
	#	TODO 守门员出门
	if body.can_carry_ball() and ball.height < MAX_CAPTURE_HEIGHT:
		ball.carrier = body
		body.control_ball()
		state_transition_requested.emit(Ball.State.CARRIED)

func _process(delta: float) -> void:
	# 传球 铲球 球会锁住相应时间 才会被接住
	player_detection_area.monitoring = (Time.get_ticks_msec() - time_scene_freeform > state_data.lock_duration)
	# TODO  height_velocity 处理有问题
	set_ball_roll_animation_from_velocity()
	var friction := ball.friction_air if ball.height > 0 else ball.friction_ground
	ball.velocity = ball.velocity.move_toward(Vector2.ZERO, friction * delta)
	process_gravity(delta, BOUNCINESS, BOUNCINESS)
	move_and_bounce(delta)

func can_air_interact() -> bool:
	return true
