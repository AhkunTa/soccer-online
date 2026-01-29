class_name  PlayerStateJumping
extends PlayerState

const HEIGHT_START := 0.1
const HEIGHT_VELOCITY := 3.0


func _enter_tree() -> void:
	animation_player.play("jumping")
	player.height = HEIGHT_START
	player.height_velocity = HEIGHT_VELOCITY
	player.velocity = Vector2.ZERO

func _process(_delta: float) -> void:
	# 检测在跳跃过程中按下 SHOT 键
	if player.control_scheme != Player.ControlScheme.CPU:
		if KeyUtils.is_action_just_pressed(player.control_scheme, KeyUtils.Action.SHOOT):
			if player.has_ball():
				transition_state(Player.State.JUMPING_SHOT)

	# 落地后转换到 RECOVERING 状态
	if player.height <= 0:
		transition_state(Player.State.RECOVERING)

func can_pass() -> bool:
	return false
