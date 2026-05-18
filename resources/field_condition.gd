class_name FieldCondition
extends Resource

enum Surface {
	GRASS, # 草地
	WET, # 湿地
	SNOW, # 雪地
	SAND # 沙地
}

enum Weather {
	CLEAR, # 正常
	RAIN, # 下雨
	SNOW, # 下雪
	THUNDER, # 打雷
	WIND # 刮风
}

enum WindDirection {NONE, LEFT, RIGHT}
enum PatchSet {NONE, WET, PUDDLE, ICE, MUD, SAND, DUST}
enum HazardType {
	NONE,
	LIGHTNING, # 雷击点
	TORNADO # 龙卷风
}
@export var surface: Surface = Surface.GRASS
@export var weather: Weather = Weather.CLEAR
@export var grass_color: Color = Color(0.52, 0.80, 0.16, 1.0)
@export var pattern_color: Color = Color(0.28, 0.61, 0.0, 1.0)
@export var line_color: Color = Color(0.94, 0.94, 0.94, 1.0)
@export var player_speed_multiplier := 1.0
@export var acceleration_multiplier := 1.0
@export var stopping_friction_multiplier := 1.0
@export_range(0.0, 1.0, 0.01) var slip_chance_per_second := 0.0
@export var ball_ground_friction_multiplier := 1.0
@export var ball_air_friction_multiplier := 1.0
@export var wind_direction: WindDirection = WindDirection.NONE
@export var wind_player_force := 0.0
@export var wind_ball_force := 0.0
@export_range(0.0, 1.0, 0.01) var lightning_spawn_threshold := 0.88
@export var max_lightning_count := 3
@export_range(0.0, 1.0, 0.01) var tornado_spawn_threshold := 0.94
@export var max_tornado_count := 2

static func grass() -> FieldCondition:
	return FieldCondition.compose(Surface.GRASS, Weather.CLEAR)

static func rain() -> FieldCondition:
	return FieldCondition.compose(Surface.WET, Weather.RAIN)

static func snow() -> FieldCondition:
	return FieldCondition.compose(Surface.SNOW, Weather.SNOW)

static func sand() -> FieldCondition:
	return FieldCondition.compose(Surface.SAND, Weather.CLEAR)

static func thunder() -> FieldCondition:
	return FieldCondition.compose(Surface.GRASS, Weather.THUNDER)

static func windy(direction: WindDirection = WindDirection.RIGHT) -> FieldCondition:
	var condition := FieldCondition.compose(Surface.GRASS, Weather.WIND)
	condition.wind_direction = direction
	return condition

static func surface_grass() -> FieldCondition:
	var condition := FieldCondition.new()
	condition.surface = Surface.GRASS
	condition._apply_surface_defaults()
	return condition

static func surface_wet() -> FieldCondition:
	var condition := FieldCondition.new()
	condition.surface = Surface.WET
	condition._apply_surface_defaults()
	return condition

static func surface_snow() -> FieldCondition:
	var condition := FieldCondition.new()
	condition.surface = Surface.SNOW
	condition._apply_surface_defaults()
	return condition

static func surface_sand() -> FieldCondition:
	var condition := FieldCondition.new()
	condition.surface = Surface.SAND
	condition._apply_surface_defaults()
	return condition

static func weather_clear() -> FieldCondition:
	var condition := FieldCondition.new()
	condition.weather = Weather.CLEAR
	condition._apply_weather_defaults()
	return condition

static func weather_rain() -> FieldCondition:
	var condition := FieldCondition.new()
	condition.weather = Weather.RAIN
	condition._apply_weather_defaults()
	return condition

static func weather_snow() -> FieldCondition:
	var condition := FieldCondition.new()
	condition.weather = Weather.SNOW
	condition._apply_weather_defaults()
	return condition

static func weather_thunder() -> FieldCondition:
	var condition := FieldCondition.new()
	condition.weather = Weather.THUNDER
	condition._apply_weather_defaults()
	return condition

static func weather_wind(direction: WindDirection = WindDirection.RIGHT) -> FieldCondition:
	var condition := FieldCondition.new()
	condition.weather = Weather.WIND
	condition.wind_direction = direction
	condition._apply_weather_defaults()
	return condition

static func compose(surface_value: Surface, weather_value: Weather = Weather.CLEAR, wind_direction_value: WindDirection = WindDirection.NONE) -> FieldCondition:
	var condition := FieldCondition.new()
	condition.surface = surface_value
	condition.weather = weather_value
	condition.wind_direction = wind_direction_value
	condition._apply_surface_defaults()
	condition._apply_weather_defaults()
	return condition

static func from_key(key: String) -> FieldCondition:
	match key.to_lower():
		"grass":
			return FieldCondition.compose(Surface.GRASS, Weather.CLEAR)
		"wet":
			return FieldCondition.compose(Surface.WET, Weather.CLEAR)
		"rain":
			return FieldCondition.compose(Surface.GRASS, Weather.RAIN)
		"snow":
			return FieldCondition.compose(Surface.SNOW, Weather.CLEAR)
		"snow_weather":
			return FieldCondition.compose(Surface.GRASS, Weather.SNOW)
		"ice":
			return FieldCondition.compose(Surface.SNOW, Weather.RAIN)
		"sand", "dirt":
			return FieldCondition.compose(Surface.SAND, Weather.CLEAR)
		"thunder", "storm":
			return FieldCondition.compose(Surface.GRASS, Weather.THUNDER)
		"wind", "windy":
			return FieldCondition.compose(Surface.GRASS, Weather.WIND, WindDirection.RIGHT)
		"sand_rain", "swamp":
			return FieldCondition.compose(Surface.SAND, Weather.RAIN)
		"sand_wind", "sandstorm":
			return FieldCondition.compose(Surface.SAND, Weather.WIND, WindDirection.RIGHT)
		_:
			return FieldCondition.compose(Surface.GRASS, Weather.CLEAR)

func get_patch_set() -> int:
	match surface:
		Surface.GRASS:
			match weather:
				Weather.RAIN:
					return PatchSet.WET
				Weather.SNOW:
					return PatchSet.ICE
				Weather.THUNDER:
					return PatchSet.MUD
				_:
					return PatchSet.NONE
		Surface.WET:
			match weather:
				Weather.RAIN:
					return PatchSet.PUDDLE
				Weather.SNOW:
					return PatchSet.ICE
				Weather.THUNDER:
					return PatchSet.MUD
				_:
					return PatchSet.WET
		Surface.SNOW:
			return PatchSet.ICE
		Surface.SAND:
			match weather:
				Weather.RAIN, Weather.THUNDER:
					return PatchSet.MUD
				Weather.SNOW:
					return PatchSet.ICE
				Weather.WIND:
					return PatchSet.DUST
				_:
					return PatchSet.SAND
		_:
			return PatchSet.NONE

func _apply_surface_defaults() -> void:
	match surface:
		Surface.GRASS:
			grass_color = Color(0.52, 0.80, 0.16, 1.0)
			pattern_color = Color(0.28, 0.61, 0.0, 1.0)
			line_color = Color(0.94, 0.94, 0.94, 1.0)
			player_speed_multiplier = 1.0
			acceleration_multiplier = 1.0
			stopping_friction_multiplier = 1.0
			slip_chance_per_second = 0.0
			ball_ground_friction_multiplier = 1.0
			ball_air_friction_multiplier = 1.0
		Surface.WET:
			grass_color = Color(0.30, 0.48, 0.25, 1.0)
			pattern_color = Color(0.18, 0.34, 0.18, 1.0)
			line_color = Color(0.78, 0.84, 0.86, 1.0)
			player_speed_multiplier = 0.88
			acceleration_multiplier = 0.72
			stopping_friction_multiplier = 0.45
			slip_chance_per_second = 0.12
			ball_ground_friction_multiplier = 1.35
			ball_air_friction_multiplier = 1.05
		Surface.SNOW:
			grass_color = Color(0.78, 0.88, 0.92, 1.0)
			pattern_color = Color(0.62, 0.76, 0.82, 1.0)
			line_color = Color(0.92, 0.98, 1.0, 1.0)
			player_speed_multiplier = 0.82
			acceleration_multiplier = 0.62
			stopping_friction_multiplier = 0.32
			slip_chance_per_second = 0.18
			ball_ground_friction_multiplier = 0.62
			ball_air_friction_multiplier = 0.95
		Surface.SAND:
			grass_color = Color(0.76, 0.65, 0.38, 1.0)
			pattern_color = Color(0.64, 0.53, 0.30, 1.0)
			line_color = Color(0.88, 0.80, 0.58, 1.0)
			player_speed_multiplier = 0.76
			acceleration_multiplier = 0.68
			stopping_friction_multiplier = 1.35
			slip_chance_per_second = 0.04
			ball_ground_friction_multiplier = 1.75
			ball_air_friction_multiplier = 1.0

func _apply_weather_defaults() -> void:
	match weather:
		Weather.THUNDER:
			if wind_direction == WindDirection.NONE:
				wind_direction = WindDirection.RIGHT
			wind_player_force = maxf(wind_player_force, 12.0)
			wind_ball_force = maxf(wind_ball_force, 26.0)
		Weather.WIND:
			if wind_direction == WindDirection.NONE:
				wind_direction = WindDirection.RIGHT
			wind_player_force = maxf(wind_player_force, 18.0)
			wind_ball_force = maxf(wind_ball_force, 34.0)
		_:
			pass

func get_player_speed_multiplier() -> float:
	return player_speed_multiplier * _get_surface_float("player_speed", 1.0) * _get_weather_float("player_speed", 1.0)

func get_acceleration_multiplier() -> float:
	return acceleration_multiplier * _get_surface_float("acceleration", 1.0) * _get_weather_float("acceleration", 1.0)

func get_stopping_friction_multiplier() -> float:
	return stopping_friction_multiplier * _get_surface_float("stopping_friction", 1.0) * _get_weather_float("stopping_friction", 1.0)

func get_slip_chance_per_second() -> float:
	return slip_chance_per_second + _get_surface_float("slip", 0.0) + _get_weather_float("slip", 0.0)

func get_ball_ground_friction_multiplier() -> float:
	return ball_ground_friction_multiplier * _get_surface_float("ball_ground_friction", 1.0) * _get_weather_float("ball_ground_friction", 1.0)

func get_ball_air_friction_multiplier() -> float:
	return ball_air_friction_multiplier * _get_weather_float("ball_air_friction", 1.0)

func get_wind_player_force() -> float:
	return maxf(wind_player_force, _get_weather_float("wind_player_force", 0.0))

func get_wind_ball_force() -> float:
	return maxf(wind_ball_force, _get_weather_float("wind_ball_force", 0.0))

func get_wind_vector() -> Vector2:
	if wind_direction == WindDirection.NONE and (weather == Weather.WIND or weather == Weather.THUNDER):
		return Vector2.RIGHT
	match wind_direction:
		WindDirection.LEFT:
			return Vector2.LEFT
		WindDirection.RIGHT:
			return Vector2.RIGHT
		_:
			return Vector2.ZERO

func get_max_hazard_count(hazard_type: int) -> int:
	match hazard_type:
		HazardType.LIGHTNING:
			return max_lightning_count
		HazardType.TORNADO:
			if surface == Surface.SAND:
				return max(max_tornado_count, 3)
			return max_tornado_count
		_:
			return 0

func get_hazard_threshold(hazard_type: int) -> float:
	match hazard_type:
		HazardType.LIGHTNING:
			return lightning_spawn_threshold
		HazardType.TORNADO:
			if surface == Surface.SAND:
				return minf(tornado_spawn_threshold, 0.88)
			if surface == Surface.SNOW:
				return minf(tornado_spawn_threshold, 0.92)
			return tornado_spawn_threshold
		_:
			return 1.0

func _get_surface_float(key: String, fallback: float) -> float:
	return _get_surface_modifiers().get(key, fallback)

func _get_weather_float(key: String, fallback: float) -> float:
	return _get_weather_modifiers().get(key, fallback)

func _get_surface_modifiers() -> Dictionary:
	match surface:
		Surface.WET:
			return {"player_speed": 0.94, "acceleration": 0.88, "stopping_friction": 0.75, "slip": 0.04, "ball_ground_friction": 1.10}
		Surface.SNOW:
			return {"player_speed": 0.92, "acceleration": 0.84, "stopping_friction": 0.78, "slip": 0.05, "ball_ground_friction": 0.88}
		Surface.SAND:
			return {"player_speed": 0.96, "acceleration": 0.94, "stopping_friction": 1.08, "ball_ground_friction": 1.08}
		_:
			return {}

func _get_weather_modifiers() -> Dictionary:
	match weather:
		Weather.RAIN:
			return {"player_speed": 0.92, "acceleration": 0.86, "stopping_friction": 0.74, "slip": 0.06, "ball_ground_friction": 1.12}
		Weather.SNOW:
			return {"player_speed": 0.90, "acceleration": 0.80, "stopping_friction": 0.66, "slip": 0.08, "ball_ground_friction": 0.90}
		Weather.THUNDER:
			return {"player_speed": 0.88, "acceleration": 0.78, "stopping_friction": 0.58, "slip": 0.10, "ball_ground_friction": 1.30, "ball_air_friction": 1.08, "wind_player_force": 10.0, "wind_ball_force": 22.0}
		Weather.WIND:
			return {"player_speed": 0.92, "acceleration": 0.88, "ball_air_friction": 1.18, "wind_player_force": 18.0, "wind_ball_force": 34.0}
		_:
			return {}
