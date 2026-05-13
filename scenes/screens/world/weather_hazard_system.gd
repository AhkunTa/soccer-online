class_name WeatherHazardSystem
extends Node2D

const HAZARD_DAMAGE := 12.0
const LIGHTNING_DURATION := 1.4
const TORNADO_DURATION := 3.0
const MIN_SPAWN_INTERVAL := 3.0
const MAX_SPAWN_INTERVAL := 6.0
const VIEW_MARGIN := 18.0

var condition: FieldCondition = null
var camera: Camera2D = null
var actors_container: ActorsContainer = null
var active_hazards: Array[Dictionary] = []
var spawn_timer := 0.0

func setup(new_condition: FieldCondition, new_camera: Camera2D, new_actors_container: ActorsContainer) -> void:
	condition = new_condition
	camera = new_camera
	actors_container = new_actors_container
	_reset_spawn_timer()

func _process(delta: float) -> void:
	_update_active_hazards(delta)
	if SyncManager.is_client():
		queue_redraw()
		return
	if not _can_spawn_hazard():
		queue_redraw()
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_try_spawn_hazard()
		_reset_spawn_timer()
	queue_redraw()

func _can_spawn_hazard() -> bool:
	return condition != null and camera != null and actors_container != null \
		and (condition.weather == FieldCondition.Weather.THUNDER or condition.weather == FieldCondition.Weather.WIND)

func _try_spawn_hazard() -> void:
	var hazard_type := _get_current_hazard_type()
	if hazard_type == FieldCondition.HazardType.NONE:
		return
	if _get_hazard_count(hazard_type) >= condition.get_max_hazard_count(hazard_type):
		return
	if randf() <= condition.get_hazard_threshold(hazard_type):
		return
	var hazard_position := _get_random_position_in_camera()
	var duration := LIGHTNING_DURATION if hazard_type == FieldCondition.HazardType.LIGHTNING else TORNADO_DURATION
	active_hazards.append({"type": hazard_type, "position": hazard_position, "time_left": duration, "duration": duration})
	_hurt_all_players(hazard_position)
	GameEvents.impact_received.emit(hazard_position, true)

func _get_current_hazard_type() -> int:
	match condition.weather:
		FieldCondition.Weather.THUNDER:
			return FieldCondition.HazardType.LIGHTNING
		FieldCondition.Weather.WIND:
			return FieldCondition.HazardType.TORNADO
		_:
			return FieldCondition.HazardType.NONE

func _get_random_position_in_camera() -> Vector2:
	var viewport_size := get_viewport_rect().size / camera.zoom
	var center := camera.get_screen_center_position()
	var min_position := center - viewport_size * 0.5 + Vector2.ONE * VIEW_MARGIN
	var max_position := center + viewport_size * 0.5 - Vector2.ONE * VIEW_MARGIN
	return Vector2(randf_range(min_position.x, max_position.x), randf_range(min_position.y, max_position.y))

func _hurt_all_players(hazard_position: Vector2) -> void:
	for player in actors_container.all_players:
		if player == null or not is_instance_valid(player):
			continue
		player.current_hp = maxf(0.0, player.current_hp - HAZARD_DAMAGE)
		var hurt_direction := hazard_position.direction_to(player.position)
		if hurt_direction == Vector2.ZERO:
			hurt_direction = Vector2.RIGHT
		player.get_hurt(hurt_direction)

func _update_active_hazards(delta: float) -> void:
	for i in range(active_hazards.size() - 1, -1, -1):
		active_hazards[i]["time_left"] -= delta
		if active_hazards[i]["time_left"] <= 0.0:
			active_hazards.remove_at(i)

func _get_hazard_count(hazard_type: int) -> int:
	var count := 0
	for hazard in active_hazards:
		if hazard["type"] == hazard_type:
			count += 1
	return count

func _reset_spawn_timer() -> void:
	spawn_timer = randf_range(MIN_SPAWN_INTERVAL, MAX_SPAWN_INTERVAL)

func _draw() -> void:
	for hazard in active_hazards:
		var hazard_position: Vector2 = hazard["position"]
		var alpha := clampf(float(hazard["time_left"]) / float(hazard["duration"]), 0.0, 1.0)
		match hazard["type"]:
			FieldCondition.HazardType.LIGHTNING:
				_draw_lightning(hazard_position, alpha)
			FieldCondition.HazardType.TORNADO:
				_draw_tornado(hazard_position, alpha)

func _draw_lightning(position: Vector2, alpha: float) -> void:
	var color := Color(1.0, 0.95, 0.22, 0.95 * alpha)
	draw_line(position + Vector2(0, -42), position + Vector2(-10, -8), color, 3.0)
	draw_line(position + Vector2(-10, -8), position + Vector2(7, -8), color, 3.0)
	draw_line(position + Vector2(7, -8), position + Vector2(-4, 28), color, 3.0)
	draw_circle(position, 18.0 * alpha, Color(1.0, 0.95, 0.35, 0.20 * alpha))

func _draw_tornado(position: Vector2, alpha: float) -> void:
	var color := Color(0.82, 0.80, 0.68, 0.78 * alpha)
	draw_arc(position + Vector2(0, -20), 18.0, 0.2, TAU * 0.9, 24, color, 3.0)
	draw_arc(position + Vector2(0, -5), 13.0, 0.4, TAU * 0.9, 20, color, 3.0)
	draw_arc(position + Vector2(0, 8), 8.0, 0.6, TAU * 0.85, 16, color, 2.5)
	draw_arc(position + Vector2(0, 18), 4.0, 0.8, TAU * 0.75, 12, color, 2.0)
