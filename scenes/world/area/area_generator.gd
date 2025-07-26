class_name RandomAreaGenerator
extends Node2D

# Ensure RandomArea is available
const RandomArea = preload("res://scenes/world/area/random_area.gd")

# 区域类型枚举（与 RandomArea 同步）
enum AreaType {
	POWERUP_ZONE,    # 道具区域
	PENALTY_ZONE,    # 惩罚区域
	SPEED_BOOST,     # 速度提升区域
	HEALING_ZONE,    # 治疗区域
	DANGER_ZONE      # 危险区域
}

# 区域配置
@export var area_count_min: int = 3
@export var area_count_max: int = 8
@export var area_size_min: Vector2 = Vector2(50, 50)
@export var area_size_max: Vector2 = Vector2(150, 150)
@export var spawn_bounds: Rect2 = Rect2(50, 50, 750, 260)  # 生成边界
@export var generation_interval: float = 30.0  # 重新生成间隔（秒）

# 区域颜色配置
const AREA_COLORS: Dictionary = {
	AreaType.POWERUP_ZONE: Color.BLUE,
	AreaType.PENALTY_ZONE: Color.RED,
	AreaType.SPEED_BOOST: Color.GREEN,
	AreaType.HEALING_ZONE: Color.YELLOW,
	AreaType.DANGER_ZONE: Color.PURPLE
}

# 区域透明度
const AREA_ALPHA: float = 0.3

# 存储当前区域
var active_areas: Array[RandomArea] = []
var generation_timer: Timer

# 信号
signal area_generated(area: RandomArea)
signal area_removed(area: RandomArea)
signal player_entered_area(player: Player, area: RandomArea)
signal player_exited_area(player: Player, area: RandomArea)

func _ready() -> void:
	setup_generation_timer()
	generate_initial_areas()

func setup_generation_timer() -> void:
	generation_timer = Timer.new()
	generation_timer.wait_time = generation_interval
	generation_timer.timeout.connect(_on_generation_timer_timeout)
	generation_timer.autostart = true
	add_child(generation_timer)

func generate_initial_areas() -> void:
	clear_all_areas()
	var area_count = randi_range(area_count_min, area_count_max)
	
	for i in area_count:
		var area_type = RandomArea.AreaType.values()[randi() % RandomArea.AreaType.size()]
		generate_random_area(area_type)

func generate_random_area(type: RandomArea.AreaType) -> RandomArea:
	var area = RandomArea.new()
	area.setup(type, get_random_position(), get_random_size())
	area.modulate = AREA_COLORS[type]
	area.modulate.a = AREA_ALPHA
	
	# 连接信号
	area.player_entered.connect(_on_player_entered_area.bind(area))
	area.player_exited.connect(_on_player_exited_area.bind(area))
	
	add_child(area)
	active_areas.append(area)
	area_generated.emit(area)
	
	return area

func get_random_position() -> Vector2:
	var x = randf_range(spawn_bounds.position.x, spawn_bounds.position.x + spawn_bounds.size.x)
	var y = randf_range(spawn_bounds.position.y, spawn_bounds.position.y + spawn_bounds.size.y)
	return Vector2(x, y)

func get_random_size() -> Vector2:
	var width = randf_range(area_size_min.x, area_size_max.x)
	var height = randf_range(area_size_min.y, area_size_max.y)
	return Vector2(width, height)

func clear_all_areas() -> void:
	for area in active_areas:
		area.queue_free()
		area_removed.emit(area)
	active_areas.clear()

func _on_generation_timer_timeout() -> void:
	# 随机移除一些区域
	if active_areas.size() > 0:
		var remove_count = randi_range(1, min(3, active_areas.size()))
		for i in remove_count:
			var area = active_areas.pick_random()
			remove_area(area)
	
	# 生成新区域
	var new_count = randi_range(1, 3)
	for i in new_count:
		var area_type = AreaType.values()[randi() % AreaType.size()]
		generate_random_area(area_type)

func remove_area(area: RandomArea) -> void:
	if area in active_areas:
		active_areas.erase(area)
		area.queue_free()
		area_removed.emit(area)

func _on_player_entered_area(area: RandomArea, player: Player) -> void:
	player_entered_area.emit(player, area)
	apply_area_effect(player, area, true)

func _on_player_exited_area(area: RandomArea, player: Player) -> void:
	player_exited_area.emit(player, area)
	apply_area_effect(player, area, false)

func apply_area_effect(player: Player, area: RandomArea, entering: bool) -> void:
	match area.area_type:
		AreaType.POWERUP_ZONE:
			if entering:
				player.apply_temporary_boost("power", 1.5, 10.0)
		AreaType.PENALTY_ZONE:
			if entering:
				player.apply_temporary_boost("speed", 0.5, 5.0)
		AreaType.SPEED_BOOST:
			if entering:
				player.apply_temporary_boost("speed", 1.8, 8.0)
		AreaType.HEALING_ZONE:
			if entering:
				player.start_healing(2.0)  # 每秒恢复2点
			else:
				player.stop_healing()
		AreaType.DANGER_ZONE:
			if entering:
				player.apply_damage(1.0)  # 进入时造成伤害

# 获取指定位置的区域
func get_area_at_position(pos: Vector2) -> RandomArea:
	for area in active_areas:
		if area.contains_point(pos):
			return area
	return null

# 获取指定类型的所有区域
func get_areas_by_type(type: AreaType) -> Array[RandomArea]:
	var result: Array[RandomArea] = []
	for area in active_areas:
		if area.area_type == type:
			result.append(area)
	return result
