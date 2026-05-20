@tool
class_name EnvironmentMap
extends TextureRect

@export_range(-1.0, 1.0, 0.01) var puddle_threshold := 0.20:
	set(value):
		puddle_threshold = value
		_sync_shader_parameters()
@export_range(-1.0, 1.0, 0.01) var swamp_threshold := 0.35:
	set(value):
		swamp_threshold = value
		_sync_shader_parameters()
@export var sample_rect := Rect2(Vector2(50, 45), Vector2(752, 285))
@export var cell_size := Vector2(16, 12)

const PATCH_COLORS := {
	FieldCondition.PatchSet.WET: Color(0.18, 0.32, 0.36, 0.24),
	FieldCondition.PatchSet.PUDDLE: Color(0.18, 0.42, 0.64, 0.36),
	FieldCondition.PatchSet.ICE: Color(0.55, 0.86, 1.0, 0.38),
	FieldCondition.PatchSet.SAND: Color(0.90, 0.78, 0.45, 0.30),
	FieldCondition.PatchSet.MUD: Color(0.20, 0.16, 0.10, 0.36),
	FieldCondition.PatchSet.DUST: Color(0.80, 0.67, 0.38, 0.36)
}

var _noise_image: Image = null


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
	_noise_image = null
	_sync_shader_parameters()


func get_noise_value(world_position: Vector2) -> float:
	var image := _get_noise_image()
	if image == null:
		return -1.0

	var uv := Vector2(
		world_position.x / maxf(size.x, 1.0),
		world_position.y / maxf(size.y, 1.0)
	)
	return _get_filtered_visual_noise(image, uv)


func _get_filtered_visual_noise(image: Image, uv: Vector2) -> float:
	var blur_radius := _get_shader_float("blur_radius", 0.006)
	if blur_radius <= 0.0:
		return _sample_noise_image(image, uv)

	var center := _sample_noise_image(image, uv) * 4.0
	var cardinals := (
		_sample_noise_image(image, uv + Vector2(blur_radius, 0.0))
		+ _sample_noise_image(image, uv + Vector2(-blur_radius, 0.0))
		+ _sample_noise_image(image, uv + Vector2(0.0, blur_radius))
		+ _sample_noise_image(image, uv + Vector2(0.0, -blur_radius))
	)
	var diagonals := (
		_sample_noise_image(image, uv + Vector2(blur_radius, blur_radius))
		+ _sample_noise_image(image, uv + Vector2(-blur_radius, blur_radius))
		+ _sample_noise_image(image, uv + Vector2(blur_radius, -blur_radius))
		+ _sample_noise_image(image, uv + Vector2(-blur_radius, -blur_radius))
	)
	return (center + cardinals * 2.0 + diagonals) / 16.0


func _sample_noise_image(image: Image, uv: Vector2) -> float:
	var wrapped_uv := Vector2(fposmod(uv.x, 1.0), fposmod(uv.y, 1.0))
	var pixel_position := Vector2(
		wrapped_uv.x * float(image.get_width() - 1),
		wrapped_uv.y * float(image.get_height() - 1)
	)
	var x0 := clampi(floori(pixel_position.x), 0, image.get_width() - 1)
	var y0 := clampi(floori(pixel_position.y), 0, image.get_height() - 1)
	var x1 := clampi(x0 + 1, 0, image.get_width() - 1)
	var y1 := clampi(y0 + 1, 0, image.get_height() - 1)
	var tx := pixel_position.x - float(x0)
	var ty := pixel_position.y - float(y0)
	var top := lerpf(image.get_pixel(x0, y0).r, image.get_pixel(x1, y0).r, tx)
	var bottom := lerpf(image.get_pixel(x0, y1).r, image.get_pixel(x1, y1).r, tx)
	return lerpf(top, bottom, ty) * 2.0 - 1.0


func get_step_value(world_position: Vector2, threshold: float) -> int:
	return 1 if get_noise_value(world_position) >= threshold else 0


func apply_patch_set_visuals(patch_set: int) -> void:
	visible = patch_set != FieldCondition.PatchSet.NONE
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return

	shader_material.set_shader_parameter("use_single_patch_mask", visible)
	shader_material.set_shader_parameter("patch_threshold", get_patch_threshold(patch_set))
	shader_material.set_shader_parameter("patch_color", get_patch_color(get_patch_type(patch_set)))
	_sync_shader_parameters()


func get_environment_at(world_position: Vector2) -> int:
	# Legacy two-threshold classification for old puddle/swamp callers.
	# Field patch generation should use get_patch_at() with FieldCondition.get_patch_set().
	if not sample_rect.has_point(world_position):
		return FieldCondition.PatchSet.NONE

	var value := get_noise_value(world_position)
	if value >= swamp_threshold:
		return FieldCondition.PatchSet.MUD
	if value >= puddle_threshold:
		return FieldCondition.PatchSet.PUDDLE
	return FieldCondition.PatchSet.NONE


func get_patch_at(world_position: Vector2, patch_set: int) -> int:
	# Converts the shared Environment noise into the single patch type allowed by the current PatchSet.
	if not sample_rect.has_point(world_position):
		return FieldCondition.PatchSet.NONE

	var sample := get_noise_value(world_position)
	if sample < get_patch_threshold(patch_set):
		return FieldCondition.PatchSet.NONE
	return get_patch_type(patch_set)


static func get_patch_type(patch_set: int) -> int:
	match patch_set:
		FieldCondition.PatchSet.WET:
			return FieldCondition.PatchSet.WET
		FieldCondition.PatchSet.PUDDLE:
			return FieldCondition.PatchSet.PUDDLE
		FieldCondition.PatchSet.ICE:
			return FieldCondition.PatchSet.ICE
		FieldCondition.PatchSet.MUD:
			return FieldCondition.PatchSet.MUD
		FieldCondition.PatchSet.SAND:
			return FieldCondition.PatchSet.SAND
		FieldCondition.PatchSet.DUST:
			return FieldCondition.PatchSet.DUST
		_:
			return FieldCondition.PatchSet.NONE


static func get_patch_threshold(patch_set: int) -> float:
	match patch_set:
		FieldCondition.PatchSet.WET:
			return -0.08
		FieldCondition.PatchSet.PUDDLE:
			return 0.20
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


static func get_patch_color(patch_type: int) -> Color:
	return PATCH_COLORS.get(patch_type, Color.TRANSPARENT)


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


func _get_noise_image() -> Image:
	var noise_texture := texture as NoiseTexture2D
	if noise_texture == null:
		return null
	if _noise_image == null:
		_noise_image = noise_texture.get_image()
	return _noise_image


func _get_shader_float(parameter_name: StringName, fallback: float) -> float:
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return fallback
	var value = shader_material.get_shader_parameter(parameter_name)
	if value == null:
		return fallback
	return float(value)


func _sync_shader_parameters() -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("noise_texture", texture)
	shader_material.set_shader_parameter("puddle_threshold", puddle_threshold)
	shader_material.set_shader_parameter("swamp_threshold", swamp_threshold)
