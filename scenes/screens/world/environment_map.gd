@tool
class_name EnvironmentMap
extends TextureRect

enum EnvironmentType {
	# Keep this order aligned with FieldPatchMap.PatchType.
	NONE,
	WET,
	PUDDLE,
	SNOW,
	ICE,
	LOOSE_SAND,
	SWAMP,
	MUD,
	DUST_DRIFT,
}

@export var noise_scale := 10.0
@export_range(-1.0, 1.0, 0.01) var puddle_threshold := 0.20:
	set(value):
		puddle_threshold = value
		_sync_shader_parameters()
@export_range(-1.0, 1.0, 0.01) var swamp_threshold := 0.35:
	set(value):
		swamp_threshold = value
		_sync_shader_parameters()
@export_range(0.0, 4.0, 0.1) var sample_blur_cells := 0.5
@export var sample_rect := Rect2(Vector2(50, 45), Vector2(752, 285))
@export var cell_size := Vector2(16, 12)


func _ready() -> void:
	_sync_shader_parameters()


func set_noise_seed(seed_value: int) -> void:
	var noise_texture := texture as NoiseTexture2D
	if noise_texture == null:
		return
	var noise := noise_texture.noise as FastNoiseLite
	if noise == null:
		return

	var seeded_noise := noise.duplicate() as FastNoiseLite
	seeded_noise.seed = seed_value
	noise_texture.noise = seeded_noise
	_sync_shader_parameters()


func get_noise_value(world_position: Vector2) -> float:
	var noise := _get_noise()
	if noise == null:
		return -1.0

	var local_position := world_position - sample_rect.position
	var sample_position := local_position / noise_scale
	if sample_blur_cells <= 0.0:
		return noise.get_noise_2d(sample_position.x, sample_position.y)

	var offset := sample_blur_cells
	var center := noise.get_noise_2d(sample_position.x, sample_position.y) * 4.0
	var cardinals := (
		noise.get_noise_2d(sample_position.x + offset, sample_position.y)
		+ noise.get_noise_2d(sample_position.x - offset, sample_position.y)
		+ noise.get_noise_2d(sample_position.x, sample_position.y + offset)
		+ noise.get_noise_2d(sample_position.x, sample_position.y - offset)
	)
	var diagonals := (
		noise.get_noise_2d(sample_position.x + offset, sample_position.y + offset)
		+ noise.get_noise_2d(sample_position.x - offset, sample_position.y + offset)
		+ noise.get_noise_2d(sample_position.x + offset, sample_position.y - offset)
		+ noise.get_noise_2d(sample_position.x - offset, sample_position.y - offset)
	)
	return (center + cardinals * 2.0 + diagonals) / 16.0


func get_step_value(world_position: Vector2, threshold: float) -> int:
	return 1 if get_noise_value(world_position) >= threshold else 0


func get_environment_at(world_position: Vector2) -> int:
	# Legacy two-threshold classification for old puddle/swamp callers.
	# Field patch generation should use get_patch_at() with FieldCondition.get_patch_set().
	if not sample_rect.has_point(world_position):
		return EnvironmentType.NONE

	var value := get_noise_value(world_position)
	if value >= swamp_threshold:
		return EnvironmentType.SWAMP
	if value >= puddle_threshold:
		return EnvironmentType.PUDDLE
	return EnvironmentType.NONE


func get_patch_at(world_position: Vector2, patch_set: int) -> int:
	# Converts the shared Environment noise into the single patch type allowed by the current PatchSet.
	if not sample_rect.has_point(world_position):
		return EnvironmentType.NONE

	var sample := get_noise_value(world_position)
	if sample < get_patch_threshold(patch_set):
		return EnvironmentType.NONE
	return get_patch_type(patch_set)


static func get_patch_type(patch_set: int) -> int:
	match patch_set:
		FieldCondition.PatchSet.WET:
			return EnvironmentType.WET
		FieldCondition.PatchSet.ICE:
			return EnvironmentType.ICE
		FieldCondition.PatchSet.MUD:
			return EnvironmentType.MUD
		FieldCondition.PatchSet.SAND:
			return EnvironmentType.LOOSE_SAND
		FieldCondition.PatchSet.DUST:
			return EnvironmentType.DUST_DRIFT
		_:
			return EnvironmentType.NONE


static func get_patch_threshold(patch_set: int) -> float:
	match patch_set:
		FieldCondition.PatchSet.WET:
			return -0.08
		FieldCondition.PatchSet.ICE:
			return -0.12
		FieldCondition.PatchSet.MUD:
			return -0.22
		FieldCondition.PatchSet.SAND:
			return 0.30
		FieldCondition.PatchSet.DUST:
			return -0.20
		_:
			return 1.0
	return 1.0


func get_environment_rects(target_type: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var columns := int(ceil(sample_rect.size.x / cell_size.x))
	var rows := int(ceil(sample_rect.size.y / cell_size.y))

	for y in rows:
		for x in columns:
			var rect := Rect2(sample_rect.position + Vector2(x, y) * cell_size, cell_size)
			if get_environment_at(rect.get_center()) == target_type:
				rects.append(rect)
	return rects


func get_patch_rects(target_patch_types: Array, patch_set: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var columns := int(ceil(sample_rect.size.x / cell_size.x))
	var rows := int(ceil(sample_rect.size.y / cell_size.y))

	for y in rows:
		for x in columns:
			var rect := Rect2(sample_rect.position + Vector2(x, y) * cell_size, cell_size)
			var patch := get_patch_at(rect.get_center(), patch_set)
			if target_patch_types.has(patch):
				rects.append(rect)
	return rects


func _get_noise() -> FastNoiseLite:
	var noise_texture := texture as NoiseTexture2D
	if noise_texture == null:
		return null
	return noise_texture.noise as FastNoiseLite


func _sync_shader_parameters() -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("noise_texture", texture)
	shader_material.set_shader_parameter("puddle_threshold", puddle_threshold)
	shader_material.set_shader_parameter("swamp_threshold", swamp_threshold)
