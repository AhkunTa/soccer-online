class_name Player
extends CharacterBody2D


@export var SPEED: float = 80.0
@export var JUMP_VELOCITY: float = -400.0
@export var STRENGTH: int = 5
@export var JUMP_IMPULES = 20
@onready var animation_player: AnimationPlayer =  %AnimationPlayer
@export var control_scheme: ControlScheme

enum ControlScheme {CPU,P1,P2}


func _physics_process(delta: float) -> void:
	
	var direction := KeyUtils.get_input_vector(control_scheme)
	velocity = direction * SPEED
	if is_on_floor() and Input.is_action_just_pressed("p1_jump"):
		prints('jump')
		#animation_player.y = JUMP_IMPULES
	if velocity.length() > 0:
		animation_player.play("run")
	else:
		animation_player.play("idle")
	move_and_slide()
