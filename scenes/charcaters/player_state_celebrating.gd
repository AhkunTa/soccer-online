class_name  PlayerStateCelebrating
extends PlayerState

const CELEBRATING_HEIGHT := 2.0
const AIR_FRICTION := 35.0
func celebrate() -> void:
	animation_player.play('celebrate')
	player.height = 0.1
	player.height_velocity = CELEBRATING_HEIGHT

func _process(_delta: float) -> void:
	if player.height == 0:
		celebrate()
	player.velocity = player.velocity.move_toward(Vector2.ZERO, _delta * AIR_FRICTION)


