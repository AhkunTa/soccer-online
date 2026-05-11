class_name PlayerStateJumping
extends PlayerState

const HEIGHT_START := 0.1
const HEIGHT_VELOCITY := 2.0
const DOUBLE_JUMP_VELOCITY := 2.5

func on_enter_visual() -> void:
	animation_player.play("jumping")

func on_enter_logic() -> void:
	player.height_velocity = HEIGHT_VELOCITY
	player.height = HEIGHT_START
	player.jump_count += 1

## Jumping 有本地/网络/CPU 三条路径，直接重写 _process
func _process(_delta: float) -> void:
	if _is_remote_on_client():
		return  # 客户端远程：动画已播放，等 SyncManager 切换状态
	match player.control_scheme:
		Player.ControlScheme.CPU:
			if player.height <= 0:
				transition_state(Player.State.RECOVERING)
		Player.ControlScheme.ONLINE_REMOTE:
			_handle_network_input()
		_:
			_handle_local_input()


func _handle_local_input() -> void:
	if KeyUtils.check_combo_triggered(player.control_scheme, [KeyUtils.Action.PASS, KeyUtils.Action.SHOOT]) and player.jump_count < player.MAX_JUMPS:
		player.height_velocity = DOUBLE_JUMP_VELOCITY
		player.jump_count += 1
		return
	if player.jump_count >= player.MAX_JUMPS \
		and KeyUtils.is_action_pressed(player.control_scheme, KeyUtils.Action.SHOOT) \
		and KeyUtils.is_action_pressed(player.control_scheme, KeyUtils.Action.PASS) \
		and player.has_ball():
		transition_state(Player.State.JUMPING_SHOT)
		return
	if KeyUtils.check_single_action_triggered(player.control_scheme, KeyUtils.Action.PASS):
		if player.has_ball():
			transition_state(Player.State.PASSING)
		return
	if KeyUtils.check_single_action_triggered(player.control_scheme, KeyUtils.Action.SHOOT):
		if player.has_ball():
			transition_state(Player.State.JUMPING_SHOT)
		elif ball.can_air_interact():
			if player.is_facing_target_goal():
				transition_state(Player.State.JUMPING_SHOT)
			else:
				transition_state(Player.State.BICYCLE_KICK)
		return
	if player.height <= 0:
		transition_state(Player.State.RECOVERING)


func _handle_network_input() -> void:
	var idx := player.network_index
	if KeyUtils.is_network_jump_pressed(idx) and player.jump_count < player.MAX_JUMPS:
		player.height_velocity = DOUBLE_JUMP_VELOCITY
		player.jump_count += 1
		return
	if KeyUtils.is_network_jump_held(idx):
		if player.jump_count >= player.MAX_JUMPS and player.has_ball():
			transition_state(Player.State.JUMPING_SHOT)
		return
	if KeyUtils.is_network_action_just_pressed(idx, KeyUtils.Action.PASS):
		if player.has_ball():
			transition_state(Player.State.PASSING)
		return
	if KeyUtils.is_network_action_just_pressed(idx, KeyUtils.Action.SHOOT):
		if player.has_ball():
			transition_state(Player.State.JUMPING_SHOT)
		elif ball.can_air_interact():
			if player.is_facing_target_goal():
				transition_state(Player.State.JUMPING_SHOT)
			else:
				transition_state(Player.State.BICYCLE_KICK)
		return
	if player.height <= 0:
		transition_state(Player.State.RECOVERING)


func _exit_tree() -> void:
	player.jump_count = 0

func can_pass() -> bool:
	return false
