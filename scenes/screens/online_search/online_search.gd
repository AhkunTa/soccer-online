class_name OnlineSearchScreen
extends Screen

@onready var ip_edit: LineEdit = %IPEdit
@onready var host_button: Button = %HostButton
@onready var connect_button: Button = %ConnectButton
@onready var status_label: Label = %StatusLabel
@onready var search_edit: LineEdit = %SearchEdit
@onready var search_button: Button = %SearchButton
@onready var create_button: Button = %CreateButton
@onready var room_list: VBoxContainer = %RoomList
@onready var back_button: Button = %BackButton
@onready var create_panel: Panel = %CreatePanel
@onready var room_title_edit: LineEdit = %RoomTitleEdit
@onready var max_players_edit: LineEdit = %MaxPlayersEdit
@onready var player_name_edit: LineEdit = %PlayerNameEdit
@onready var connect_panel: Panel = %ConnectPanel
@onready var connect_ip_edit: LineEdit = %ConnectIPEdit
@onready var connect_name_edit: LineEdit = %ConnectNameEdit


func _ready() -> void:
	RoomManager.room_list_updated.connect(_on_room_list_updated)
	RoomManager.connection_status_changed.connect(_on_status_changed)
	RoomManager.error_occurred.connect(_on_error)
	RoomManager.room_created.connect(_on_room_created)
	RoomManager.room_joined.connect(_on_room_joined)
	RoomManager.room_ready.connect(_on_room_ready)
	create_panel.visible = false
	connect_panel.visible = false
	var initial: String
	if RoomManager.state == RoomManager.State.HOSTING:
		initial = "Hosting on port %d" % RoomManager.PORT
	elif RoomManager.state == RoomManager.State.CONNECTED:
		initial = "Connected"
	else:
		initial = "Not connected — Host or Connect first"
	status_label.text = initial
	_update_action_buttons()
	if RoomManager.state != RoomManager.State.OFFLINE:
		RoomManager.request_rooms()
		_refresh_room_list(RoomManager.rooms_cache)


func _get_player_name() -> String:
	var n := player_name_edit.text.strip_edges()
	if n.is_empty():
		return "P%d" % multiplayer.get_unique_id()
	return n


func _on_status_changed(status: String) -> void:
	status_label.text = status
	_update_action_buttons()
	if status == "Connected":
		var upload_name := RoomManager.local_player_name
		if upload_name.is_empty():
			upload_name = "P%d" % multiplayer.get_unique_id()
		RoomManager.upload_player_name(upload_name)


func _on_error(message: String) -> void:
	status_label.text = "! " + message
	_update_action_buttons()


func _on_room_list_updated(rooms: Array[RoomData]) -> void:
	_refresh_room_list(rooms)


func _on_room_created(_room_id: int) -> void:
	RoomManager.request_rooms(search_edit.text)


func _on_room_joined(_room_id: int) -> void:
	status_label.text = "Joined room %d" % RoomManager.my_room_id
	RoomManager.request_rooms(search_edit.text)


func _on_room_ready(room_id: int, player_ids: Array) -> void:
	print("Room %d is ready with players %s" % [room_id, str(player_ids)])
	# 查找本地房间对应的 player_count
	var player_count := player_ids.size()
	var peer_id := multiplayer.get_unique_id()
	var data := ScreenData.build().set_online_context(room_id, player_count, peer_id)
	transition_screen(SoccerGame.ScreenType.ONLINE_TEAM_SELECTION, data)


func _update_action_buttons() -> void:
	var online := RoomManager.state != RoomManager.State.OFFLINE
	host_button.disabled = online
	connect_button.disabled = online
	create_button.disabled = not online
	search_button.disabled = not online


func _refresh_room_list(rooms: Array[RoomData]) -> void:
	for child in room_list.get_children():
		child.queue_free()
	for room_data: RoomData in rooms:
		room_list.add_child(_build_room_row(room_data))


# TODO room list 使用 scene 实现更复杂的交互和样式
func _build_room_row(room_data: RoomData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var title_suffix := (" [%s]" % room_data.host_name) if room_data.host_name != "" else ""

	var title_lbl := Label.new()
	title_lbl.text = room_data.title + title_suffix
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 6)
	row.add_child(title_lbl)

	var status_lbl := Label.new()
	status_lbl.text = room_data.status
	status_lbl.add_theme_font_size_override("font_size", 5)
	status_lbl.modulate = Color(0.7, 1.0, 0.7) if room_data.status == "waiting" else Color(1.0, 0.7, 0.3)
	row.add_child(status_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "%d/%d" % [room_data.current_players, room_data.max_players]
	count_lbl.add_theme_font_size_override("font_size", 6)
	row.add_child(count_lbl)

	if not room_data.players.is_empty():
		var names_lbl := Label.new()
		var display_names: Array[String] = []
		for p: RoomData.PlayerSelection in room_data.players:
			display_names.append(p.name if p.name != "" else "P%d" % p.peer_id)
		names_lbl.text = ", ".join(display_names)
		names_lbl.add_theme_font_size_override("font_size", 5)
		names_lbl.modulate = Color(0.85, 0.85, 0.85)
		names_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(names_lbl)

	var join_btn := Button.new()
	var is_mine: bool = RoomManager.my_room_id == room_data.id
	join_btn.text = "In" if is_mine else "Join"
	join_btn.disabled = room_data.is_full() or is_mine or not room_data.is_joinable()
	join_btn.add_theme_font_size_override("font_size", 6)
	var room_id: int = room_data.id
	join_btn.pressed.connect(func() -> void: RoomManager.join_room(room_id))
	row.add_child(join_btn)

	return row


# ── Button handlers ───────────────────────────────────────────────────────────

func _on_host_button_pressed() -> void:
	var host_name := RoomManager.local_player_name
	if host_name.is_empty():
		host_name = "Host"
	RoomManager.local_player_name = host_name
	RoomManager.start_as_host()
	RoomManager.upload_player_name(host_name)


func _on_connect_button_pressed() -> void:
	connect_ip_edit.text = ip_edit.text
	connect_name_edit.text = RoomManager.local_player_name
	connect_panel.visible = true


func _on_cancel_connect_pressed() -> void:
	connect_panel.visible = false


func _on_confirm_connect_pressed() -> void:
	var ip := connect_ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	ip_edit.text = ip
	var player_name := connect_name_edit.text.strip_edges()
	if not player_name.is_empty():
		RoomManager.local_player_name = player_name
	connect_panel.visible = false
	RoomManager.connect_to_host(ip)


func _on_search_button_pressed() -> void:
	RoomManager.request_rooms(search_edit.text)


func _on_create_button_pressed() -> void:
	room_title_edit.text = ""
	max_players_edit.text = "2"
	create_panel.visible = true


func _on_cancel_create_pressed() -> void:
	create_panel.visible = false


func _on_confirm_create_pressed() -> void:
	var title := room_title_edit.text.strip_edges()
	if title.is_empty():
		title = "Room %d" % (randi() % 900 + 100)
	var max_p := max_players_edit.text.to_int()

	max_p = clampi(max_p, 2, 10)
	create_panel.visible = false
	RoomManager.create_room(title, max_p)


func _on_back_button_pressed() -> void:
	RoomManager.disconnect_network()
	transition_screen(SoccerGame.ScreenType.MAIN_MENU)


func _exit_tree() -> void:
	if RoomManager.room_list_updated.is_connected(_on_room_list_updated):
		RoomManager.room_list_updated.disconnect(_on_room_list_updated)
	if RoomManager.connection_status_changed.is_connected(_on_status_changed):
		RoomManager.connection_status_changed.disconnect(_on_status_changed)
	if RoomManager.error_occurred.is_connected(_on_error):
		RoomManager.error_occurred.disconnect(_on_error)
	if RoomManager.room_created.is_connected(_on_room_created):
		RoomManager.room_created.disconnect(_on_room_created)
	if RoomManager.room_joined.is_connected(_on_room_joined):
		RoomManager.room_joined.disconnect(_on_room_joined)
	if RoomManager.room_ready.is_connected(_on_room_ready):
		RoomManager.room_ready.disconnect(_on_room_ready)
