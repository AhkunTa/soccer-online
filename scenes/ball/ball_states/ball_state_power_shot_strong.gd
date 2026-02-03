class_name  BallStatePowerShotStrong
extends BallState

const POWER_SHOT_STRENGTH := 300.0

var time_since_power_shot := Time.get_ticks_msec()

func _enter_tree() -> void:
	print("BallStatePowerShotStrong Activated!")
	pass

func _process(_delta: float) -> void:
	pass