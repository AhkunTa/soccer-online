class_name  BallStatePowerShotNormal
extends BallState

const POWER_SHOT_STRENGTH := 300.0

var time_since_power_shot := Time.get_ticks_msec()

func _enter_tree() -> void:
	print("Power Shot Activated!")
	pass

func _process(_delta: float) -> void:
	pass

func set_ball_animation_from_velocity() -> void:
	sprite.play("power_shot")