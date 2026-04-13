class_name PlayerStateBicycleKick
extends PlayerState

const BALL_HEIGHT_MIN := 10.0
const BALL_HEIGHT_MAX := 40.0
const BONUS_POWER := 2.0

func on_enter_visual() -> void:
	animation_player.play("bicycle_kick")

func on_enter_logic() -> void:
	ball_detection_area.body_entered.connect(_on_ball_entered.bind())

func on_animation_complete() -> void:
	transition_state(Player.State.RECOVERING)

func _on_ball_entered(connect_ball: Ball) -> void:
	if connect_ball.can_air_connect(BALL_HEIGHT_MIN, BALL_HEIGHT_MAX):
		AudioPlayer.play(AudioPlayer.Sound.POWERSHOT)
		connect_ball.shoot(player.velocity.normalized() * player.power * BONUS_POWER, -1.0, player.power * BONUS_POWER, Ball.PowerShotType.HEIGHT_LIGHT)
