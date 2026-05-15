class_name FieldPatchMap
extends Node2D

enum PatchType {NORMAL, WET, PUDDLE, SNOW, ICE, LOOSE_SAND, SWAMP, MUD, DUST_DRIFT}

const FIELD_RECT := Rect2(Vector2(50, 45), Vector2(752, 285))
const TILE_SIZE := Vector2(16, 12) # 小长方形采样格，比正方形大块更细碎。
const PATCH_EDGE_JITTER := 3.0 # 只影响视觉边缘，不影响碰撞/物理采样所属格子。
const NORMAL_MODIFIER := {
	"player_speed": 1.0,
	"acceleration": 1.0,
	"stopping_friction": 1.0,
	"slip": 0.0,
	"ball_ground_friction": 1.0
}
const PATCH_MODIFIERS := {
	PatchType.WET: {
		"player_speed": 0.94,
		"acceleration": 0.86,
		"stopping_friction": 0.65,
		"slip": 0.08,
		"ball_ground_friction": 1.18
	},
	PatchType.PUDDLE: {
		"player_speed": 0.78,
		"acceleration": 0.62,
		"stopping_friction": 0.38,
		"slip": 0.22,
		"ball_ground_friction": 1.65
	},
	PatchType.SNOW: {
		"player_speed": 0.86,
		"acceleration": 0.72,
		"stopping_friction": 0.52,
		"slip": 0.10,
		"ball_ground_friction": 0.86
	},
	PatchType.ICE: {
		"player_speed": 0.96,
		"acceleration": 0.48,
		"stopping_friction": 0.20,
		"slip": 0.30,
		"ball_ground_friction": 0.42
	},
	PatchType.LOOSE_SAND: {
		"player_speed": 0.76,
		"acceleration": 0.70,
		"stopping_friction": 1.45,
		"slip": 0.02,
		"ball_ground_friction": 1.85
	},
	PatchType.SWAMP: {
		"player_speed": 0.58,
		"acceleration": 0.44,
		"stopping_friction": 0.26,
		"slip": 0.18,
		"ball_ground_friction": 2.35
	},
	PatchType.MUD: {
		"player_speed": 0.72,
		"acceleration": 0.58,
		"stopping_friction": 0.38,
		"slip": 0.14,
		"ball_ground_friction": 1.90
	},
	PatchType.DUST_DRIFT: {
		"player_speed": 0.68,
		"acceleration": 0.58,
		"stopping_friction": 1.70,
		"slip": 0.05,
		"ball_ground_friction": 2.05
	}
}
const PATCH_COLORS := {
	PatchType.WET: Color(0.18, 0.32, 0.36, 0.24),
	PatchType.PUDDLE: Color(0.18, 0.42, 0.64, 0.36),
	PatchType.SNOW: Color(0.88, 0.96, 1.0, 0.40),
	PatchType.ICE: Color(0.55, 0.86, 1.0, 0.38),
	PatchType.LOOSE_SAND: Color(0.90, 0.78, 0.45, 0.30),
	PatchType.SWAMP: Color(0.12, 0.22, 0.13, 0.42),
	PatchType.MUD: Color(0.20, 0.16, 0.10, 0.36),
	PatchType.DUST_DRIFT: Color(0.80, 0.67, 0.38, 0.36)
}

var field_condition: FieldCondition
var environment_map: EnvironmentMap
var terrain_grid: Array[Array] = []
var generation_seed := 0
var columns := 0
var rows := 0

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
		return PatchType.NORMAL
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
		return PatchType.NORMAL
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
	var modifier: Dictionary = PATCH_MODIFIERS.get(patch, NORMAL_MODIFIER)
	return modifier.get(key, NORMAL_MODIFIER[key])

func _draw() -> void:
	if terrain_grid.is_empty():
		return
	for y in rows:
		for x in columns:
			var patch: int = terrain_grid[y][x]
			if patch == PatchType.NORMAL:
				continue
			var color: Color = PATCH_COLORS.get(patch, Color.TRANSPARENT)
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
