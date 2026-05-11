class_name PlayerStateVolleyKick
extends PlayerState

const BALL_HEIGHT_MIN := 1.0
const BALL_HEIGHT_MAX := 30.0
const BONUS_POWER := 1.5
const DURATION_RECOVERY_FALLBACK := 450

var time_start_kick := Time.get_ticks_msec()
var did_finish := false

func on_enter_visual() -> void:
	animation_player.play("volley_kick")

func on_enter_logic() -> void:
	time_start_kick = Time.get_ticks_msec()
	did_finish = false
	ball_detection_area.body_entered.connect(_on_ball_entered.bind())

func server_process(_delta: float) -> void:
	if SyncManager.is_client():
		return
	if Time.get_ticks_msec() - time_start_kick > DURATION_RECOVERY_FALLBACK:
		_finish_kick()

func on_animation_complete() -> void:
	_finish_kick()

func _finish_kick() -> void:
	if did_finish:
		return
	did_finish = true
	transition_state(Player.State.RECOVERING)

func _on_ball_entered(connect_ball: Ball) -> void:
	if connect_ball.can_air_connect(BALL_HEIGHT_MIN, BALL_HEIGHT_MAX):
		var destination := target_goal.get_random_target_position()
		var direction := ball.position.direction_to(destination)
		AudioPlayer.play(AudioPlayer.Sound.POWERSHOT)
		connect_ball.shoot(direction * player.power * BONUS_POWER, -1.0, 150.0, Ball.PowerShotType.NULL, player)
