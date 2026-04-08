class_name BallStateFreeForm

extends BallState

const  MAX_CAPTURE_HEIGHT := 25

var time_scene_freeform := Time.get_ticks_msec()

func _enter_tree() -> void:
	player_detection_area.body_entered.connect(on_player_enter.bind())
	time_scene_freeform = Time.get_ticks_msec()
	
func on_player_enter(body: Player) -> void:
	# 联机模式：仅服务端判定持球
	if GameManager.is_online() and not multiplayer.is_server():
		return
	#	TODO 守门员出门
	if body.can_carry_ball() and ball.height < MAX_CAPTURE_HEIGHT:
		ball.carrier = body
		body.control_ball()
		state_transition_requested.emit(Ball.State.CARRIED)

func _process(delta: float) -> void:
	# 传球 铲球 球会锁住相应时间 才会被接住
	player_detection_area.monitoring = (Time.get_ticks_msec() - time_scene_freeform > state_data.lock_duration)
	set_ball_roll_animation_from_velocity()
	# 物理计算（联机客户端在 base class 中被跳过）
	if not (GameManager.is_online() and not ball.multiplayer.is_server()):
		var friction := ball.friction_air if ball.height > 0 else ball.friction_ground
		ball.velocity = ball.velocity.move_toward(Vector2.ZERO, friction * delta)
	process_gravity(delta, BOUNCINESS, BOUNCINESS)
	move_and_bounce(delta)

func can_air_interact() -> bool:
	return true
