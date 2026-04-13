class_name BallStatePowerShotRising
extends BallState

const DURATION_RISING := 500
const RISING_TARGET_HEIGHT := 30.0
const RISING_SPEED := 0.08

enum Phase { RISING, SHOOTING }

var current_phase: Phase = Phase.RISING
var time_since_start := 0
var initial_velocity := Vector2.ZERO

func on_enter_visual() -> void:
	shot_particles.emitting = true
	GameEvents.impact_received.emit(ball.position, true)

func on_enter_logic() -> void:
	initial_velocity = ball.velocity
	current_phase = Phase.RISING
	time_since_start = Time.get_ticks_msec()

func physics_process(delta: float) -> void:
	match current_phase:
		Phase.RISING:
			_process_rising(delta)
		Phase.SHOOTING:
			_process_shooting(delta)

func _process_rising(delta: float) -> void:
	var elapsed_time := Time.get_ticks_msec() - time_since_start
	if ball.height < RISING_TARGET_HEIGHT:
		ball.height += RISING_SPEED * delta * 60.0
	ball.velocity = ball.velocity.move_toward(Vector2.ZERO, ball.friction_ground * delta * 0.5)
	move_and_bounce(delta)
	if elapsed_time >= DURATION_RISING:
		current_phase = Phase.SHOOTING
		ball.velocity = initial_velocity.normalized() * initial_velocity.length()
		ball.height_velocity = 0.0

func _process_shooting(delta: float) -> void:
	ball.height_velocity = 0.0
	var ball_caught := check_player_damage()
	if ball_caught:
		return
	var collision := ball.move_and_collide(ball.velocity * delta)
	if collision != null:
		ball.velocity = ball.velocity.bounce(collision.get_normal()) * BOUNCINESS
		AudioPlayer.play(AudioPlayer.Sound.BOUNCE)
		state_transition_requested.emit(Ball.State.FREEFORM)

func _exit_tree() -> void:
	shot_particles.emitting = false
