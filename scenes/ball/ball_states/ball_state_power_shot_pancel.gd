class_name  BallStatePowerShotPancel
extends BallStatePowerShotNormal


func play_animation() -> void:
	set_ball_animation_from_velocity('pancel_shot')

func is_height_light_effect() -> bool:
	return true