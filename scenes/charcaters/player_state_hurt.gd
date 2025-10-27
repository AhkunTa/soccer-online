class_name  PlayerStateHurt
extends PlayerState

const DURATION_HURT := 1000
const AIR_FRICTION := 35.0
const HURT_HEIGHT_VELOCITY := 3.0

var time_start_hurt := Time.get_ticks_msec()

func _enter_tree() -> void:
	animation_player.play("hurt")
	time_start_hurt = Time.get_ticks_msec()
	player.height_velocity = HURT_HEIGHT_VELOCITY
	tackle_damage_emitter_area.monitoring = true

func _process(delta: float) -> void:
	if Time.get_ticks_msec() - time_start_hurt > DURATION_HURT:
		transition_state(Player.State.RECOVERING)
	player.velocity = player.velocity.move_toward(Vector2.ZERO, AIR_FRICTION * delta)

func _exit_tree() -> void:
	tackle_damage_emitter_area.monitoring = false