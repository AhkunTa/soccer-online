class_name Player
extends CharacterBody2D


@export var SPEED: float = 80.0
@export var JUMP_VELOCITY: float = -400.0
@export var STRENGTH: int = 5
@export var JUMP_IMPULES = 20
@export var control_scheme: ControlScheme



@onready var animation_player: AnimationPlayer =  %AnimationPlayer
@onready var player_sprite: Sprite2D = %PlayerSprite


const DURATION_TACKLE :=200
enum ControlScheme {CPU,P1,P2}
enum State {MOVING, TACKLING, JUMPING,SHOOTING}

var heading:= Vector2.RIGHT
var state:=State.MOVING
var time_start_tackle := Time.get_ticks_msec()

func _physics_process(delta: float) -> void:
	if control_scheme == ControlScheme.CPU:
		pass
	else:
		if state == State.MOVING:
			set_movement_animation()
			handle_human_movement()
			if velocity.x != 0 and KeyUtils.is_action_just_pressed(control_scheme,KeyUtils.Action.SHOOT):
				state = State.TACKLING
				time_start_tackle = Time.get_ticks_msec()
		elif state == State.TACKLING:
			set_tackling_animation()
			if Time.get_ticks_msec() - time_start_tackle >= DURATION_TACKLE && state == State.TACKLING:
				state = State.MOVING
		elif state == State.SHOOTING:
			pass
		elif state == State.JUMPING:
			pass
	if is_on_floor() and Input.is_action_just_pressed("p1_jump"):
		prints('jump')
		#animation_player.y = JUMP_IMPULES		
	set_heading()
	flip_sprites()
	move_and_slide()

func handle_human_movement() -> void:
	var direction := KeyUtils.get_input_vector(control_scheme)
	velocity = direction * SPEED

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
