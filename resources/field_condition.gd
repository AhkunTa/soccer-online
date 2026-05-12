class_name FieldCondition
extends Resource

enum Surface { GRASS, RAIN, SNOW, SAND }
enum Weather { CLEAR, RAIN, SNOW, THUNDER, WIND }
enum WindDirection { NONE, LEFT, RIGHT }

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

static func grass() -> FieldCondition:
	var condition := FieldCondition.new()
	condition.surface = Surface.GRASS
	condition.weather = Weather.CLEAR
	condition.grass_color = Color(0.52, 0.80, 0.16, 1.0)
	condition.pattern_color = Color(0.28, 0.61, 0.0, 1.0)
	condition.player_speed_multiplier = 1.0
	condition.acceleration_multiplier = 1.0
	condition.stopping_friction_multiplier = 1.0
	condition.ball_ground_friction_multiplier = 1.0
	return condition

static func rain() -> FieldCondition:
	var condition := FieldCondition.new()
	condition.surface = Surface.RAIN
	condition.weather = Weather.RAIN
	condition.grass_color = Color(0.30, 0.48, 0.25, 1.0)
	condition.pattern_color = Color(0.18, 0.34, 0.18, 1.0)
	condition.line_color = Color(0.78, 0.84, 0.86, 1.0)
	condition.player_speed_multiplier = 0.88
	condition.acceleration_multiplier = 0.72
	condition.stopping_friction_multiplier = 0.45
	condition.slip_chance_per_second = 0.12
	condition.ball_ground_friction_multiplier = 1.35
	condition.ball_air_friction_multiplier = 1.05
	return condition

static func snow() -> FieldCondition:
	var condition := FieldCondition.new()
	condition.surface = Surface.SNOW
	condition.weather = Weather.SNOW
	condition.grass_color = Color(0.78, 0.88, 0.92, 1.0)
	condition.pattern_color = Color(0.62, 0.76, 0.82, 1.0)
	condition.line_color = Color(0.92, 0.98, 1.0, 1.0)
	condition.player_speed_multiplier = 0.82
	condition.acceleration_multiplier = 0.62
	condition.stopping_friction_multiplier = 0.32
	condition.slip_chance_per_second = 0.18
	condition.ball_ground_friction_multiplier = 0.62
	condition.ball_air_friction_multiplier = 0.95
	return condition

static func sand() -> FieldCondition:
	var condition := FieldCondition.new()
	condition.surface = Surface.SAND
	condition.weather = Weather.CLEAR
	condition.grass_color = Color(0.76, 0.65, 0.38, 1.0)
	condition.pattern_color = Color(0.64, 0.53, 0.30, 1.0)
	condition.line_color = Color(0.88, 0.80, 0.58, 1.0)
	condition.player_speed_multiplier = 0.76
	condition.acceleration_multiplier = 0.68
	condition.stopping_friction_multiplier = 1.35
	condition.slip_chance_per_second = 0.04
	condition.ball_ground_friction_multiplier = 1.75
	condition.ball_air_friction_multiplier = 1.0
	return condition

static func thunder() -> FieldCondition:
	var condition := FieldCondition.rain()
	condition.weather = Weather.THUNDER
	condition.wind_direction = WindDirection.RIGHT
	condition.wind_player_force = 12.0
	condition.wind_ball_force = 26.0
	return condition

static func windy(direction: WindDirection = WindDirection.RIGHT) -> FieldCondition:
	var condition := FieldCondition.grass()
	condition.weather = Weather.WIND
	condition.wind_direction = direction
	condition.wind_player_force = 18.0
	condition.wind_ball_force = 34.0
	return condition

static func from_key(key: String) -> FieldCondition:
	match key.to_lower():
		"rain", "wet", "mud":
			return FieldCondition.rain()
		"snow", "ice":
			return FieldCondition.snow()
		"sand", "dirt":
			return FieldCondition.sand()
		"thunder", "storm":
			return FieldCondition.thunder()
		"wind", "windy":
			return FieldCondition.windy()
		_:
			return FieldCondition.grass()

func get_effective_surface() -> Surface:
	if weather == Weather.RAIN or weather == Weather.THUNDER:
		return Surface.RAIN
	if weather == Weather.SNOW:
		return Surface.SNOW
	return surface

func get_wind_vector() -> Vector2:
	match wind_direction:
		WindDirection.LEFT:
			return Vector2.LEFT
		WindDirection.RIGHT:
			return Vector2.RIGHT
		_:
			return Vector2.ZERO
