class_name PlayerStateCelebrating
extends PlayerState

const CELEBRATING_HEIGHT := 2.0
const AIR_FRICTION := 60.0
var initial_delay := randi_range(200, 1000)
var time_since_celebrating := Time.get_ticks_msec()

func on_enter_visual() -> void:
	GameEvents.team_reset.connect(_on_team_reset.bind())

func server_process(delta: float) -> void:
	if player.height == 0 and Time.get_ticks_msec() - time_since_celebrating > initial_delay:
		animation_player.play("celebrate")
		player.height = 0.1
		player.height_velocity = CELEBRATING_HEIGHT
	player.velocity = player.velocity.move_toward(Vector2.ZERO, delta * AIR_FRICTION)

func _on_team_reset() -> void:
	transition_state(Player.State.RESETTING, PlayerStateData.build().set_reset_position(player.spawn_position))
