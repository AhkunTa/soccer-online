class_name PlayerStateHeader
extends PlayerState

const BALL_HEIGHT_MIN := 0
const BALL_HEIGHT_MAX := 30
const BONUS_POWER := 1.3
const HEIGHT_START := .1
const HEIGHT_VELOCITY := 1.5

func on_enter_visual() -> void:
	animation_player.play("header")

func on_enter_logic() -> void:
	player.height = HEIGHT_START
	player.height_velocity = HEIGHT_VELOCITY
	ball_detection_area.body_entered.connect(_on_ball_entered.bind())

func _on_ball_entered(contact_ball: Ball) -> void:
	if contact_ball.can_air_connect(BALL_HEIGHT_MIN, BALL_HEIGHT_MAX):
		AudioPlayer.play(AudioPlayer.Sound.POWERSHOT)
		contact_ball.current_state.state_data.set_last_hit_player(player)
		contact_ball.shoot(player.velocity.normalized() * player.power * BONUS_POWER, -1.0, player.power * BONUS_POWER, Ball.PowerShotType.HEIGHT_LIGHT, player)

func server_process(_delta: float) -> void:
	if player.height == 0:
		transition_state(Player.State.RECOVERING)
