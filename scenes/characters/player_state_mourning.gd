class_name PlayerStateMourning
extends PlayerState

func on_enter_visual() -> void:
	animation_player.play("mourn")
	player.velocity = Vector2.ZERO
	GameEvents.team_reset.connect(_on_team_reset.bind())

func _on_team_reset() -> void:
	transition_state(Player.State.RESETTING, PlayerStateData.build().set_reset_position(player.kickoff_position))
