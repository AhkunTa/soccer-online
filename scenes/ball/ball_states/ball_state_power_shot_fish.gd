class_name BallStatePowerShotFish
extends BallStatePowerShotJump

# 绝招：鱼跃射门
# 球在飞行过程中会有鱼跃效果，类似于跳跃射门

func play_animation() -> void:
	set_ball_roll_animation_from_velocity()