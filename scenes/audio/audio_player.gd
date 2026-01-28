extends Node

enum Sound {BOUNCE, HURT, SHOT, PASS, TACKLE, WHISTLE, POWERSHOT, TACKLING, UI_NAV, UI_SELECT}

const NB_CHANNELS := 4

const SFX_MAP: Dictionary[Sound, AudioStream] = {
	Sound.BOUNCE: preload("res://assets/sfx/bounce.wav"),
	Sound.HURT: preload("res://assets/sfx/hurt.wav"),
	Sound.SHOT: preload("res://assets/sfx/shoot.wav"),
	Sound.PASS: preload("res://assets/sfx/pass.wav"),
	Sound.TACKLE: preload("res://assets/sfx/tackle.wav"),
	Sound.WHISTLE: preload("res://assets/sfx/whistle.wav"),
	Sound.POWERSHOT: preload("res://assets/sfx/power-shot.wav"),
	Sound.TACKLING: preload("res://assets/sfx/tackle.wav"),
	Sound.UI_NAV: preload("res://assets/sfx/ui-navigate.wav"),
	Sound.UI_SELECT: preload("res://assets/sfx/ui-select.wav"),
}


var stream_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in range(NB_CHANNELS):
		var player := AudioStreamPlayer.new()
		stream_players.append(player)
		add_child(player)

func play(sound: Sound) -> void:
	var player := find_first_available_player()
	if player != null:
		player.stream = SFX_MAP[sound]
		player.play()

func find_first_available_player() -> AudioStreamPlayer:
	for player in stream_players:
		if not player.playing:
			return player
	return null
