class_name BallStateCarried

extends BallState

var OFFSET_FROM_PLAYER: Vector2 = Vector2(10,-10)
var DRIBBLE_FREQUENCY: float = 10.0
var DRIBBLEe_INTENSITY: float = 3.0

var dribble_time := 0.0
func _enter_tree() -> void:
	# 联机客户端：carrier 可能为 null（由服务端管理），跳过 assert 和信号
	if carrier == null:
		return
	GameEvents.ball_possessed.emit(carrier.fullname)

func _process(delta: float) -> void:
	# 联机客户端：球位置由快照插值驱动，仅播放动画
	if GameManager.is_online() and not ball.multiplayer.is_server():
		if carrier != null and carrier.velocity != Vector2.ZERO:
			if carrier.heading.x >= 0:
				animation_player.play("roll")
			else:
				animation_player.play_backwards("roll")
			animation_player.advance(0)
		else:
			animation_player.play("idle")
		return

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
