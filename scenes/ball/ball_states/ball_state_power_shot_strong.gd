class_name  BallStatePowerShotStrong
extends BallStatePowerShotNormal


func play_animation() -> void:
	print("play power shot strong animation")
	set_ball_animation_from_velocity('power_shot_strong')

func is_height_light_effect() -> bool:
	return true