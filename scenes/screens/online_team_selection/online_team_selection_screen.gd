class_name OnlineTeamSelectionScreen
extends Screen

# ── 常量 ─────────────────────────────────────────────────────────────────────
const NB_COLS := 4
const NB_ROWS := 2
const FLAG_ANCHOR_POINT := Vector2(35, 80)
const FLAG_SPACING := Vector2(55, 50)
const FLAG_SELECTOR_PREFAB := preload("res://scenes/screens/team_selection/flag_selector.tscn")

# ── 节点引用 ──────────────────────────────────────────────────────────────────
@onready var home_flag_container: Control = %HomeFlagContainer
@onready var away_flag_container: Control = %AwayFlagContainer
@onready var home_slots_container: VBoxContainer = %HomeSlotsContainer
@onready var away_slots_container: VBoxContainer = %AwaySlotsContainer
@onready var status_label: Label = %StatusLabel
@onready var ready_button: Button = %ReadyButton
@onready var home_flag_selector: Control = %HomeFlagSelector
@onready var away_flag_selector: Control = %AwayFlagSelector

# ── 运行时状态 ────────────────────────────────────────────────────────────────
var my_peer_id: int = -1
var room_id: int = -1
var player_count: int = 0

# 本地选择状态
var my_team: int = -1    # 0=Home, 1=Away
var my_slot: int = -1
var my_flag_pos: Vector2i = Vector2i.ZERO  # 旗帜网格坐标
var is_confirmed: bool = false

# 服务端同步的所有人选择快照 Array[{ peer_id, team, slot, is_ready }]
var all_selections: Array = []

# 旗帜选择模式：false=选队伍阶段, true=选球员slot阶段
var in_slot_phase: bool = false

# 当前激活的旗帜选择器（0=home, 1=away）
var active_flag_selector: int = -1

var _home_flag_nodes: Array[TextureRect] = []
var _away_flag_nodes: Array[TextureRect] = []

# ── 生命周期 ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	RoomManager.team_selection_updated.connect(_on_team_selection_updated)
	RoomManager.match_config_received.connect(_on_match_config_received)
	RoomManager.error_occurred.connect(_on_error)
	ready_button.pressed.connect(_on_ready_button_pressed)
	ready_button.disabled = true

	_place_flags(home_flag_container, _home_flag_nodes)
	_place_flags(away_flag_container, _away_flag_nodes)

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
	# P1 控制方案操作（目前联机每端只控制自己）
	var scheme := Player.ControlScheme.P1
	if not in_slot_phase:
		_handle_team_select(scheme)
	else:
		_handle_slot_select(scheme)


# ── 输入处理 ──────────────────────────────────────────────────────────────────

## 阶段一：左右选队伍，确认键进入选 slot 阶段
func _handle_team_select(scheme: Player.ControlScheme) -> void:
	if KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.LEFT):
		_set_my_team(0)
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.RIGHT):
		_set_my_team(1)
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.SHOOT) and my_team != -1:
		in_slot_phase = true
		my_slot = 0
		RoomManager.select_slot(my_slot)
		_update_status()


## 阶段二：上下换 slot，确认键就绪（等同于 ready_button）
func _handle_slot_select(scheme: Player.ControlScheme) -> void:
	var slots_per_team: int = player_count / 2
	if KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.UP):
		my_slot = posmod(my_slot - 1, slots_per_team)
		RoomManager.select_slot(my_slot)
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.DOWN):
		my_slot = (my_slot + 1) % slots_per_team
		RoomManager.select_slot(my_slot)
	elif KeyUtils.is_action_just_pressed(scheme, KeyUtils.Action.PASS):
		# 返回队伍选择阶段
		in_slot_phase = false
		_update_status()


func _set_my_team(team: int) -> void:
	my_team = team
	RoomManager.select_team(team)
	AudioPlayer.play(AudioPlayer.Sound.UI_NAV)
	_update_status()


# ── 旗帜放置 ─────────────────────────────────────────────────────────────────

func _place_flags(container: Control, out_nodes: Array[TextureRect]) -> void:
	for j in range(NB_ROWS):
		for i in range(NB_COLS):
			var flag_texture := TextureRect.new()
			flag_texture.position = FLAG_ANCHOR_POINT + Vector2(FLAG_SPACING.x * i, FLAG_SPACING.y * j)
			var country_index := 1 + i + NB_COLS * j
			var country := DataLoader.get_countries()[country_index]
			flag_texture.texture = FlagHelper.get_texture(country)
			flag_texture.scale = Vector2(2, 2)
			flag_texture.z_index = 1
			container.add_child(flag_texture)
			out_nodes.append(flag_texture)


# ── UI 更新 ───────────────────────────────────────────────────────────────────

func _update_status() -> void:
	var phase_text := "← → 选队伍" if not in_slot_phase else "↑ ↓ 选球员位置"
	var team_text: String = (["Home ✓", "Away ✓"] as Array)[my_team] if my_team != -1 else "未选"
	var slot_text := str(my_slot + 1) if my_slot != -1 else "未选"
	status_label.text = "[%s]  队伍: %s  位置: %s" % [phase_text, team_text, slot_text]
	ready_button.disabled = my_team == -1 or my_slot == -1 or is_confirmed


func _rebuild_slot_labels() -> void:
	for child in home_slots_container.get_children():
		child.queue_free()
	for child in away_slots_container.get_children():
		child.queue_free()

	var slots_per_team: int = max(1, player_count / 2)
	# 收集当前占用情况
	var home_occupants: Dictionary = {}
	var away_occupants: Dictionary = {}
	for entry: Dictionary in all_selections:
		if entry["team"] == 0 and entry["slot"] >= 0:
			home_occupants[entry["slot"]] = entry["peer_id"]
		elif entry["team"] == 1 and entry["slot"] >= 0:
			away_occupants[entry["slot"]] = entry["peer_id"]

	for s in range(slots_per_team):
		home_slots_container.add_child(_build_slot_label(s, home_occupants))
		away_slots_container.add_child(_build_slot_label(s, away_occupants))


func _build_slot_label(slot_idx: int, occupants: Dictionary) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 8)
	if occupants.has(slot_idx):
		var pid: int = occupants[slot_idx]
		var marker := " ✓" if _is_ready(pid) else ""
		var mine := " ◀" if pid == my_peer_id else ""
		lbl.text = "  [%d] Player %d%s%s" % [slot_idx + 1, pid, marker, mine]
	else:
		lbl.text = "  [%d] ---" % (slot_idx + 1)
	return lbl


func _is_ready(peer_id: int) -> bool:
	for entry: Dictionary in all_selections:
		if entry["peer_id"] == peer_id:
			return entry["is_ready"]
	return false


# ── 信号回调 ──────────────────────────────────────────────────────────────────

func _on_ready_button_pressed() -> void:
	if my_team == -1 or my_slot == -1:
		return
	is_confirmed = true
	ready_button.disabled = true
	status_label.text = "等待其他玩家就绪..."
	RoomManager.confirm_ready()


func _on_team_selection_updated(selections: Array) -> void:
	all_selections = selections
	_rebuild_slot_labels()
	_update_status()


func _on_match_config_received(config: Dictionary) -> void:
	# 将配置写入 GameManager 后跳转游戏
	GameManager.apply_online_match_config(config, my_peer_id)
	transition_screen(SoccerGame.ScreenType.IN_GAME)


func _on_error(message: String) -> void:
	status_label.text = "! " + message
	is_confirmed = false
	ready_button.disabled = my_team == -1 or my_slot == -1
