class_name PlayerStateJumpingShot
extends PlayerState

const JUMP_BONUS := 1.3
const DOUBLE_JUMP_BONUS := 2.0
const PARRY_BONUS := 2.0
const BALL_HEIGHT_MIN := 10.0
const BALL_HEIGHT_MAX := 50.0
const POWER_SHOT_AIR_TIME_MIN := 0.18
# const POWER_SHOT_AIR_TIME_MAX := 0.5
# DEBUG
const POWER_SHOT_AIR_TIME_MAX := 0.6

var shot_air_time := 0.0

func on_enter_visual() -> void:
	animation_player.play("volley_kick")
	player.velocity = Vector2.ZERO

func on_enter_logic() -> void:
	shot_air_time = player.air_time_since_jump
	if player.has_ball():
		_perform_jump_shot()
	else:
		ball_detection_area.body_entered.connect(_on_ball_entered.bind())

func server_process(_delta: float) -> void:
	if player.height <= 0:
		transition_state(Player.State.RECOVERING)

func _on_ball_entered(contact_ball: Ball) -> void:
	if contact_ball.can_air_connect(BALL_HEIGHT_MIN, BALL_HEIGHT_MAX):
		var destination := target_goal.get_random_target_position()
		var direction := ball.position.direction_to(destination)
		var bonus_power := PARRY_BONUS * player.power
		var power_shot_type := _get_air_power_shot_type()
		AudioPlayer.play(AudioPlayer.Sound.POWERSHOT)
		contact_ball.shoot(direction * bonus_power, player.height, bonus_power, power_shot_type, player)

func _perform_jump_shot() -> void:
	var destination := target_goal.get_random_target_position()
	var direction := ball.position.direction_to(destination)
	var bonus_power := JUMP_BONUS * player.power if player.jump_count == 1 else DOUBLE_JUMP_BONUS * player.power
	var power_shot_type := _get_air_power_shot_type()
	AudioPlayer.play(AudioPlayer.Sound.POWERSHOT)
	ball.shoot(direction * bonus_power, player.height, bonus_power, power_shot_type, player)

func _get_air_power_shot_type() -> Ball.PowerShotType:
	print("Air time for shot: ", shot_air_time)
	if shot_air_time >= POWER_SHOT_AIR_TIME_MIN and shot_air_time <= POWER_SHOT_AIR_TIME_MAX:
		return player.power_shot_type
	return Ball.PowerShotType.PLAIN

func can_pass() -> bool:
	return true
