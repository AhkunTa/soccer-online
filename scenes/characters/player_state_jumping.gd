class_name PlayerStateJumping
extends PlayerState

const HEIGHT_START := 0.1
const HEIGHT_VELOCITY := 2.0
const DOUBLE_JUMP_VELOCITY := 2.5

func _enter_tree() -> void:
	animation_player.play("jumping")
	player.height_velocity = HEIGHT_VELOCITY
	player.height = HEIGHT_START
	player.jump_count += 1

func _process(_delta: float) -> void:
		# double jump 检测
	if KeyUtils.check_combo_triggered(player.control_scheme, [KeyUtils.Action.PASS, KeyUtils.Action.SHOOT]) and player.jump_count < player.MAX_JUMPS:
		player.height_velocity = DOUBLE_JUMP_VELOCITY
		player.jump_count += 1
		return
	# 检查单键：传球
	if KeyUtils.check_single_action_triggered(player.control_scheme, KeyUtils.Action.PASS):
		if player.has_ball():
			transition_state(Player.State.PASSING)
		return
	# 检查单键：射门
	if KeyUtils.check_single_action_triggered(player.control_scheme, KeyUtils.Action.SHOOT):
		if player.has_ball():
			transition_state(Player.State.JUMPING_SHOT)
		# TODO 空中射门逻辑待补充
		elif ball.can_air_interact():
			if player.is_facing_target_goal():
				transition_state(Player.State.JUMPING_SHOT)
			else:
				transition_state(Player.State.BICYCLE_KICK)
		return

	# 落地后转换到 RECOVERING 状态
	if player.height <= 0:
		transition_state(Player.State.RECOVERING)

func _exit_tree() -> void:
	player.jump_count = 0

func can_pass() -> bool:
	return false
