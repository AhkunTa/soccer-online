class_name GameStateKickoff

extends GameState

var valid_control_schemes := []

func _enter_tree() -> void:
	# 联机模式：仅服务端处理开球逻辑
	if GameManager.is_online() and not multiplayer.is_server():
		return

	var country_starting := state_data.country_scored_on
	if country_starting.is_empty():
		country_starting = manager.current_match.country_home

	if GameManager.is_online():
		# 联机模式：服务端自动开球（不等待按键）
		_do_kickoff()
	else:
		if country_starting == manager.player_setup[0]:
			valid_control_schemes.append(Player.ControlScheme.P1)
		if country_starting == manager.player_setup[1]:
			valid_control_schemes.append(Player.ControlScheme.P2)
		if valid_control_schemes.is_empty():
			valid_control_schemes.append(Player.ControlScheme.P1)

func _process(_delta: float) -> void:
	# 联机模式：客户端不处理
	if GameManager.is_online():
		return
	for control_scheme: Player.ControlScheme in valid_control_schemes:
		if KeyUtils.is_action_just_pressed(control_scheme, KeyUtils.Action.PASS):
			_do_kickoff()

func _do_kickoff() -> void:
	GameEvents.kickoff_started.emit()
	AudioPlayer.play(AudioPlayer.Sound.WHISTLE)
	transition_state(GameManager.State.IN_PLAY)
