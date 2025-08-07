class_name WorldManager
extends Node2D

# 图层管理
@onready var background_layer: Node2D = $Backgrounds
@onready var actors_layer: Node2D = $ActorsContainer
@onready var effects_layer: Node2D = $EffectsContainer
@onready var ui_layer: CanvasLayer = $UILayer

# 区域生成器
var area_generator: Node2D

func _ready() -> void:
	# TODO 地图管理器
	#setup_layers()
	#setup_area_generator()
	pass

func setup_layers() -> void:
	# 创建效果图层（如果不存在）
	if not has_node("EffectsContainer"):
		effects_layer = Node2D.new()
		effects_layer.name = "EffectsContainer"
		effects_layer.y_sort_enabled = true
		add_child(effects_layer)
	
	# 创建UI图层（如果不存在）
	if not has_node("UILayer"):
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		ui_layer.layer = 10  # 确保UI在最上层
		add_child(ui_layer)
	
	# 设置图层顺序（z_index）
	if background_layer:
		background_layer.z_index = -10
	if actors_layer:
		actors_layer.z_index = 0
	if effects_layer:
		effects_layer.z_index = 5

func setup_area_generator() -> void:
	# 加载区域生成器脚本
	var area_script = preload("res://scenes/world/area/area_generator.gd")
	area_generator = Node2D.new()
	area_generator.set_script(area_script)
	area_generator.name = "AreaGenerator"
	
	# 连接信号（使用字符串连接以避免类型检查）
	area_generator.connect("player_entered_area", _on_player_entered_area)
	area_generator.connect("player_exited_area", _on_player_exited_area)
	area_generator.connect("area_generated", _on_area_generated)
	area_generator.connect("area_removed", _on_area_removed)
	
	# 添加到效果图层
	effects_layer.add_child(area_generator)

func _on_player_entered_area(player: Node2D, _area: Node2D) -> void:
	print("Player %s entered area" % [player.name])
	# 这里可以添加进入区域的视觉/音效效果

func _on_player_exited_area(player: Node2D, _area: Node2D) -> void:
	print("Player %s exited area" % [player.name])
	# 这里可以添加离开区域的视觉/音效效果

func _on_area_generated(area: Node2D) -> void:
	print("New area generated at %s" % [area.position])

func _on_area_removed(_area: Node2D) -> void:
	print("Area removed")

# 手动触发新区域生成
func generate_new_areas() -> void:
	if area_generator and area_generator.has_method("generate_initial_areas"):
		area_generator.call("generate_initial_areas")

# 清除所有区域
func clear_all_areas() -> void:
	if area_generator and area_generator.has_method("clear_all_areas"):
		area_generator.call("clear_all_areas")

# 获取当前活跃区域数量
func get_active_area_count() -> int:
	if area_generator and area_generator.has_method("get_active_area_count"):
		return area_generator.call("get_active_area_count")
	return 0

# 获取指定图层
func get_background_layer() -> Node2D:
	return background_layer

func get_actors_layer() -> Node2D:
	return actors_layer

func get_effects_layer() -> Node2D:
	return effects_layer

func get_ui_layer() -> CanvasLayer:
	return ui_layer

# 在指定图层添加节点
func add_to_background(node: Node2D) -> void:
	background_layer.add_child(node)

func add_to_actors(node: Node2D) -> void:
	actors_layer.add_child(node)

func add_to_effects(node: Node2D) -> void:
	effects_layer.add_child(node)

func add_to_ui(node: Control) -> void:
	ui_layer.add_child(node)

# 切换区域可见性
func toggle_areas_visibility(show_areas: bool) -> void:
	if area_generator and area_generator.has_method("toggle_area_visibility"):
		area_generator.call("toggle_area_visibility", show_areas)

# 调试功能：显示图层信息
func print_layer_info() -> void:
	print("=== 图层信息 ===")
	print("背景图层子节点数量: ", background_layer.get_child_count() if background_layer else 0)
	print("角色图层子节点数量: ", actors_layer.get_child_count() if actors_layer else 0)
	print("效果图层子节点数量: ", effects_layer.get_child_count() if effects_layer else 0)
	print("UI图层子节点数量: ", ui_layer.get_child_count() if ui_layer else 0)
	print("活跃区域数量: ", get_active_area_count())
	print("================")

# 输入处理（用于调试）
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Space 键
		generate_new_areas()
	elif event.is_action_pressed("ui_cancel"):  # ESC 键
		clear_all_areas()
	elif event.is_action_pressed("ui_select"):  # Enter 键
		print_layer_info()
