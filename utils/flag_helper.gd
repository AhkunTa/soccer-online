class_name FlagHelper
extends Node

static var flag_texures: Dictionary[String, Texture2D] = {}

static func get_texture(country: String) -> Texture2D:
	if not flag_texures.has(country):
		flag_texures.set(country, load("res://assets/art/ui/flags/flag-%s.png" % [country.to_lower()]))
	return flag_texures[country]
