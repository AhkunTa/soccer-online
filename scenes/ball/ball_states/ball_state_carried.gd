class_name BallStateCarried

extends BallState

var OFFSET_FROM_PLAYER: Vector2 = Vector2(10,-10)
var DRIBBLE_FREQUENCY: float = 10.0
var DRIBBLEe_INTENSITY: float = 3.0

var dribble_time := 0.0
func _enter_tree() -> void:
	assert(carrier != null)
	GameEvents.ball_possessed.emit(carrier.fullname)

func _process(delta: float) -> void:
	var vx: float = 0.0
	dribble_time += delta
	if carrier.velocity != Vector2.ZERO:
		if carrier.velocity.x != 0:
			vx = cos(DRIBBLE_FREQUENCY * dribble_time) * DRIBBLEe_INTENSITY
		if carrier.heading.x >=0:
			animation_player.play("roll")
			animation_player.advance(0)
		else:
			animation_player.play_backwards('roll')
			animation_player.advance(0)
	else:
		animation_player.play('idle')

	ball.position = carrier.position + Vector2(vx + carrier.heading.x * OFFSET_FROM_PLAYER.x , carrier.heading.y * OFFSET_FROM_PLAYER.y)
	ball.height = carrier.height

func _exit_tree() -> void:
	GameEvents.ball_released.emit()
