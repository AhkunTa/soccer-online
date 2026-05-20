class_name FieldPatchMap
extends Node2D

const FIELD_RECT := Rect2(Vector2(50, 45), Vector2(752, 285))
const TILE_SIZE := Vector2(16, 12) # 小长方形采样格，比正方形大块更细碎。
const PATCH_EDGE_JITTER := 3.0 # 只影响视觉边缘，不影响碰撞/物理采样所属格子。

var field_condition: FieldCondition
var environment_map: EnvironmentMap
var terrain_grid: Array[Array] = []
var generation_seed := 0
var columns := 0
var rows := 0
var draw_visual_patches := true

func generate(condition: FieldCondition, seed_value: int, source_environment_map: EnvironmentMap = null) -> void:
	print("Generating FieldPatchMap with condition: %s, seed: %d" % [condition, seed_value])
	field_condition = condition
	environment_map = source_environment_map
	generation_seed = seed_value
	columns = int(ceil(FIELD_RECT.size.x / TILE_SIZE.x))
	rows = int(ceil(FIELD_RECT.size.y / TILE_SIZE.y))

	# 初始化时把整片球场离散成固定网格。
	# 后续玩家/球的物理效果只查 terrain_grid，不依赖 _draw() 的视觉多边形。
	terrain_grid.clear()
	for y in rows:
		var row: Array = []
		for x in columns:
			var rect := Rect2(FIELD_RECT.position + Vector2(x, y) * TILE_SIZE, TILE_SIZE)
			row.append(_pick_patch_at(rect.get_center(), seed_value))
		terrain_grid.append(row)
	queue_redraw()

func get_patch_at(global_world_position: Vector2) -> int:
	# 调用方传 global_position；FieldPatchMap 自己转换到本地网格坐标。
	# 这样角色层、球层、背景层即使父节点不同，也能查到同一片地块。
	var map_position := to_local(global_world_position)
	if terrain_grid.is_empty() or not FIELD_RECT.has_point(map_position):
		return FieldCondition.PatchSet.NONE
	var local_position := map_position - FIELD_RECT.position
	var x := clampi(int(local_position.x / TILE_SIZE.x), 0, columns - 1)
	var y := clampi(int(local_position.y / TILE_SIZE.y), 0, rows - 1)
	return terrain_grid[y][x]

func get_patch_rects(target_patch_types: Array) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if terrain_grid.is_empty():
		return rects

	for y in rows:
		for x in columns:
			var patch: int = terrain_grid[y][x]
			if not target_patch_types.has(patch):
				continue
			rects.append(Rect2(FIELD_RECT.position + Vector2(x, y) * TILE_SIZE, TILE_SIZE))
	return rects

func get_player_speed_multiplier(world_position: Vector2) -> float:
	return _get_modifier_value(world_position, "player_speed")

func get_acceleration_multiplier(world_position: Vector2) -> float:
	return _get_modifier_value(world_position, "acceleration")

func get_stopping_friction_multiplier(world_position: Vector2) -> float:
	return _get_modifier_value(world_position, "stopping_friction")

func get_slip_chance_bonus(world_position: Vector2) -> float:
	return _get_modifier_value(world_position, "slip")

func get_ball_ground_friction_multiplier(world_position: Vector2) -> float:
	return _get_modifier_value(world_position, "ball_ground_friction")

func _pick_patch_at(world_position: Vector2, seed_value: int) -> int:
	# PatchSet 决定这场比赛允许出现哪一种特殊地块；
	# 噪声只决定这个位置是否生成特殊地块，不再在同一 PatchSet 中混出多种块。
	var patch_set := field_condition.get_patch_set()
	if environment_map != null:
		return environment_map.get_patch_at(world_position, patch_set)

	var sample := _get_environment_sample(world_position, seed_value)
	if sample < EnvironmentMap.get_patch_threshold(patch_set):
		return FieldCondition.PatchSet.NONE
	return EnvironmentMap.get_patch_type(patch_set)

func _get_environment_sample(world_position: Vector2, seed_value: int) -> float:
	if environment_map != null:
		return environment_map.get_noise_value(world_position)

	# Fallback keeps FieldPatchMap usable in tests or scenes without EnvironmentMap.
	var fallback_noise := FastNoiseLite.new()
	fallback_noise.seed = seed_value
	fallback_noise.frequency = 0.12
	fallback_noise.fractal_octaves = 3
	fallback_noise.fractal_lacunarity = 2.0
	fallback_noise.fractal_gain = 0.5
	var local_position := world_position - FIELD_RECT.position
	return fallback_noise.get_noise_2d(local_position.x / TILE_SIZE.x, local_position.y / TILE_SIZE.y)

func _get_modifier_value(world_position: Vector2, key: String) -> float:
	var patch := get_patch_at(world_position)
	return FieldCondition.get_patch_modifier_value(patch, key)

func _draw() -> void:
	if terrain_grid.is_empty() or not draw_visual_patches:
		return
	for y in rows:
		for x in columns:
			var patch: int = terrain_grid[y][x]
			if patch == FieldCondition.PatchSet.NONE:
				continue
			var color := EnvironmentMap.get_patch_color(patch)
			var rect := Rect2(FIELD_RECT.position + Vector2(x, y) * TILE_SIZE, TILE_SIZE)
			draw_colored_polygon(_build_patch_polygon(rect, x, y), color)

func _build_patch_polygon(rect: Rect2, x: int, y: int) -> PackedVector2Array:
	# 用 8 个点画一个轻微变形的矩形：四个角 + 四条边的中点。
	# 相邻格子会通过 grid 坐标复用同一批扰动点，避免每块独立抖动造成边缘断裂。
	var left := rect.position.x
	var top := rect.position.y
	var field_end := FIELD_RECT.position + FIELD_RECT.size
	var right := minf(rect.position.x + rect.size.x, field_end.x)
	var bottom := minf(rect.position.y + rect.size.y, field_end.y)
	var center_x := (left + right) * 0.5
	var center_y := (top + bottom) * 0.5
	var jitter := minf(PATCH_EDGE_JITTER, minf(rect.size.x, rect.size.y) * 0.28)
	return PackedVector2Array([
		_jitter_grid_point(Vector2(left, top), x, y, 0, jitter),
		_jitter_grid_point(Vector2(center_x, top), x, y, 1, jitter),
		_jitter_grid_point(Vector2(right, top), x + 1, y, 0, jitter),
		_jitter_grid_point(Vector2(right, center_y), x + 1, y, 2, jitter),
		_jitter_grid_point(Vector2(right, bottom), x + 1, y + 1, 0, jitter),
		_jitter_grid_point(Vector2(center_x, bottom), x, y + 1, 1, jitter),
		_jitter_grid_point(Vector2(left, bottom), x, y + 1, 0, jitter),
		_jitter_grid_point(Vector2(left, center_y), x, y, 2, jitter),
	])

func _jitter_grid_point(point: Vector2, grid_x: int, grid_y: int, point_kind: int, amount: float) -> Vector2:
	# point_kind:
	# 0 = 网格角点，1 = 水平边中点，2 = 垂直边中点。
	# 只使用共享的 grid_x/grid_y/kind 作为随机键，相邻格子的公共边会得到同一个坐标。
	var offset := Vector2(
		_cell_noise(grid_x, grid_y, point_kind * 2) * amount,
		_cell_noise(grid_x, grid_y, point_kind * 2 + 1) * amount
	)
	var jittered := point + offset
	var field_end := FIELD_RECT.position + FIELD_RECT.size
	return Vector2(
		clampf(jittered.x, FIELD_RECT.position.x, field_end.x),
		clampf(jittered.y, FIELD_RECT.position.y, field_end.y)
	)

func _cell_noise(x: int, y: int, salt: int) -> float:
	var value := sin(float(x * 127 + y * 311 + salt * 47 + generation_seed * 17)) * 43758.5453
	return fposmod(value, 1.0) * 2.0 - 1.0
