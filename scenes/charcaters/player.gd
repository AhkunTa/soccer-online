class_name Player
extends CharacterBody2D

const CONTROL_SCHENE_MAP: Dictionary = {
	ControlScheme.CPU: preload("res://assets/art/props/cpu.png"),
	ControlScheme.P1: preload("res://assets/art/props/1p.png"),
	ControlScheme.P2: preload("res://assets/art/props/2p.png")
}

const GRAVITY := 8.0

@export var speed: float = 80.0
@export var power: float = 150.0
@export var JUMP_VELOCITY: float = -400.0
@export var strength: int = 5
@export var JUMP_IMPULES = 20
@export var control_scheme: ControlScheme
@export var ball: Ball
@export var player_config: PlayerConfig  # 玩家配置

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var player_sprite: Sprite2D = %PlayerSprite
@onready var team_detection_area: Area2D = %TeammateDetectionArea
@onready var control_sprite: Sprite2D = %ControlSprite
@onready var ball_detection_area: Area2D = %BallDetectionArea

enum ControlScheme {CPU, P1, P2}
enum State {MOVING, TACKLING, JUMPING, RECOVERING, PREPINGSHOT, SHOOTING, JUMPINGSHOTING, PASSING, HEADER, VOLLEY_KICK, BICYCLE_KICK}

var heading := Vector2.RIGHT
var height := 0.0
var height_velocity := 0.0

var current_state: PlayerState = null
var state_factory := PlayerStateFactory.new()

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
	move_and_slide()
	#zIndex_set()

func switch_state(state: State, state_data: PlayerStateData) -> void:
	if current_state != null:
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self, state_data, animation_player, ball, team_detection_area, ball_detection_area)
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

	
#func zIndex_set() ->void:
	#z_index = int(position.y)
