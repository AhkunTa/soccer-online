class_name WeatherSystem
extends Node2D

const VIEWPORT_SIZE := Vector2(850, 360)

var condition: FieldCondition = FieldCondition.grass()
var drops: Array[Dictionary] = []
var flash_alpha := 0.0
var thunder_cooldown := 1.4
var show_weather_particles := true

func setup(new_condition: FieldCondition) -> void:
	condition = new_condition
	_build_particles()
	queue_redraw()

func _process(delta: float) -> void:
	_update_particles(delta)
	if condition.weather == FieldCondition.Weather.THUNDER:
		thunder_cooldown -= delta
		if thunder_cooldown <= 0.0:
			flash_alpha = 0.65
			thunder_cooldown = randf_range(2.0, 4.5)
	flash_alpha = move_toward(flash_alpha, 0.0, delta * 2.8)
	queue_redraw()

func _build_particles() -> void:
	drops.clear()
	if not show_weather_particles:
		return
	var amount := 0
	match condition.weather:
		FieldCondition.Weather.RAIN, FieldCondition.Weather.THUNDER:
			amount = 90
		FieldCondition.Weather.SNOW:
			amount = 70
		FieldCondition.Weather.WIND:
			amount = 35
		_:
			amount = 0
	for i in amount:
		drops.append({
			"pos": Vector2(randf_range(0, VIEWPORT_SIZE.x), randf_range(0, VIEWPORT_SIZE.y)),
			"speed": randf_range(0.75, 1.25),
			"phase": randf_range(0.0, TAU)
		})

func _update_particles(delta: float) -> void:
	if not show_weather_particles:
		return
	var wind := condition.get_wind_vector()
	for drop in drops:
		var pos: Vector2 = drop["pos"]
		var speed: float = drop["speed"]
		match condition.weather:
			FieldCondition.Weather.RAIN, FieldCondition.Weather.THUNDER:
				pos += Vector2(-40.0 + wind.x * 55.0, 250.0) * speed * delta
			FieldCondition.Weather.SNOW:
				pos += Vector2(sin(Time.get_ticks_msec() * 0.003 + drop["phase"]) * 18.0 + wind.x * 20.0, 45.0) * speed * delta
			FieldCondition.Weather.WIND:
				pos += Vector2(120.0 * wind.x, sin(Time.get_ticks_msec() * 0.005 + drop["phase"]) * 18.0) * speed * delta
			_:
				pass
		pos.x = wrapf(pos.x, -20.0, VIEWPORT_SIZE.x + 20.0)
		pos.y = wrapf(pos.y, -20.0, VIEWPORT_SIZE.y + 20.0)
		drop["pos"] = pos

func _draw() -> void:
	if show_weather_particles:
		match condition.weather:
			FieldCondition.Weather.RAIN, FieldCondition.Weather.THUNDER:
				for drop in drops:
					var pos: Vector2 = drop["pos"]
					draw_line(pos, pos + Vector2(-5, 14), Color(0.62, 0.82, 1.0, 0.55), 1.0)
			FieldCondition.Weather.SNOW:
				for drop in drops:
					draw_circle(drop["pos"], 1.0, Color(0.94, 0.98, 1.0, 0.86))
			FieldCondition.Weather.WIND:
				for drop in drops:
					var pos: Vector2 = drop["pos"]
					draw_line(pos, pos + condition.get_wind_vector() * 12.0, Color(0.9, 0.95, 0.9, 0.30), 1.0)
			_:
				pass
	if flash_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), Color(0.9, 0.95, 1.0, flash_alpha), true)
