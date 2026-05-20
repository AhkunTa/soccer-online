class_name WorldScreen
extends Screen

# 图层管理
@onready var background_layer: Node2D = $Backgrounds
@onready var actors_layer: ActorsContainer = $ActorsContainer
@onready var effects_layer: Node2D = $EffectsContainer
@onready var ui_layer: CanvasLayer = %UI
@onready var grass: Sprite2D = $Backgrounds/Grass
@onready var pattern: Sprite2D = $Backgrounds/Pattern
@onready var lines: Sprite2D = $Backgrounds/Lines
@onready var environment_map: EnvironmentMap = %Environment
@onready var game_camera: Camera2D = $Camera
@onready var rain_effect: RainParticles = $EffectsContainer/Rain

# Timer
@onready var game_over_timer: Timer = %GameOverTimer

@export var field_condition: FieldCondition

var weather_system: WeatherSystem
var weather_hazard_system: WeatherHazardSystem
var field_patch_map: FieldPatchMap

func _ready() -> void:
	setup_layers()
	_apply_field_condition()
	game_over_timer.timeout.connect(on_transition.bind())
	GameEvents.game_over.connect(on_game_over.bind())
	if GameManager.is_online():
		# 联机模式：等待 SyncManager 所有客户端加载完成后再开始
		SyncManager.match_started.connect(_on_online_match_started, CONNECT_ONE_SHOT)
		# 通知服务器本地场景已加载完毕
		SyncManager.notify_scene_loaded()
	else:
		GameManager.start_game()


func _on_online_match_started() -> void:
	GameManager.start_game()

func on_game_over(_winning: String) -> void:
	game_over_timer.start()

func on_transition() -> void:
	if GameManager.is_online():
		SyncManager.reset_state()
		GameManager.game_mode = GameManager.GameMode.LOCAL
		transition_screen(SoccerGame.ScreenType.ONLINE_LOBBY)
		return
	if screen_data.tournament != null and GameManager.current_match.winner == GameManager.player_setup[0]:
		screen_data.tournament.advance()
		transition_screen(SoccerGame.ScreenType.TOURNAMENT, screen_data)
	else:
		transition_screen(SoccerGame.ScreenType.MAIN_MENU)


func setup_layers() -> void:
	# 创建效果图层（如果不存在）
	if not has_node("EffectsContainer"):
		effects_layer = Node2D.new()
		effects_layer.name = "EffectsContainer"
		effects_layer.y_sort_enabled = true
		add_child(effects_layer)
	
	# 创建UI图层（如果不存在）
	if ui_layer == null:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		ui_layer.layer = 10 # 确保UI在最上层
		add_child(ui_layer)
	
	# 设置图层顺序（z_index）
	if background_layer:
		background_layer.z_index = -10
	if actors_layer:
		actors_layer.z_index = 0
	if effects_layer:
		effects_layer.z_index = 1

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

func _apply_field_condition() -> void:
	if field_condition == null:
		field_condition = GameManager.field_condition
	if field_condition == null:
		field_condition = FieldCondition.grass()
	_print_field_condition_debug(field_condition)
	_apply_field_visuals(field_condition)
	_create_field_patch_map(field_condition)
	_apply_particle_rain(field_condition)
	actors_layer.apply_field_condition(field_condition, field_patch_map)
	weather_system = WeatherSystem.new()
	weather_system.name = "WeatherSystem"
	weather_system.z_index = -1
	weather_system.show_weather_particles = not _uses_particle_rain(field_condition)
	effects_layer.add_child(weather_system)
	weather_system.setup(field_condition)
	weather_hazard_system = WeatherHazardSystem.new()
	weather_hazard_system.name = "WeatherHazardSystem"
	weather_hazard_system.z_index = 20
	effects_layer.add_child(weather_hazard_system)
	weather_hazard_system.setup(field_condition, game_camera, actors_layer)

func _print_field_condition_debug(condition: FieldCondition) -> void:
	var surface_name = FieldCondition.Surface.keys()[condition.surface]
	var weather_name = FieldCondition.Weather.keys()[condition.weather]
	var wind_direction_name = FieldCondition.WindDirection.keys()[condition.wind_direction]
	var patch_set_name = FieldCondition.PatchSet.keys()[condition.get_patch_set()]
	print("[FieldCondition] Surface=%s Weather=%s PatchSet=%s" % [surface_name, weather_name, patch_set_name])
	print("[FieldCondition] 玩家: player_speed=%.2f acceleration=%.2f stopping_friction=%.2f slip=%.2f" % [
		condition.player_speed_multiplier,
		condition.acceleration_multiplier,
		condition.stopping_friction_multiplier,
		condition.slip_chance_per_second,
	])
	print("[FieldCondition] 足球: ball_ground_friction=%.2f ball_air_friction=%.2f" % [
		condition.ball_ground_friction_multiplier,
		condition.ball_air_friction_multiplier,
	])
	print("[FieldCondition] 风: direction=%s vector=%s player_force=%.2f ball_force=%.2f" % [
		wind_direction_name,
		str(condition.get_wind_vector()),
		condition.get_wind_player_force(),
		condition.get_wind_ball_force(),
	])
	print("[FieldCondition] 最终效果: player_speed=%.2f acceleration=%.2f stopping_friction=%.2f slip=%.2f ball_ground_friction=%.2f ball_air_friction=%.2f" % [
		condition.get_player_speed_multiplier(),
		condition.get_acceleration_multiplier(),
		condition.get_stopping_friction_multiplier(),
		condition.get_slip_chance_per_second(),
		condition.get_ball_ground_friction_multiplier(),
		condition.get_ball_air_friction_multiplier(),
	])
	var patch_modifier = FieldCondition.get_patch_modifiers(condition.get_patch_set())
	print("[FieldCondition] 特殊地块倍率: player_speed=%.2f acceleration=%.2f stopping_friction=%.2f slip=%.2f ball_ground_friction=%.2f" % [
		patch_modifier["player_speed"],
		patch_modifier["acceleration"],
		patch_modifier["stopping_friction"],
		patch_modifier["slip"],
		patch_modifier["ball_ground_friction"],
	])

func _apply_field_visuals(condition: FieldCondition) -> void:
	grass.modulate = condition.grass_color
	pattern.modulate = condition.pattern_color
	lines.modulate = condition.line_color

func _apply_particle_rain(condition: FieldCondition) -> void:
	var enabled := _uses_particle_rain(condition)
	rain_effect.visible = enabled
	rain_effect.set_emitting(enabled)
	if not enabled:
		return

	if condition.weather == FieldCondition.Weather.THUNDER:
		rain_effect.rain_size = RainParticles.RainSize.HEAVY
	else:
		rain_effect.rain_size = RainParticles.RainSize.MEDIUM

	var patch_set := condition.get_patch_set()
	if environment_map != null:
		rain_effect.set_puddle_rects(environment_map.get_patch_rects([FieldCondition.PatchSet.PUDDLE], patch_set))
	elif field_patch_map != null:
		rain_effect.set_puddle_rects(field_patch_map.get_patch_rects([FieldCondition.PatchSet.PUDDLE]))

	var wind := condition.get_wind_vector()
	if wind.x < -0.01:
		rain_effect.wind_direction = RainParticles.WindDirection.LEFT
	elif wind.x > 0.01:
		rain_effect.wind_direction = RainParticles.WindDirection.RIGHT
	else:
		rain_effect.wind_direction = RainParticles.WindDirection.NONE


func _uses_particle_rain(condition: FieldCondition) -> bool:
	return condition.weather == FieldCondition.Weather.RAIN or condition.weather == FieldCondition.Weather.THUNDER

func _create_field_patch_map(condition: FieldCondition) -> void:
	var seed_value := GameManager.field_seed
	if environment_map != null:
		environment_map.set_noise_seed(seed_value)
		environment_map.apply_patch_set_visuals(condition.get_patch_set())
	field_patch_map = FieldPatchMap.new()
	field_patch_map.name = "FieldPatchMap"
	field_patch_map.draw_visual_patches = environment_map == null or not environment_map.visible
	background_layer.add_child(field_patch_map)
	field_patch_map.generate(condition, seed_value, environment_map)

# 调试功能：显示图层信息
func print_layer_info() -> void:
	print("=== 图层信息 ===")
	print("背景图层子节点数量: ", background_layer.get_child_count() if background_layer else 0)
	print("角色图层子节点数量: ", actors_layer.get_child_count() if actors_layer else 0)
	print("效果图层子节点数量: ", effects_layer.get_child_count() if effects_layer else 0)
	print("UI图层子节点数量: ", ui_layer.get_child_count() if ui_layer else 0)
	print("================")

# 输入处理（用于调试）
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select"): # Enter 键
		print_layer_info()
