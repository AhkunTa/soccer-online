class_name KeyUtils

enum Action {LEFT, RIGHT, UP, DOWN, SHOOT, PASS, JUMP}

# 组合键容错窗口
const COMBO_TOLERANCE_WINDOW = 50

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

# 记录待定的单键按下时间戳 {scheme: {action: timestamp}}
static var _pending_actions: Dictionary = {}

# 已触发的组合键标记 {scheme: {combo_key: true}}
static var _triggered_combos: Dictionary = {}

static func _init_dicts() -> void:
	if _pending_actions.is_empty():
		for scheme in ACTIONS_MAP.keys():
			_pending_actions[scheme] = {}
			_triggered_combos[scheme] = {}
			for action in Action.values():
				_pending_actions[scheme][action] = 0

static func get_input_vector(scheme: Player.ControlScheme) -> Vector2:
	var map: Dictionary = ACTIONS_MAP[scheme]
	return Input.get_vector(map[Action.LEFT], map[Action.RIGHT], map[Action.UP], map[Action.DOWN])

static func is_action_pressed(scheme: Player.ControlScheme, action: Action) -> bool:
	return Input.is_action_pressed(ACTIONS_MAP[scheme][action])

static func is_action_just_pressed(scheme: Player.ControlScheme, action: Action) -> bool:
	return Input.is_action_just_pressed(ACTIONS_MAP[scheme][action])

static func is_action_just_released(scheme: Player.ControlScheme, action: Action) -> bool:
	return Input.is_action_just_released(ACTIONS_MAP[scheme][action])

static func check_combo_triggered(scheme: Player.ControlScheme, actions: Array[Action]) -> bool:
	if actions.size() != 2:
		return false

	var action1 = actions[0]
	var action2 = actions[1]
	var combo_key = str(action1) + "_" + str(action2)
	# 防止重复触发
	if _triggered_combos[scheme].get(combo_key, false):
		# 任一按键释放后清除触发标记
		if not is_action_pressed(scheme, action1) or not is_action_pressed(scheme, action2):
			_triggered_combos[scheme][combo_key] = false
			_pending_actions[scheme][action1] = 0
			_pending_actions[scheme][action2] = 0
		return false

	var time1 = _pending_actions[scheme][action1]
	var time2 = _pending_actions[scheme][action2]

	# 两个键都有时间戳且在窗口期内
	if time1 > 0 and time2 > 0:
		if abs(time1 - time2) <= COMBO_TOLERANCE_WINDOW:
			# 检查两个键是否都还按着
			if is_action_pressed(scheme, action1) and is_action_pressed(scheme, action2):
				# 触发组合键
				_triggered_combos[scheme][combo_key] = true
				_pending_actions[scheme][action1] = 0
				_pending_actions[scheme][action2] = 0
				return true

	return false

# ========== 单键检测 ==========
static func check_single_action_triggered(scheme: Player.ControlScheme, action: Action) -> bool:
	var current_time = Time.get_ticks_msec()

	# 按键释放时清除待定状态
	if is_action_just_released(scheme, action):
		_pending_actions[scheme][action] = 0
		return false

	# 按键刚按下
	if is_action_just_pressed(scheme, action):
		if _is_part_of_combo(action):
			# 是组合键的一部分，记录时间戳，进入待定状态
			_pending_actions[scheme][action] = current_time
			return false
		else:
			# 不是组合键的一部分，立即触发
			return true

	# 检查待定状态
	var pending_time = _pending_actions[scheme][action]
	if pending_time > 0:
		var elapsed = current_time - pending_time

		# 按键必须仍然按下
		if not is_action_pressed(scheme, action):
			_pending_actions[scheme][action] = 0
			return false

		# 窗口期已过，触发单键
		if elapsed > COMBO_TOLERANCE_WINDOW:
			_pending_actions[scheme][action] = 0
			return true

	return false

# 检查动作是否是组合键的一部分
static func _is_part_of_combo(action: Action) -> bool:
	for combo in COMBO_KEYS:
		if action in combo:
			return true
	return false
