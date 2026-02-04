extends Node

var squads: Dictionary[String, Array]
var countries: Array[String] = ["DEFAULT"]


func _init() -> void:
	var json_file = FileAccess.open("res://assets/json/squads_en.json", FileAccess.READ)

	if json_file == null:
		printerr("Failed to open squads.json")
		return
	var json_text = json_file.get_as_text()
	var json := JSON.new()
	if json.parse(json_text) != OK:
		printerr("Failed to parse squads.json: %s" % json.get_error_message())
	for team in json.data:
		var country_name := team["country"] as String
		countries.append(country_name)
		var players := team["players"] as Array
		if not squads.has(country_name):
			squads.set(country_name, [])
		for player in players:
			var full_name := player["name"] as String
			var skin := player["skin"] as Player.SkinColor
			var role := player["role"] as Player.Role
			var speed := player["speed"] as float
			var power := player["power"] as float
			# 默认强力射击 球扁平
			var power_shot_type: Ball.PowerShotType
			if player.has("power_shot_type"):
				power_shot_type = player["power_shot_type"] as Ball.PowerShotType
			else:
				power_shot_type = Ball.PowerShotType.STRONG
			var player_resource := PlayerResource.new(full_name, skin, role, speed, power, power_shot_type)
			squads.get(country_name).append(player_resource)
		assert(players.size() == 6, "Expected 6 players per team, got %d" % players.size())
	json_file.close()

func get_squad(country: String) -> Array:
	if squads.has(country):
		return squads[country]
	else:
		printerr("No squad found for country: %s" % country)
		return []

func get_countries() -> Array[String]:
	return countries
