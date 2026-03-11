class_name PositionSelector
extends Control

signal selected_signal

@onready var label: Label = %Label
@onready var texture: TextureRect = %TextureRect
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var control_scheme := Player.ControlScheme.P1

var is_selected := false

func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	if not is_selected and KeyUtils.is_action_just_pressed(control_scheme, KeyUtils.Action.SHOOT):
		is_selected = true
		AudioPlayer.play(AudioPlayer.Sound.UI_SELECT)
		selected_signal.emit()
	elif is_selected and KeyUtils.is_action_just_pressed(control_scheme, KeyUtils.Action.PASS):
		is_selected = false

func set_occupied(player_name: String, color: Color) -> void:
	animation_player.play("RESET")
	label.text = player_name
	label.add_theme_color_override("font_color", color)


func set_empty() -> void:
	animation_player.play("RESET")
	label.text = ""
	label.remove_theme_color_override("font_color")


func set_choosing(player_name: String) -> void:
	label.text = player_name
	animation_player.play("active")
