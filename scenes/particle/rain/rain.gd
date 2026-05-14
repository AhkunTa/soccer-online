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
		"amount": 10,
		"scale_min": 0.3,
		"scale_max": 0.5,
		"splash_amount_at_collision": 1,
		"splash_scale_min": 0.25,
		"splash_scale_max": 0.45,
	},
	RainSize.MEDIUM: {
		"amount": 20,
		"scale_min": 0.4,
		"scale_max": 0.6,
		"splash_amount_at_collision": 2,
		"splash_scale_min": 0.35,
		"splash_scale_max": 0.65,
	},
	RainSize.HEAVY: {
		"amount": 30,
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

@export var splash_enabled := true:
	set(value):
		splash_enabled = value
		_apply_sub_emitter_settings()

@export_range(0.0, 850.0, 1.0) var ground_y := 332.0:
	set(value):
		ground_y = value
		_apply_ground_collision()

@export_range(1.0, 1000.0, 1.0) var ground_width := 850.0:
	set(value):
		ground_width = value
		_apply_ground_collision()

@onready var rain_particles: GPUParticles2D = %Raindrop
@onready var splash_particles: GPUParticles2D = $SplashParticles
@onready var ground_occluder: LightOccluder2D = $GroundOccluder


func _ready() -> void:
	_apply_rain_settings()
	_apply_wind_settings()
	_apply_sub_emitter_settings()
	_apply_ground_collision()
	_apply_emitting()


func set_emitting(enabled: bool) -> void:
	is_raining = enabled
	var particles := _get_rain_particles()
	if particles != null:
		particles.one_shot = false
		particles.visibility_rect = Rect2(-500.0, -80.0, 1850.0, 520.0)
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
	var supports_sub_emitters := _supports_particle_sub_emitters()
	particles.one_shot = false
	particles.visibility_rect = Rect2(-500.0, -80.0, 1850.0, 520.0)
	particles.amount = settings["amount"]
	rain_material.scale_min = settings["scale_min"]
	rain_material.scale_max = settings["scale_max"]
	rain_material.sub_emitter_amount_at_collision = settings["splash_amount_at_collision"] if splash_enabled and supports_sub_emitters else 0

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


func _apply_sub_emitter_settings() -> void:
	var particles := _get_rain_particles()
	var rain_material := _get_rain_process_material()
	if particles == null or rain_material == null:
		return

	var use_sub_emitters := splash_enabled and _supports_particle_sub_emitters()
	particles.sub_emitter = NodePath("../SplashParticles") if use_sub_emitters else NodePath("")
	rain_material.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT if use_sub_emitters else ParticleProcessMaterial.COLLISION_DISABLED
	rain_material.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION if use_sub_emitters else ParticleProcessMaterial.SUB_EMITTER_DISABLED
	_apply_rain_settings()


func _apply_ground_collision() -> void:
	var occluder := _get_ground_occluder()
	if occluder == null:
		return

	occluder.position = Vector2.ZERO
	occluder.occluder = _build_ground_occluder_polygon()


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


func _supports_particle_sub_emitters() -> bool:
	return ProjectSettings.get_setting("rendering/renderer/rendering_method", "") != "gl_compatibility"


func _build_ground_occluder_polygon() -> OccluderPolygon2D:
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(0.0, ground_y),
		Vector2(ground_width, ground_y),
		Vector2(ground_width, ground_y + 28.0),
		Vector2(0.0, ground_y + 28.0),
	])
	return polygon
