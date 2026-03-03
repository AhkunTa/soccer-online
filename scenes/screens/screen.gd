class_name Screen
extends Node

signal screen_transition_requested(new_screen: SoccerGame.ScreenType, data: ScreenData)

@export var music: MusicPlayer.Music

var screen_data: ScreenData = null
var game: SoccerGame = null

func _enter_tree() -> void:
	MusicPlayer.play_music(music)

func setup(context_game: SoccerGame, context_data: ScreenData) -> void:
	game = context_game
	screen_data = context_data

func transition_screen(new_screen: SoccerGame.ScreenType, data: ScreenData = ScreenData.new()) -> void:
	# DEBUG 
	if screen_transition_requested.get_connections().is_empty():
		# 调试兜底：F6 单独运行某个 Screen 场景时，直接本地切到目标 Screen。
		var next_screen: Screen = ScreenFactory.new().get_fresh_screen(new_screen)
		next_screen.setup(null, data)
		var parent := get_parent()
		if parent != null:
			parent.add_child(next_screen)
		else:
			get_tree().root.add_child(next_screen)
		queue_free()
		return
	screen_transition_requested.emit(new_screen, data)
