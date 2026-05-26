class_name BallStatePowerShotPancel
extends BallStatePowerShotNormal


func on_enter_visual() -> void:
	super ()
	ball.start_tail_trail(BallTrail.TrailStyle.RAINBOW)


func play_animation() -> void:
	set_ball_animation_from_velocity('pancel_shot')

func is_height_light_effect() -> bool:
	return false

func _exit_tree() -> void:
	super ()
	ball.stop_tail_trail()

func get_power_shot_strength() -> float:
	return 150.0