class_name  BallStatePowerShot
extends BallState

# 绝招射门状态
# TODO 多绝招
const POWER_SHOT_STRENGTH := 300.0

var time_since_power_shot := Time.get_ticks_msec()

func _enter_tree() -> void:
	print("Power Shot Activated!")
	pass

func _process(_delta: float) -> void:
	pass
