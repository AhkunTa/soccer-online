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

# 视觉组件
var visual_rect: ColorRect
var border_rect: NinePatchRect
var label: Label

# 信号
signal player_entered(player: Player)
signal player_exited(player: Player)

func setup(type: AreaType, pos: Vector2, size: Vector2) -> void:
	area_type = type
	area_size = size
	position = pos
	
	create_visual_components()
	create_collision_shape()
	setup_detection()

func create_visual_components() -> void:
	# 创建背景矩形
	visual_rect = ColorRect.new()
	visual_rect.size = area_size
	visual_rect.position = -area_size / 2
	visual_rect.color = Color.WHITE
	add_child(visual_rect)
	
	# 创建边框
	border_rect = NinePatchRect.new()
	border_rect.size = area_size + Vector2(4, 4)
	border_rect.position = -area_size / 2 - Vector2(2, 2)
	border_rect.modulate = Color.BLACK
	add_child(border_rect)
	
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
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = area_size
	collision_shape.shape = rect_shape
	add_child(collision_shape)

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
	var rect = Rect2(-area_size / 2, area_size)
	return rect.has_point(local_point)

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

# 获取区域中心位置
func get_center_position() -> Vector2:
	return global_position

# 检查区域是否与其他区域重叠
func overlaps_with_area(other_area: RandomArea) -> bool:
	var my_rect = Rect2(global_position - area_size / 2, area_size)
	var other_rect = Rect2(other_area.global_position - other_area.area_size / 2, other_area.area_size)
	return my_rect.intersects(other_rect)
