class_name RandomArea
extends Area2D

# 区域类型枚举（与 RandomAreaGenerator 同步）
enum AreaType {
	POWERUP_ZONE,    # 道具区域
	PENALTY_ZONE,    # 惩罚区域
	SPEED_BOOST,     # 速度提升区域
	HEALING_ZONE,    # 治疗区域
	DANGER_ZONE      # 危险区域
}

var area_type: AreaType
var area_size: Vector2
var players_inside: Array[Player] = []
var shape_points: PackedVector2Array = []  # 存储不规则形状的点

# 视觉组件
var visual_polygon: Polygon2D
var border_line: Line2D
var label: Label

# 信号
signal player_entered(player: Player)
signal player_exited(player: Player)

func setup(type: AreaType, pos: Vector2, size: Vector2) -> void:
	area_type = type
	area_size = size
	position = pos
	
	# 先生成不规则形状的点
	generate_irregular_shape()
	
	create_visual_components()
	create_collision_shape()
	setup_detection()
	
	# 更新视觉样式
	update_visual_style()

# 生成不规则形状的点
func generate_irregular_shape() -> void:
	shape_points.clear()
	
	# 根据区域类型选择不同的形状生成方法
	match area_type:
		AreaType.POWERUP_ZONE:
			generate_star_shape()
		AreaType.PENALTY_ZONE:
			generate_jagged_shape()
		AreaType.SPEED_BOOST:
			generate_arrow_shape()
		AreaType.HEALING_ZONE:
			generate_flower_shape()
		AreaType.DANGER_ZONE:
			generate_spiky_shape()
		_:
			generate_random_polygon()

# 生成星形
func generate_star_shape() -> void:
	var center = Vector2.ZERO
	var outer_radius = min(area_size.x, area_size.y) * 0.4
	var inner_radius = outer_radius * 0.5
	var points = 5
	
	for i in range(points * 2):
		var angle = i * PI / points
		var radius = outer_radius if i % 2 == 0 else inner_radius
		var point = center + Vector2(cos(angle), sin(angle)) * radius
		shape_points.append(point)

# 生成锯齿形状
func generate_jagged_shape() -> void:
	var width = area_size.x * 0.5
	var height = area_size.y * 0.5
	var segments = 6
	
	# 创建锯齿边界
	for i in range(segments):
		var t = float(i) / (segments - 1)
		var x = lerp(-width, width, t)
		var y_base = lerp(-height, height, t)
		var jitter = randf_range(-20, 20)
		shape_points.append(Vector2(x + jitter, y_base + jitter))

# 生成箭头形状
func generate_arrow_shape() -> void:
	var width = area_size.x * 0.4
	var height = area_size.y * 0.4
	
	shape_points.append(Vector2(width, 0))        # 箭头尖
	shape_points.append(Vector2(width * 0.3, height * 0.3))
	shape_points.append(Vector2(width * 0.3, height * 0.1))
	shape_points.append(Vector2(-width, height * 0.1))
	shape_points.append(Vector2(-width, -height * 0.1))
	shape_points.append(Vector2(width * 0.3, -height * 0.1))
	shape_points.append(Vector2(width * 0.3, -height * 0.3))

# 生成花朵形状
func generate_flower_shape() -> void:
	var center = Vector2.ZERO
	var radius = min(area_size.x, area_size.y) * 0.3
	var petals = 6
	
	for i in range(petals * 3):
		var angle = i * 2 * PI / (petals * 3)
		var r = radius
		# 创建花瓣效果
		if i % 3 == 1:
			r *= 1.5
		var point = center + Vector2(cos(angle), sin(angle)) * r
		shape_points.append(point)

# 生成尖刺形状
func generate_spiky_shape() -> void:
	var center = Vector2.ZERO
	var base_radius = min(area_size.x, area_size.y) * 0.3
	var spikes = 8
	
	for i in range(spikes * 2):
		var angle = i * PI / spikes
		var radius = base_radius if i % 2 == 0 else base_radius * 1.8
		var point = center + Vector2(cos(angle), sin(angle)) * radius
		shape_points.append(point)

# 生成随机多边形
func generate_random_polygon() -> void:
	var center = Vector2.ZERO
	var base_radius = min(area_size.x, area_size.y) * 0.3
	var vertices = randi_range(6, 10)
	
	for i in range(vertices):
		var angle = i * 2 * PI / vertices
		var radius = base_radius * randf_range(0.7, 1.3)
		var point = center + Vector2(cos(angle), sin(angle)) * radius
		shape_points.append(point)

func create_visual_components() -> void:
	# 创建多边形背景
	visual_polygon = Polygon2D.new()
	visual_polygon.polygon = shape_points
	visual_polygon.color = Color.WHITE
	add_child(visual_polygon)
	
	# 创建边框线条
	border_line = Line2D.new()
	border_line.points = shape_points
	border_line.closed = true
	border_line.width = 3.0
	border_line.default_color = Color.BLACK
	add_child(border_line)
	
	# 创建标签
	label = Label.new()
	label.text = get_area_type_name()
	label.position = -area_size / 2
	label.size = area_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)

func create_collision_shape() -> void:
	var collision_shape = CollisionShape2D.new()
	
	# 使用ConvexPolygonShape2D创建不规则碰撞形状
	var polygon_shape = ConvexPolygonShape2D.new()
	
	# 确保点数不超过ConvexPolygonShape2D的限制
	var simplified_points = simplify_polygon(shape_points, 16)
	polygon_shape.points = simplified_points
	
	collision_shape.shape = polygon_shape
	add_child(collision_shape)

# 简化多边形点数（保持凸性）
func simplify_polygon(points: PackedVector2Array, max_points: int) -> PackedVector2Array:
	if points.size() <= max_points:
		return points
	
	var simplified: PackedVector2Array = []
	var step = float(points.size()) / max_points
	
	for i in range(max_points):
		var index = int(i * step)
		if index < points.size():
			simplified.append(points[index])
	
	return simplified

func setup_detection() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 设置检测层
	collision_layer = 0  # 区域本身不参与物理碰撞
	collision_mask = 2   # 检测层2的玩家

func _on_body_entered(body: Node2D) -> void:
	if body is Player and body not in players_inside:
		players_inside.append(body)
		player_entered.emit(body)
		print("Player %s entered %s area" % [body.name, get_area_type_name()])

func _on_body_exited(body: Node2D) -> void:
	if body is Player and body in players_inside:
		players_inside.erase(body)
		player_exited.emit(body)
		print("Player %s exited %s area" % [body.name, get_area_type_name()])

func contains_point(point: Vector2) -> bool:
	var local_point = to_local(point)
	return Geometry2D.is_point_in_polygon(local_point, shape_points)

func get_area_type_name() -> String:
	match area_type:
		AreaType.POWERUP_ZONE:
			return "POWER UP"
		AreaType.PENALTY_ZONE:
			return "PENALTY"
		AreaType.SPEED_BOOST:
			return "SPEED"
		AreaType.HEALING_ZONE:
			return "HEAL"
		AreaType.DANGER_ZONE:
			return "DANGER"
		_:
			return "UNKNOWN"

func get_players_inside() -> Array[Player]:
	return players_inside

func toggle_area_visibility(show_area: bool) -> void:
	modulate.a = 0.5 if show_area else 0.0

# 添加视觉效果
func _ready() -> void:
	# 创建闪烁效果
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate:a", 0.6, 1.0)
	tween.tween_property(self, "modulate:a", 0.3, 1.0)
	
	# 添加旋转动画（仅对某些形状）
	if area_type == AreaType.POWERUP_ZONE or area_type == AreaType.DANGER_ZONE:
		var rotation_tween = create_tween()
		rotation_tween.set_loops()
		rotation_tween.tween_property(self, "rotation", 2 * PI, 5.0)

# 更新区域的视觉样式
func update_visual_style() -> void:
	if visual_polygon:
		match area_type:
			AreaType.POWERUP_ZONE:
				visual_polygon.color = Color.BLUE
				border_line.default_color = Color.CYAN
			AreaType.PENALTY_ZONE:
				visual_polygon.color = Color.RED
				border_line.default_color = Color.DARK_RED
			AreaType.SPEED_BOOST:
				visual_polygon.color = Color.GREEN
				border_line.default_color = Color.LIME_GREEN
			AreaType.HEALING_ZONE:
				visual_polygon.color = Color.YELLOW
				border_line.default_color = Color.ORANGE
			AreaType.DANGER_ZONE:
				visual_polygon.color = Color.PURPLE
				border_line.default_color = Color.MAGENTA

# 获取区域中心位置
func get_center_position() -> Vector2:
	return global_position

# 检查区域是否与其他区域重叠
func overlaps_with_area(other_area: RandomArea) -> bool:
	# 简化的重叠检测：检查多边形的边界框
	var my_bounds = get_polygon_bounds(shape_points, global_position)
	var other_bounds = get_polygon_bounds(other_area.shape_points, other_area.global_position)
	
	return my_bounds.intersects(other_bounds)

# 获取多边形的边界框
func get_polygon_bounds(points: PackedVector2Array, offset: Vector2) -> Rect2:
	if points.is_empty():
		return Rect2(offset, Vector2.ZERO)
	
	var min_x = points[0].x + offset.x
	var max_x = min_x
	var min_y = points[0].y + offset.y
	var max_y = min_y
	
	for point in points:
		var world_point = point + offset
		min_x = min(min_x, world_point.x)
		max_x = max(max_x, world_point.x)
		min_y = min(min_y, world_point.y)
		max_y = max(max_y, world_point.y)
	
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

# 获取形状的实际尺寸（用于调试）
func get_actual_shape_size() -> Vector2:
	if shape_points.is_empty():
		return Vector2.ZERO
	
	var bounds = get_polygon_bounds(shape_points, Vector2.ZERO)
	return bounds.size
