class_name TeamSelectionScreen
extends Control
const FLAG_ANCHOR_POINT := Vector2(35, 80)
const NB_COLS :=4
const NB_ROWS :=2

@onready var flags_container :Control = %FlagsContainer

func _ready() -> void:
	place_flags()


func place_flags() -> void:
	for j in range(NB_ROWS):
		for i in range(NB_COLS):	
			var flag_texture := TextureRect.new()
			flag_texture.position = FLAG_ANCHOR_POINT + Vector2(55 *i, 50 * j)
			var country_index := 1 + i + NB_COLS * j
			var country := DataLoader.get_countries()[country_index]
			flag_texture.texture = FlagHelper.get_texture(country)
			flag_texture.scale = Vector2(2,2)
			flags_container.add_child(flag_texture)
