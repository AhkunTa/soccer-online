class_name Player
extends CharacterBody2D

const CONTROL_SCHENE_MAP: Dictionary = {
	ControlScheme.CPU: preload("res://assets/art/props/cpu.png"),
	ControlScheme.P1: preload("res://assets/art/props/1p.png"),
	ControlScheme.P2: preload("res://assets/art/props/2p.png")
}
const BALL_CONTROL_HEIGHT_MAX := 10.0

const GRAVITY := 8.0

@export var speed: float = 80.0
@export var power: float = 150.0
@export var JUMP_VELOCITY: float = -400.0
@export var strength: int = 5
@export var JUMP_IMPULES = 20
@export var control_scheme: ControlScheme
@export var ball: Ball
@export var player_config: PlayerConfig # 玩家配置
@export var own_goal: Goal
@export var target_goal: Goal

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var player_sprite: Sprite2D = %PlayerSprite
@onready var team_detection_area: Area2D = %TeammateDetectionArea
@onready var control_sprite: Sprite2D = %ControlSprite
@onready var ball_detection_area: Area2D = %BallDetectionArea

enum ControlScheme {CPU, P1, P2}
enum State {MOVING, TACKLING, JUMPING, RECOVERING, PREPINGSHOT, SHOOTING, JUMPINGSHOTING, PASSING, HEADER, VOLLEY_KICK, BICYCLE_KICK, CHEST_CONTROL}


enum Role {GOALIE, DEFENDER, MIDFIELDER, FORWARD}
enum SkinColor {LIGHT, MEDIUM, DARK}

# 基础属性
var fullname := ""
var role :=Player.Role.MIDFIELDER
var skin_color := Player.SkinColor.MEDIUM

var heading := Vector2.RIGHT
var height := 0.0
var height_velocity := 0.0

var current_state: PlayerState = null
var state_factory := PlayerStateFactory.new()

# 临时效果系统
var active_boosts: Dictionary = {}
var healing_active: bool = false
var healing_rate: float = 0.0

func _ready() -> void:
	# 如果没有配置，使用默认配置
	if player_config == null:
		player_config = PlayerConfig.create_default_config()
	
	# 应用配置到玩家属性
	apply_player_config()
	
	
	set_control_texture()
	switch_state(State.MOVING, PlayerStateData.new())

# 应用玩家配置到属性
func apply_player_config() -> void:
	if player_config != null:
		speed = player_config.speed
		power = player_config.power
		JUMP_VELOCITY = player_config.jump_velocity
		strength = player_config.strength
		JUMP_IMPULES = player_config.jump_impulse

# 设置玩家配置
func set_player_config(config: PlayerConfig) -> void:
	player_config = config
	apply_player_config()

# 获取玩家配置
func get_player_config() -> PlayerConfig:
	return player_config

func _process(delta: float) -> void:
	flip_sprites()
	set_sprite_visiable()
	process_gravity(delta)
	# update_temporary_effects(delta)
	move_and_slide()
	#zIndex_set()

func initialize(context_position: Vector2, context_ball: Ball, context_own_goal: Goal, context_target_goal: Goal, context_player_data: PlayerResource) -> void:
	position = context_position
	ball = context_ball
	own_goal = context_own_goal
	target_goal = context_target_goal
	speed = context_player_data.speed
	power = context_player_data.power
	role = context_player_data.role
	skin_color = context_player_data.skin_color
	fullname = context_player_data.full_name
	heading = Vector2.LEFT if target_goal.position.x < position.x else Vector2.RIGHT

func switch_state(state: State, state_data: PlayerStateData) -> void:
	if current_state != null:
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self, state_data, animation_player, ball, team_detection_area, ball_detection_area, own_goal, target_goal)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "PlayerStateMachine: " + str(state)
	call_deferred("add_child", current_state)

func set_tackling_animation() -> void:
	animation_player.play("tackle")

func set_movement_animation() -> void:
	if velocity.length() > 0:
		animation_player.play("run")
	else:
		animation_player.play("idle")


func process_gravity(delta) -> void:
	if height > 0:
		height_velocity -= GRAVITY * delta
		height += height_velocity
		if height < 0:
			height = 0
	player_sprite.position = Vector2.UP * height


func set_heading() -> void:
	if velocity.x > 0:
		heading = Vector2.RIGHT
	elif velocity.x < 0:
		heading = Vector2.LEFT

func flip_sprites() -> void:
	if heading == Vector2.RIGHT:
		player_sprite.flip_h = false
	elif heading == Vector2.LEFT:
		player_sprite.flip_h = true
	#player_sprite.flip_h == true if heading == Vector2.LEFT else false

func set_sprite_visiable() -> void:
	control_sprite.visible = has_ball() or not control_scheme == ControlScheme.CPU

func has_ball() -> bool:
	return ball.carrier == self

func set_control_texture() -> void:
	control_sprite.texture = CONTROL_SCHENE_MAP[control_scheme]

func on_animation_complete() -> void:
	if current_state != null:
		current_state.on_animation_complete()
	pass

func get_player_info() -> String:
	if player_config != null:
		return "Player: %s | Speed: %.1f | Power: %.1f | Strength: %d | Team: %d" % [
			player_config.player_name,
			speed,
			power,
			strength,
		]
	else:
		return "Player: Unknown | Speed: %.1f | Power: %.1f | Strength: %d" % [speed, power, strength]

# 重置玩家为默认配置
func reset_to_default() -> void:
	set_player_config(PlayerConfig.create_default_config())

# 应用临时增益效果
func apply_temporary_boost(stat_name: String, multiplier: float, duration: float) -> void:
	# 移除现有的同类型增益
	if stat_name in active_boosts:
		remove_boost(stat_name)
	
	# 应用新增益
	var original_value = get(stat_name)
	var boosted_value = original_value * multiplier
	set(stat_name, boosted_value)
	
	# 保存增益信息
	active_boosts[stat_name] = {
		"original_value": original_value,
		"multiplier": multiplier,
		"timer": duration
	}
	
	print("Applied %s boost: %.1fx for %.1fs" % [stat_name, multiplier, duration])

# 移除增益效果
func remove_boost(stat_name: String) -> void:
	if stat_name in active_boosts:
		var boost_data = active_boosts[stat_name]
		set(stat_name, boost_data["original_value"])
		active_boosts.erase(stat_name)
		print("Removed %s boost" % stat_name)

# 开始治疗
func start_healing(rate: float) -> void:
	healing_active = true
	healing_rate = rate
	print("Started healing at %.1f per second" % rate)

# 停止治疗
func stop_healing() -> void:
	healing_active = false
	healing_rate = 0.0
	print("Stopped healing")

# 应用伤害
func apply_damage(amount: float) -> void:
	# 这里可以实现伤害系统
	print("Player took %.1f damage" % amount)

# 更新临时效果
func update_temporary_effects(delta: float) -> void:
	# 更新临时增益效果
	var boosts_to_remove: Array[String] = []
	for stat_name in active_boosts:
		active_boosts[stat_name]["timer"] -= delta
		if active_boosts[stat_name]["timer"] <= 0:
			boosts_to_remove.append(stat_name)
	
	# 移除过期的增益
	for stat_name in boosts_to_remove:
		remove_boost(stat_name)
	
	# 处理治疗效果
	if healing_active:
		# 这里可以实现实际的治疗逻辑
		pass

# 检查是否与其他玩家在同一队伍
func is_teammate(other_player: Player) -> bool:
	if player_config != null and other_player.player_config != null:
		return player_config.team_id == other_player.player_config.team_id
	return false

func control_ball() -> void:
	if ball.height >= BALL_CONTROL_HEIGHT_MAX:
		switch_state(Player.State.CHEST_CONTROL, PlayerStateData.new())

#func zIndex_set() ->void:
	#z_index = int(position.y)
