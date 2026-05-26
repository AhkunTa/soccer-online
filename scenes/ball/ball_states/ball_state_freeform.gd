class_name BallStateFreeForm
extends BallState

const MAX_CAPTURE_HEIGHT := 25

var time_scene_freeform := Time.get_ticks_msec()

func on_enter_visual() -> void:
	player_detection_area.body_entered.connect(on_player_enter.bind())
	time_scene_freeform = Time.get_ticks_msec()

func on_player_enter(body: Player) -> void:
	if SyncManager.is_client():
		return
	if body.can_carry_ball() and ball.height < MAX_CAPTURE_HEIGHT:
		ball.carrier = body
		body.control_ball()
		state_transition_requested.emit(Ball.State.CARRIED)

func visual_process(_delta: float) -> void:
	player_detection_area.monitoring = (Time.get_ticks_msec() - time_scene_freeform > state_data.lock_duration)
	set_ball_roll_animation_from_velocity()

func server_process(delta: float) -> void:
	var friction := ball.friction_air if ball.height > 0 else ball.get_ground_friction_at_current_patch()
	ball.velocity += ball.field_condition.get_wind_vector() * ball.field_condition.get_wind_ball_force() * delta
	ball.velocity = ball.velocity.move_toward(Vector2.ZERO, friction * delta)
	process_gravity(delta, BOUNCINESS, BOUNCINESS)
	move_and_bounce(delta)

func can_air_interact() -> bool:
	return true
