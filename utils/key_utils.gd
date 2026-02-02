class_name KeyUtils

enum Action {LEFT, RIGHT, UP, DOWN, SHOOT, PASS, JUMP}

# 缓冲 时间窗口
const TOLERANCE_WINDOW = 150  # 毫秒

# 定义组合键配置: [动作1, 动作2]
const COMBO_KEYS: Array[Array] = [
	[Action.PASS, Action.SHOOT],  # 跳跃组合键
]

const ACTIONS_MAP: Dictionary = {
	Player.ControlScheme.P1: {
		Action.LEFT: "p1_left",
		Action.RIGHT: "p1_right",
		Action.UP: "p1_up",
		Action.DOWN: "p1_down",
		Action.SHOOT: "p1_shoot",
		Action.PASS: "p1_pass",
		Action.JUMP: "p1_jump"
	},
	Player.ControlScheme.P2: {
		Action.LEFT: "p2_left",
		Action.RIGHT: "p2_right",
		Action.UP: "p2_up",
		Action.DOWN: "p2_down",
		Action.SHOOT: "p2_shoot",
		Action.PASS: "p2_pass",
		Action.JUMP: "p2_jump"
	},
}

# TODO 先简单实现 组合键检测 后续看情况 实现 输入容错窗口 
# 记录待定的单键按下时间戳
static var _pending_actions: Dictionary = {}

static func _init_dicts() -> void:
	if _pending_actions.is_empty():
		for scheme in ACTIONS_MAP.keys():
			_pending_actions[scheme] = {}
			for action in Action.values():
				_pending_actions[scheme][action] = 0

static func check_input() -> void:
	pass

static func get_input_vector(scheme: Player.ControlScheme) -> Vector2:
	var map: Dictionary = ACTIONS_MAP[scheme];
	return Input.get_vector(map[Action.LEFT], map[Action.RIGHT], map[Action.UP], map[Action.DOWN])
	

static func is_action_pressed(scheme: Player.ControlScheme, action: Action) -> bool:
	return Input.is_action_pressed(ACTIONS_MAP[scheme][action])


static func is_action_just_pressed(scheme: Player.ControlScheme, action: Action) -> bool:
	return Input.is_action_just_pressed(ACTIONS_MAP[scheme][action])
	
static func is_action_just_released(scheme: Player.ControlScheme, action: Action) -> bool:
	return Input.is_action_just_released(ACTIONS_MAP[scheme][action])

static func is_action_both_pressed(scheme: Player.ControlScheme, action1: Action, action2: Action) -> bool:
	return Input.is_action_pressed(ACTIONS_MAP[scheme][action1]) and Input.is_action_pressed(ACTIONS_MAP[scheme][action2])

# 检查 PASS + SHOOT 组合键
static func are_actions_pressed_together(scheme: Player.ControlScheme, actions: Array[Action]) -> bool:
	_init_dicts()

	if actions.size() != 2:
		return false

	var time1 = _pending_actions[scheme][actions[0]]
	var time2 = _pending_actions[scheme][actions[1]]

	if time1 == 0 or time2 == 0:
		return false
	return abs(time1 - time2) <= TOLERANCE_WINDOW

static func should_trigger_single_action(scheme: Player.ControlScheme, action: Action) -> bool:
	_init_dicts()
	if Input.is_action_just_pressed(ACTIONS_MAP[scheme][action]):
		# 如果是组合键的一部分，标记为 待定 不立即触发
		if _is_part_of_combo(action):
			_pending_actions[scheme][action] = Time.get_ticks_msec()
			return false
		else:
			return true

	# 检查是否有待定的按键
	var pending_time = _pending_actions[scheme][action]
	if pending_time > 0:
		var elapsed = Time.get_ticks_msec() - pending_time

		# 如果等待期已过，触发单键
		if elapsed > TOLERANCE_WINDOW:
			_pending_actions[scheme][action] = 0  # 清除待定
			return true

	return false

# 检查动作是否是组合键的一部分
static func _is_part_of_combo(action: Action) -> bool:
	for combo in COMBO_KEYS:
		if action in combo:
			return true
	return false
