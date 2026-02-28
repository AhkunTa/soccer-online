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


func _ready() -> void:
	RoomManager.room_list_updated.connect(_on_room_list_updated)
	RoomManager.connection_status_changed.connect(_on_status_changed)
	RoomManager.error_occurred.connect(_on_error)
	RoomManager.room_created.connect(_on_room_created)
	RoomManager.room_joined.connect(_on_room_joined)
	create_panel.visible = false
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


func _on_status_changed(status: String) -> void:
	status_label.text = status
	_update_action_buttons()


func _on_error(message: String) -> void:
	status_label.text = "! " + message
	_update_action_buttons()


func _on_room_list_updated(rooms: Array) -> void:
	_refresh_room_list(rooms)


func _on_room_created(_room_id: int) -> void:
	RoomManager.request_rooms(search_edit.text)


func _on_room_joined(_room_id: int) -> void:
	status_label.text = "Joined room %d" % RoomManager.my_room_id
	RoomManager.request_rooms(search_edit.text)


func _update_action_buttons() -> void:
	var online := RoomManager.state != RoomManager.State.OFFLINE
	host_button.disabled = online
	connect_button.disabled = online
	create_button.disabled = not online
	search_button.disabled = not online


func _refresh_room_list(rooms: Array) -> void:
	for child in room_list.get_children():
		child.queue_free()
	for room_data: Dictionary in rooms:
		room_list.add_child(_build_room_row(room_data))


func _build_room_row(room_data: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var title_lbl := Label.new()
	title_lbl.text = room_data["title"]
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 6)
	row.add_child(title_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "%d/%d" % [room_data["players"], room_data["max_players"]]
	count_lbl.add_theme_font_size_override("font_size", 6)
	row.add_child(count_lbl)

	var join_btn := Button.new()
	var is_full: bool = room_data["players"] >= room_data["max_players"]
	var is_mine: bool = RoomManager.my_room_id == room_data["id"]
	join_btn.text = "In" if is_mine else "Join"
	join_btn.disabled = is_full or is_mine
	join_btn.add_theme_font_size_override("font_size", 6)
	var room_id: int = room_data["id"]
	join_btn.pressed.connect(func() -> void: RoomManager.join_room(room_id))
	row.add_child(join_btn)

	return row


# ── Button handlers ───────────────────────────────────────────────────────────

func _on_host_button_pressed() -> void:
	RoomManager.start_as_host()


func _on_connect_button_pressed() -> void:
	var ip := ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	RoomManager.connect_to_host(ip)


func _on_search_button_pressed() -> void:
	RoomManager.request_rooms(search_edit.text)


func _on_create_button_pressed() -> void:
	room_title_edit.text = ""
	max_players_edit.text = "4"
	create_panel.visible = true


func _on_cancel_create_pressed() -> void:
	create_panel.visible = false


func _on_confirm_create_pressed() -> void:
	var title := room_title_edit.text.strip_edges()
	if title.is_empty():
		title = "Room %d" % (randi() % 900 + 100)
	var max_p := max_players_edit.text.to_int()
	max_p = clampi(max_p, 2, 16)
	create_panel.visible = false
	RoomManager.create_room(title, max_p)


func _on_back_button_pressed() -> void:
	RoomManager.disconnect_network()
	transition_screen(SoccerGame.ScreenType.MAIN_MENU)
