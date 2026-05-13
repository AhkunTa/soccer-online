class_name FieldPatchMap
extends Node2D

enum PatchType {NORMAL, WET, PUDDLE, SNOW, ICE, LOOSE_SAND, SWAMP, MUD, DUST_DRIFT}

const FIELD_RECT := Rect2(Vector2(50, 45), Vector2(752, 285))
const TILE_SIZE := Vector2(24, 24)
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

var noise := FastNoiseLite.new()
var field_condition: FieldCondition
var terrain_grid: Array[Array] = []
var columns := 0
var rows := 0

func generate(condition: FieldCondition, seed_value: int) -> void:
	field_condition = condition
	columns = int(ceil(FIELD_RECT.size.x / TILE_SIZE.x))
	rows = int(ceil(FIELD_RECT.size.y / TILE_SIZE.y))
	noise.seed = seed_value
	noise.frequency = 0.12
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

	terrain_grid.clear()
	for y in rows:
		var row: Array = []
		for x in columns:
			var sample := noise.get_noise_2d(float(x), float(y))
			row.append(_pick_patch(sample))
		terrain_grid.append(row)
	queue_redraw()

func get_patch_at(world_position: Vector2) -> int:
	if terrain_grid.is_empty() or not FIELD_RECT.has_point(world_position):
		return PatchType.NORMAL
	var local_position := world_position - FIELD_RECT.position
	var x := clampi(int(local_position.x / TILE_SIZE.x), 0, columns - 1)
	var y := clampi(int(local_position.y / TILE_SIZE.y), 0, rows - 1)
	return terrain_grid[y][x]

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

func _pick_patch(sample: float) -> int:
	match field_condition.get_patch_set():
		FieldCondition.PatchSet.WET:
			if sample > 0.2:
				return PatchType.PUDDLE
			if sample > -0.08:
				return PatchType.WET
		FieldCondition.PatchSet.ICE:
			if sample > 0.3:
				return PatchType.ICE
			if sample > -0.12:
				return PatchType.SNOW
		FieldCondition.PatchSet.MUD:
			if sample > 0.08:
				return PatchType.SWAMP
			if sample > -0.22:
				return PatchType.MUD
		FieldCondition.PatchSet.SAND:
			if sample > 0.3:
				return PatchType.LOOSE_SAND
		FieldCondition.PatchSet.DUST:
			if sample > 0.12:
				return PatchType.DUST_DRIFT
			if sample > -0.2:
				return PatchType.LOOSE_SAND
		_:
			pass
	return PatchType.NORMAL

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
			draw_rect(rect, color, true)
