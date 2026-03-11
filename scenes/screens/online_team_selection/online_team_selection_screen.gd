class_name OnlineTeamSelectionScreen
extends Screen

# ── 常量 ─────────────────────────────────────────────────────────────────────
const NB_COLS := 2
const NB_ROWS := 4
const FLAG_ANCHOR_POINT := Vector2(10, 10)
const FLAG_SPACING := Vector2(30, 20)
const FLAG_SELECTOR_PREFAB := preload("res://scenes/screens/team_selection/flag_selector.tscn")
const POSITION_SELECTOR_PREFAB := preload("res://scenes/screens/online_team_selection/position_selector.tscn")
# ── 节点引用 ──────────────────────────────────────────────────────────────────
@onready var home_flag_container: Control = %HomeFlagContainer
@onready var away_flag_container: Control = %AwayFlagContainer
@onready var home_slots_container: VBoxContainer = %HomeSlotsContainer
@onready var away_slots_container: VBoxContainer = %AwaySlotsContainer
@onready var status_label: Label = %StatusLabel
@onready var ready_button: Button = %ReadyButton
@onready var pitch_panel: TextureRect = %PitchPanel

# 选位界面上预设的出生点位置（相对于 pitch_panel）
const player_positions := [
	Vector2(5, 30),
	Vector2(20, 15),
	Vector2(20, 45),
	Vector2(30, 30),
	Vector2(40, 20),
	Vector2(40, 40),
]


# ── 运行时状态 ────────────────────────────────────────────────────────────────
var my_peer_id: int = -1
var room_id: int = -1
var player_count: int = 0

# 本地选择状态
var my_team: int = -1 # 0=Home, 1=Away
var my_country: String = "" # 已选国家
var my_slot: int = -1
var cursor_slot: int = 0 # 位置光标（预览），分离于 my_slot（已向服务端确认占位）
var is_confirmed: bool = false

# 阶段：TEAM -> FLAG -> SLOT
enum Phase {TEAM, FLAG, SLOT}
var phase: Phase = Phase.TEAM

# 旗帜网格光标位置
var flag_cursor: Vector2i = Vector2i.ZERO

# 服务端同步快照 Array[{ peer_id, team, slot, is_ready, country }]
var all_selections: Array = []

var _home_flag_nodes: Array[TextureRect] = []
var _away_flag_nodes: Array[TextureRect] = []
var _my_flag_selector: FlagSelector = null
var _home_selectors: Array[PositionSelector] = []
var _away_selectors: Array[PositionSelector] = []

# ── 生命周期 ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	RoomManager.team_selection_updated.connect(_on_team_selection_updated)
	RoomManager.match_config_received.connect(_on_match_config_received)
	RoomManager.error_occurred.connect(_on_error)
	ready_button.pressed.connect(_on_ready_button_pressed)
	ready_button.disabled = true

	_place_flags(home_flag_container, _home_flag_nodes)
	_place_flags(away_flag_container, _away_flag_nodes)
	spawn_positions()
	if screen_data and screen_data.is_online:
		my_peer_id = screen_data.peer_id
		room_id = screen_data.room_id
		player_count = screen_data.player_count

	_update_status()


func _exit_tree() -> void:
	if RoomManager.team_selection_updated.is_connected(_on_team_selection_updated):
		RoomManager.team_selection_updated.disconnect(_on_team_selection_updated)
	if RoomManager.match_config_received.is_connected(_on_match_config_received):
		RoomManager.match_config_received.disconnect(_on_match_config_received)
	if RoomManager.error_occurred.is_connected(_on_error):
		RoomManager.error_occurred.disconnect(_on_error)


func _process(_delta: float) -> void:
	if is_confirmed:
		return
	var scheme := Player.ControlScheme.P1
	match phase:
		Phase.TEAM: _handle_team_select(scheme)
		Phase.FLAG: _handle_flag_select(scheme)
		Phase.SLOT: _handle_slot_select(scheme)


# ── 输入处理 ──────────────────────────────────────────────────────────────────

## 阶段一：左右选队伍，SHOOT 确认进入国旗选择
func _handle_team_select(scheme: Player.ControlScheme) -> void:
	var capacity := maxi(1, player_count >> 1)
	if KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.LEFT):
		if _count_team_members(0) < capacity or my_team == 0:
			_set_my_team(0)
		else:
			AudioPlayer.play(AudioPlayer.Sound.UI_DISABLE)
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.RIGHT):
		if _count_team_members(1) < capacity or my_team == 1:
			_set_my_team(1)
		else:
			AudioPlayer.play(AudioPlayer.Sound.UI_DISABLE)
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.SHOOT) and my_team != -1:
		_enter_flag_phase()


## 阶段二：WASD 移动旗帜光标，SHOOT 确认国家，PASS 返回
func _handle_flag_select(scheme: Player.ControlScheme) -> void:
	var moved := false
	if KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.LEFT):
		flag_cursor.x = max(0, flag_cursor.x - 1)
		moved = true
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.RIGHT):
		flag_cursor.x = min(NB_COLS - 1, flag_cursor.x + 1)
		moved = true
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.UP):
		flag_cursor.y = max(0, flag_cursor.y - 1)
		moved = true
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.DOWN):
		flag_cursor.y = min(NB_ROWS - 1, flag_cursor.y + 1)
		moved = true

	if moved:
		AudioPlayer.play(AudioPlayer.Sound.UI_NAV)
		_update_flag_selector_position()
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.SHOOT):
		_confirm_country()
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.PASS):
		phase = Phase.TEAM
		_my_flag_selector.queue_free()
		_update_status()


## 阶段三：左右移动光标预览位置，SHOOT 确认占位，PASS 返回国旗选择
func _handle_slot_select(scheme: Player.ControlScheme) -> void:
	var slots_count: int = player_positions.size()
	if KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.LEFT):
		cursor_slot = posmod(cursor_slot - 1, slots_count)
		RoomManager.preview_slot(cursor_slot)
		_update_slot_visuals()
		AudioPlayer.play(AudioPlayer.Sound.UI_NAV)
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.RIGHT):
		cursor_slot = (cursor_slot + 1) % slots_count
		RoomManager.preview_slot(cursor_slot)
		_update_slot_visuals()
		AudioPlayer.play(AudioPlayer.Sound.UI_NAV)
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.SHOOT):
		_claim_slot(cursor_slot)
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.PASS):
		if not _is_team_country_locked():
			phase = Phase.FLAG
			my_slot = -1
			cursor_slot = 0
			RoomManager.select_slot(-1)
			_update_slot_visuals()
	_update_status()


## 确认占用指定位置（SHOOT 时调用，服务端为最终权威）
func _claim_slot(slot: int) -> void:
	# 本地预检：同队是否已有人占据该 slot
	for entry: Dictionary in all_selections:
		if entry.get("peer_id") != my_peer_id \
				and entry.get("team") == my_team \
				and entry.get("slot") == slot:
			AudioPlayer.play(AudioPlayer.Sound.UI_DISABLE)
			_update_status()
			return
	my_slot = slot
	RoomManager.select_slot(my_slot)
	AudioPlayer.play(AudioPlayer.Sound.UI_SELECT)
	_update_slot_visuals()
	_update_status()


# ── 阶段切换 ──────────────────────────────────────────────────────────────────

func _set_my_team(team: int) -> void:
	if my_team == team:
		return
	my_team = team
	my_country = ""
	my_slot = -1
	cursor_slot = 0
	RoomManager.select_team(team)
	AudioPlayer.play(AudioPlayer.Sound.UI_NAV)
	_update_status()


## 进入国旗选择阶段
## 多人情况：如果本队已有队友选好了国家，直接跳到 slot 阶段并高亮该国家
func _enter_flag_phase() -> void:
	var locked_country := _get_team_locked_country()
	if locked_country != "":
		my_country = locked_country
		RoomManager.select_country(my_country)
		_highlight_country(my_country)
		phase = Phase.SLOT
		my_slot = -1
		cursor_slot = 0
		RoomManager.preview_slot(cursor_slot)
		_update_slot_visuals()
	else:
		phase = Phase.FLAG
		flag_cursor = Vector2i.ZERO
		_spawn_flag_selector()
		_update_flag_selector_position()
	_update_status()


## 确认当前光标所在国家
func _confirm_country() -> void:
	var flag_index := flag_cursor.y * NB_COLS + flag_cursor.x
	var country := DataLoader.get_countries()[1 + flag_index]
	var opponent_team := 1 - my_team
	if _get_locked_country_for_team(opponent_team) == country:
		AudioPlayer.play(AudioPlayer.Sound.UI_DISABLE)
		return
	my_country = country
	RoomManager.select_country(my_country)
	AudioPlayer.play(AudioPlayer.Sound.UI_SELECT)
	phase = Phase.SLOT
	my_slot = -1
	cursor_slot = 0
	RoomManager.preview_slot(cursor_slot)
	_update_slot_visuals()
	_update_status()


# ── 旗帜选择器 ────────────────────────────────────────────────────────────────

func _spawn_flag_selector() -> void:
	var container := home_flag_container if my_team == 0 else away_flag_container
	if _my_flag_selector != null and is_instance_valid(_my_flag_selector):
		_my_flag_selector.queue_free()
	_my_flag_selector = FLAG_SELECTOR_PREFAB.instantiate()
	_my_flag_selector.scale = Vector2(.5, .5)
	_my_flag_selector.control_scheme = Player.ControlScheme.P1
	# 禁用 FlagSelector 自身的输入处理，由本屏幕统一管理
	_my_flag_selector.set_process(false)
	container.add_child(_my_flag_selector)
	_update_flag_selector_position()


func _update_flag_selector_position() -> void:
	if _my_flag_selector == null or not is_instance_valid(_my_flag_selector):
		return
	var flag_index := flag_cursor.y * NB_COLS + flag_cursor.x
	var container := home_flag_container if my_team == 0 else away_flag_container
	if flag_index < container.get_child_count() - 1:
		_my_flag_selector.position = container.get_child(flag_index).position


# ── 旗帜放置 ─────────────────────────────────────────────────────────────────

func _place_flags(container: Control, out_nodes: Array[TextureRect]) -> void:
	for j in range(NB_ROWS):
		for i in range(NB_COLS):
			var flag_texture := TextureRect.new()
			flag_texture.position = FLAG_ANCHOR_POINT + Vector2(FLAG_SPACING.x * i, FLAG_SPACING.y * j)
			var country_index := 1 + i + NB_COLS * j
			var country := DataLoader.get_countries()[country_index]
			flag_texture.texture = FlagHelper.get_texture(country)
			flag_texture.z_index = 1
			container.add_child(flag_texture)
			out_nodes.append(flag_texture)


## 高亮已锁定国家，其余变暗
func _highlight_country(country: String) -> void:
	var flag_nodes := _home_flag_nodes if my_team == 0 else _away_flag_nodes
	var countries := DataLoader.get_countries()
	for i in flag_nodes.size():
		var c_index := 1 + i
		if c_index < countries.size() and countries[c_index] == country:
			flag_nodes[i].modulate = Color(1.5, 1.5, 0.5)
		else:
			flag_nodes[i].modulate = Color(0.5, 0.5, 0.5)


# ── 多人辅助查询 ──────────────────────────────────────────────────────────────

func _get_team_locked_country() -> String:
	return _get_locked_country_for_team(my_team)


func _get_locked_country_for_team(team: int) -> String:
	for entry: Dictionary in all_selections:
		if entry["peer_id"] != my_peer_id and entry["team"] == team:
			var c: String = entry.get("country", "")
			if c != "":
				return c
	return ""


func _is_team_country_locked() -> bool:
	return _get_team_locked_country() != ""


func _count_team_members(team: int) -> int:
	var count := 0
	for entry: Dictionary in all_selections:
		if entry.get("team") == team:
			count += 1
	return count


# ── UI 更新 ───────────────────────────────────────────────────────────────────

func _update_status() -> void:
	var hint: String
	match phase:
		Phase.TEAM:
			hint = "A/D 选队伍  SHOOT 确认"
		Phase.FLAG:
			hint = "WASD 选国家  SHOOT 确认  PASS 返回"
		Phase.SLOT:
			var country_text := my_country if my_country != "" else "?"
			if my_slot >= 0:
				hint = "[ %s ] A/D 预览  SHOOT 换位  PASS 返回" % country_text
			else:
				hint = "[ %s ] A/D 预览  SHOOT 确认占位  PASS 返回" % country_text
	var team_text: String
	if my_team == 0:
		team_text = "HOME"
	elif my_team == 1:
		team_text = "AWAY"
	else:
		team_text = "---"
	status_label.text = "%s | %s | %s" % [hint, team_text, _slot_text()]
	ready_button.disabled = my_team == -1 or my_slot == -1 or my_country == "" or is_confirmed


func _slot_text() -> String:
	return "---" if my_slot == -1 else "位置:%d" % (my_slot + 1)


func _rebuild_slot_labels() -> void:
	for child in home_slots_container.get_children():
		child.queue_free()
	for child in away_slots_container.get_children():
		child.queue_free()
	var slots_per_team: int = player_positions.size()
	var home_count := _count_team_members(0)
	var away_count := _count_team_members(1)
	# 队伍人数标题
	var home_title := Label.new()
	home_title.text = "HOME %d/%d" % [home_count, slots_per_team]
	home_slots_container.add_child(home_title)
	var away_title := Label.new()
	away_title.text = "AWAY %d/%d" % [away_count, slots_per_team]
	away_slots_container.add_child(away_title)
	var home_occ: Dictionary = {}
	var away_occ: Dictionary = {}
	for entry: Dictionary in all_selections:
		if entry["team"] == 0 and entry["slot"] >= 0:
			home_occ[entry["slot"]] = entry["peer_id"]
		elif entry["team"] == 1 and entry["slot"] >= 0:
			away_occ[entry["slot"]] = entry["peer_id"]
	for s in range(slots_per_team):
		home_slots_container.add_child(_build_slot_label(s, home_occ))
		away_slots_container.add_child(_build_slot_label(s, away_occ))


func _build_slot_label(slot_idx: int, occupants: Dictionary) -> Label:
	var lbl := Label.new()
	if occupants.has(slot_idx):
		var pid: int = occupants[slot_idx]
		var marker := " v" if _is_ready(pid) else ""
		var mine := " <" if pid == my_peer_id else ""
		lbl.text = "[ %d ] %s%s%s" % [slot_idx + 1, _get_name_for_peer(pid), marker, mine]
	else:
		lbl.text = "[ %d ] ---" % (slot_idx + 1)
	return lbl


func _get_name_for_peer(pid: int) -> String:
	for entry: Dictionary in all_selections:
		if entry["peer_id"] == pid:
			return entry.get("name", "P%d" % pid)
	return "P%d" % pid


func _is_ready(peer_id: int) -> bool:
	for entry: Dictionary in all_selections:
		if entry["peer_id"] == peer_id:
			return entry["is_ready"]
	return false


# ── 信号回调 ──────────────────────────────────────────────────────────────────

func _on_ready_button_pressed() -> void:
	if my_team == -1 or my_slot == -1 or my_country == "":
		return
	is_confirmed = true
	ready_button.disabled = true
	status_label.text = "等待其他玩家就绪..."
	RoomManager.confirm_ready()


func _on_team_selection_updated(selections: Array) -> void:
	all_selections = selections
	# 从服务端快照同步 my_slot，防止客户端与服务端不一致
	for entry: Dictionary in selections:
		if entry.get("peer_id") == my_peer_id:
			my_slot = entry.get("slot", -1)
			break
	_rebuild_slot_labels()
	_update_slot_visuals()
	# 当队伍国家被锁定（同队已有人确认），自动进入对应阶段
	if phase == Phase.FLAG and _is_team_country_locked():
		_enter_flag_phase()
	_update_status()


func _on_match_config_received(config: Dictionary) -> void:
	# 将 slot 序号解析为实际出生位置，写入每个 assignment 的 position 字段
	var assignments: Array = config.get("assignments", [])
	for entry: Dictionary in assignments:
		var s: int = entry.get("slot", 0)
		if s >= 0 and s < player_positions.size():
			entry["position"] = player_positions[s]
		else:
			entry["position"] = Vector2.ZERO
	GameManager.apply_online_match_config(config, my_peer_id)
	transition_screen(SoccerGame.ScreenType.IN_GAME)


func _on_error(message: String) -> void:
	status_label.text = "! " + message
	is_confirmed = false
	# 根据错误类型重置对应状态
	if message == "队伍已满":
		my_team = -1
	elif message == "Slot already taken":
		my_slot = -1
	_update_slot_visuals()
	ready_button.disabled = my_team == -1 or my_slot == -1 or my_country == "" or is_confirmed


func spawn_positions() -> void:
	const PANEL_WIDTH := 100.0
	const selector_size := Vector2(9, 15)
	for i in range(player_positions.size()):
		# 左侧（Home）
		var sel_home: PositionSelector = POSITION_SELECTOR_PREFAB.instantiate()
		sel_home.position = player_positions[i]
		sel_home.scale = Vector2(0.5, 0.5)
		pitch_panel.add_child(sel_home)
		_home_selectors.append(sel_home)
		# 右侧（Away）：水平镜像
		var sel_away: PositionSelector = POSITION_SELECTOR_PREFAB.instantiate()
		sel_away.position = Vector2(PANEL_WIDTH - player_positions[i].x - selector_size.x, player_positions[i].y)
		sel_away.scale = Vector2(0.5, 0.5)
		pitch_panel.add_child(sel_away)
		_away_selectors.append(sel_away)


func _update_slot_visuals() -> void:
	# 重置所有选位显示
	for sel in _home_selectors:
		sel.set_empty()
	for sel in _away_selectors:
		sel.set_empty()
	# 展示服务端已确认的所有玩家位置：自己黄色、队友蓝色、对面红色
	for entry: Dictionary in all_selections:
		var t: int = entry.get("team", -1)
		var s: int = entry.get("slot", -1)
		if t == -1 or s == -1:
			continue
		var sels := _home_selectors if t == 0 else _away_selectors
		if s < sels.size():
			var pid: int = entry.get("peer_id", -1)
			var player_name := _get_name_for_peer(pid)
			var color: Color
			if pid == my_peer_id:
				color = Color.YELLOW
			elif t == my_team:
				color = Color(0.4, 0.7, 1.0) # 蓝色（队友）
			else:
				color = Color(1.0, 0.4, 0.4) # 红色（对面）
			sels[s].set_occupied(player_name, color)
	# 自己的光标预览（仅 SLOT 阶段且未确认占位时闪烁，确认后静止显示）
	if my_team != -1 and phase == Phase.SLOT and my_slot == -1:
		var my_sels := _home_selectors if my_team == 0 else _away_selectors
		if cursor_slot >= 0 and cursor_slot < my_sels.size():
			my_sels[cursor_slot].set_choosing(_get_name_for_peer(my_peer_id))
