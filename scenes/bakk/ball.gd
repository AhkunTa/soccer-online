class_name  Ball
extends AnimatableBody2D
enum State {CARRIED, FREEFORM, SHOT}

var state_factory :=BallStateFactory.new()
var velocity:= Vector2.ZERO
var current_state :BallState = null
var carrier :Player = null
var height := 0.0
var height_velocity = 0.0

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var player_detection_area :Area2D = $PlayerDetection
@onready var ball_sprite :Sprite2D = %BallSprite

func _ready() -> void:
	switch_state(State.FREEFORM)

func _process(delta: float) -> void:
	ball_sprite.position = Vector2.UP * height

func switch_state(state: Ball.State) -> void:
	if current_state != null:
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self, player_detection_area,carrier, animation_player,ball_sprite)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "BallStateMachine"
	call_deferred('add_child', current_state)
	
func shoot(shot_velocity: Vector2) -> void:
	velocity = shot_velocity
	print(shot_velocity)
	carrier = null
	switch_state(Ball.State.SHOT)
	
