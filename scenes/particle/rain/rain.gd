@tool
class_name RainParticles
extends Node2D

enum RainSize {
	SMALL,
	MEDIUM,
	HEAVY,
}

enum WindDirection {
	NONE,
	LEFT,
	RIGHT,
}

const RAIN_SETTINGS := {
	RainSize.SMALL: {
		"amount": 20,
		"scale_min": 0.3,
		"scale_max": 0.5,
		"splash_amount_at_collision": 1,
		"splash_scale_min": 0.25,
		"splash_scale_max": 0.45,
	},
	RainSize.MEDIUM: {
		"amount": 50,
		"scale_min": 0.4,
		"scale_max": 0.6,
		"splash_amount_at_collision": 2,
		"splash_scale_min": 0.35,
		"splash_scale_max": 0.65,
	},
	RainSize.HEAVY: {
		"amount": 80,
		"scale_min": 0.5,
		"scale_max": 0.7,
		"splash_amount_at_collision": 3,
		"splash_scale_min": 0.45,
		"splash_scale_max": 0.85,
	},
}

var is_raining := false
@export var rain_size: RainSize = RainSize.MEDIUM:
	set(value):
		rain_size = value
		_apply_rain_settings()

@export var wind_direction: WindDirection = WindDirection.NONE:
	set(value):
		wind_direction = value
		_apply_wind_settings()

@export_range(0.0, 8.0, 0.1) var wind_strength := 2.0:
	set(value):
		wind_strength = value
		_apply_wind_settings()

@export_range(1.0, 20.0, 0.1) var down_direction := 10.0:
	set(value):
		down_direction = value
		_apply_wind_settings()

@export_range(1.0, 1200.0, 1.0) var rain_width := 970.0:
	set(value):
		rain_width = value
		_apply_rain_emission_area()

@export_range(1.0, 500.0, 1.0) var rain_height := 360.0:
	set(value):
		rain_height = value
		_apply_rain_emission_area()

@export var splash_enabled := true:
	set(value):
		splash_enabled = value
		_apply_sub_emitter_settings()

@export var puddle_rects: Array[Rect2] = [
	Rect2(130.0, 150.0, 110.0, 34.0),
	Rect2(365.0, 238.0, 140.0, 42.0),
	Rect2(610.0, 120.0, 120.0, 36.0),
]:
	set(value):
		puddle_rects = value
		_apply_ground_collision()

@onready var rain_particles: GPUParticles2D = %Raindrop
@onready var splash_particles: GPUParticles2D = $SplashParticles
@onready var ground_occluder: LightOccluder2D = $GroundOccluder
@onready var puddle_occluders: Node2D = $PuddleOccluders


func set_puddle_rects(rects: Array[Rect2]) -> void:
	puddle_rects = rects
	_apply_ground_collision()


func _ready() -> void:
	_enable_particle_z_axis()
	_apply_rain_settings()
	_apply_wind_settings()
	_apply_rain_emission_area()
	_apply_sub_emitter_settings()
	_apply_ground_collision()
	_apply_emitting()


func set_emitting(enabled: bool) -> void:
	is_raining = enabled
	var particles := _get_rain_particles()
	if particles != null:
		particles.one_shot = false
		particles.visibility_rect = Rect2(-500.0, -80.0, 1850.0, 520.0)
		_apply_rain_emission_area()
		particles.emitting = enabled
		if enabled:
			particles.restart()
	var splash := _get_splash_particles()
	if splash != null:
		splash.visibility_rect = Rect2(-500.0, -120.0, 1850.0, 560.0)
		splash.emitting = false


func _process(_delta: float) -> void:
	if not is_raining:
		return
	var particles := _get_rain_particles()
	if particles == null:
		return
	if not particles.emitting:
		particles.emitting = true


func _apply_rain_settings() -> void:
	var particles := _get_rain_particles()
	var rain_material := _get_rain_process_material()
	if particles == null or rain_material == null:
		return

	var settings: Dictionary = RAIN_SETTINGS[rain_size]
	particles.one_shot = false
	particles.visibility_rect = Rect2(-500.0, -80.0, 1850.0, 520.0)
	_apply_rain_emission_area()
	particles.amount = settings["amount"]
	rain_material.scale_min = settings["scale_min"]
	rain_material.scale_max = settings["scale_max"]
	rain_material.sub_emitter_amount_at_collision = settings["splash_amount_at_collision"] if splash_enabled else 0

	var splash := _get_splash_particles()
	var splash_material := _get_splash_process_material()
	if splash != null and splash_material != null:
		splash.one_shot = false
		splash.visibility_rect = Rect2(-500.0, -120.0, 1850.0, 560.0)
		splash.amount = max(settings["amount"] * settings["splash_amount_at_collision"], 1)
		splash_material.scale_min = settings["splash_scale_min"]
		splash_material.scale_max = settings["splash_scale_max"]


func _apply_wind_settings() -> void:
	var rain_material := _get_rain_process_material()
	if rain_material == null:
		return

	var x_direction := 0.0
	match wind_direction:
		WindDirection.LEFT:
			x_direction = - wind_strength
		WindDirection.RIGHT:
			x_direction = wind_strength
		_:
			x_direction = 0.0

	rain_material.direction = Vector3(x_direction, down_direction, 0.0)

	var splash_material := _get_splash_process_material()
	if splash_material != null:
		splash_material.direction = Vector3(x_direction * 0.15, -1.0, 0.0)


func _apply_rain_emission_area() -> void:
	var particles := _get_rain_particles()
	var rain_material := _get_rain_process_material()
	if particles == null or rain_material == null:
		return

	particles.position = Vector2(425.0, -20.0 + rain_height * 0.5)
	rain_material.emission_box_extents = Vector3(rain_width * 0.5, rain_height * 0.5, 1.0)


func _apply_sub_emitter_settings() -> void:
	var particles := _get_rain_particles()
	var rain_material := _get_rain_process_material()
	if particles == null or rain_material == null:
		return

	_enable_particle_z_axis()
	var use_sub_emitters := splash_enabled
	particles.sub_emitter = NodePath("../SplashParticles") if use_sub_emitters else NodePath("")
	rain_material.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT if use_sub_emitters else ParticleProcessMaterial.COLLISION_DISABLED
	rain_material.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION if use_sub_emitters else ParticleProcessMaterial.SUB_EMITTER_DISABLED
	_apply_rain_settings()


func _enable_particle_z_axis() -> void:
	var rain_material := _get_rain_process_material()
	if rain_material != null:
		rain_material.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_DISABLE_Z, false)

	var splash_material := _get_splash_process_material()
	if splash_material != null:
		splash_material.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_DISABLE_Z, false)


func _apply_ground_collision() -> void:
	var occluder := _get_ground_occluder()
	if occluder == null:
		return

	var rects := _get_puddle_rects()
	if rects.is_empty():
		occluder.visible = false
		_rebuild_extra_puddle_occluders()
		return

	occluder.visible = true
	occluder.position = Vector2.ZERO
	occluder.sdf_collision = true
	occluder.occluder = _build_rect_occluder_polygon(rects[0])
	_rebuild_extra_puddle_occluders()


func _apply_emitting() -> void:
	is_raining = visible
	var particles := _get_rain_particles()
	if particles != null:
		particles.emitting = visible
	var splash := _get_splash_particles()
	if splash != null:
		splash.emitting = false


func _get_rain_particles() -> GPUParticles2D:
	if is_instance_valid(rain_particles):
		return rain_particles
	return get_node_or_null("Raindrop") as GPUParticles2D


func _get_splash_particles() -> GPUParticles2D:
	if is_instance_valid(splash_particles):
		return splash_particles
	return get_node_or_null("SplashParticles") as GPUParticles2D


func _get_ground_occluder() -> LightOccluder2D:
	if is_instance_valid(ground_occluder):
		return ground_occluder
	return get_node_or_null("GroundOccluder") as LightOccluder2D


func _get_puddle_occluders_root() -> Node2D:
	if is_instance_valid(puddle_occluders):
		return puddle_occluders
	return get_node_or_null("PuddleOccluders") as Node2D


func _get_rain_process_material() -> ParticleProcessMaterial:
	var particles := _get_rain_particles()
	if particles == null:
		return null
	return particles.process_material as ParticleProcessMaterial


func _get_splash_process_material() -> ParticleProcessMaterial:
	var particles := _get_splash_particles()
	if particles == null:
		return null
	return particles.process_material as ParticleProcessMaterial


func _get_puddle_rects() -> Array[Rect2]:
	return puddle_rects


func _rebuild_extra_puddle_occluders() -> void:
	var root := _get_puddle_occluders_root()
	if root == null:
		return

	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()

	var rects := _get_puddle_rects()
	for i in range(1, rects.size()):
		var occluder := LightOccluder2D.new()
		occluder.name = "PuddleOccluder%d" % i
		occluder.sdf_collision = true
		occluder.occluder = _build_rect_occluder_polygon(rects[i])
		root.add_child(occluder)


func _build_rect_occluder_polygon(rect: Rect2) -> OccluderPolygon2D:
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		rect.position + rect.size,
		Vector2(rect.position.x, rect.position.y + rect.size.y),
	])
	return polygon
