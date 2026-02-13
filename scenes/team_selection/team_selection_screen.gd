class_name TeamSelectionScreen
extends Control
const FLAG_ANCHOR_POINT := Vector2(35, 80)
const NB_COLS := 4
const NB_ROWS := 2
const FLAG_SELECTOR_PREFAB := preload('res://scenes/team_selection/flag_selector.tscn')

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
			
				
func try_navigate(selector_index: int, direction: Vector2i) -> void:
	var rect := Rect2i(0, 0, NB_COLS, NB_ROWS)
	if rect.has_point(selection[selector_index] + direction):
		selection[selector_index] += direction
		var flag_index := selection[selector_index].y * NB_COLS + selection[selector_index].x
		selectors[selector_index].position = flags_container.get_child(flag_index).position
		AudioPlayer.play(AudioPlayer.Sound.UI_SELECT)
			
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
	selector.position = flags_container.get_child(0).position
	selectors.append(selector)
	flags_container.add_child(selector)
