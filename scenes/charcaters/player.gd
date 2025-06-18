class_name Player
extends CharacterBody2D


@export var SPEED: float = 80.0
@export var JUMP_VELOCITY: float = -400.0
@export var STRENGTH: int = 5
@export var JUMP_IMPULES = 20
@export var control_scheme: ControlScheme

@onready var animation_player: AnimationPlayer =  %AnimationPlayer
@onready var player_sprite: Sprite2D = %PlayerSprite

enum ControlScheme {CPU,P1,P2}
enum State {MOVING, TACKLING, JUMPING,SHOOTING, RECOVERING}

var heading:= Vector2.RIGHT

var current_state: PlayerState = null
var state_factory := PlayerStateFactory.new()
func _ready() -> void:
	switch_state(State.MOVING)

func _process(_delta: float) -> void:

	flip_sprites()
	move_and_slide()
	#zIndex_set()

func switch_state(state: State) -> void:
	if current_state != null:
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self, animation_player)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "PlayerStateMachine: " + str(state)
	call_deferred("add_child", current_state)

func set_tackling_animation() ->void:
	animation_player.play("tackle")

func set_movement_animation() ->void:
	if velocity.length() > 0:
		animation_player.play("run")
	else:
		animation_player.play("idle")
		
func set_heading() -> void:
	if velocity.x >0:
		heading = Vector2.RIGHT
	elif velocity.x <0:
		heading = Vector2.LEFT

func flip_sprites() -> void:
	if heading == Vector2.RIGHT:
		player_sprite.flip_h = false
	elif heading == Vector2.LEFT:
		player_sprite.flip_h = true
	#player_sprite.flip_h == true if heading == Vector2.LEFT else false

func zIndex_set() ->void:
	z_index = int(position.y)
