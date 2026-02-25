class_name TeamSelectionScreen
extends Screen
const FLAG_ANCHOR_POINT := Vector2(35, 80)
const NB_COLS := 4
const NB_ROWS := 2
const FLAG_SELECTOR_PREFAB := preload('res://scenes/screens/team_selection/flag_selector.tscn')

@onready var flags_container: Control = %FlagsContainer

var selection: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]

var selectors: Array[FlagSelector] = []

var move_dirs: Dictionary[KeyUtils.Action, Vector2i] = {
	KeyUtils.Action.UP: Vector2i.UP,
	KeyUtils.Action.DOWN: Vector2i.DOWN,
	KeyUtils.Action.RIGHT: Vector2i.RIGHT,
	KeyUtils.Action.LEFT: Vector2i.LEFT,
}

func _ready() -> void:
	place_flags()
	place_selectors()

func _process(_delta: float) -> void:
	for i in range(selectors.size()):
		var selector = selectors[i]
		if not selector.is_selected:
			for action: KeyUtils.Action in move_dirs.keys():
				if KeyUtils.is_action_just_pressed(selector.control_scheme, action):
					try_navigate(i, move_dirs[action])
	if not selectors[0].is_selected and KeyUtils.is_action_just_pressed(Player.ControlScheme.P1, KeyUtils.Action.PASS):
		AudioPlayer.play(AudioPlayer.Sound.UI_NAV)
		transition_screen(SoccerGame.ScreenType.MAIN_MENU)

func try_navigate(selector_index: int, direction: Vector2i) -> void:
	var rect := Rect2i(0, 0, NB_COLS, NB_ROWS)
	if rect.has_point(selection[selector_index] + direction):
		selection[selector_index] += direction
		var flag_index := selection[selector_index].y * NB_COLS + selection[selector_index].x

		GameManager.player_setup[selector_index] = DataLoader.get_countries()[1 + flag_index]
		selectors[selector_index].position = flags_container.get_child(flag_index).position
		AudioPlayer.play(AudioPlayer.Sound.UI_NAV)

func place_flags() -> void:
	for j in range(NB_ROWS):
		for i in range(NB_COLS):
			var flag_texture := TextureRect.new()
			flag_texture.position = FLAG_ANCHOR_POINT + Vector2(55 * i, 50 * j)
			var country_index := 1 + i + NB_COLS * j
			var country := DataLoader.get_countries()[country_index]
			flag_texture.texture = FlagHelper.get_texture(country)
			flag_texture.scale = Vector2(2, 2)
			flag_texture.z_index = 1
			flags_container.add_child(flag_texture)

func place_selectors() -> void:
	add_selector(Player.ControlScheme.P1)
	if not GameManager.player_setup[1].is_empty():
		add_selector(Player.ControlScheme.P2)
	
func add_selector(scheme: Player.ControlScheme) -> void:
	var selector := FLAG_SELECTOR_PREFAB.instantiate()
	selector.control_scheme = scheme
	selector.selected_signal.connect(on_selector_selected.bind())
	selector.position = flags_container.get_child(0).position
	selectors.append(selector)
	flags_container.add_child(selector)

func on_selector_selected() -> void:
	for selector in selectors:
		if not selector.is_selected:
			return
	var country_p1 := GameManager.player_setup[0]
	var country_p2 := GameManager.player_setup[1]
	if not country_p2.is_empty():
		if country_p1 != country_p2:
			GameManager.current_match = Match.new(country_p1, country_p2)
			transition_screen(SoccerGame.ScreenType.IN_GAME)
		else :
			AudioPlayer.play(AudioPlayer.Sound.UI_DISABLE)
	elif country_p2.is_empty():
		# TODO single player mode
		GameManager.current_match = Match.new(country_p1, 'USA')
		transition_screen(SoccerGame.ScreenType.IN_GAME)
