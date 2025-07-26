class_name Ball
extends AnimatableBody2D
enum State {CARRIED, FREEFORM, SHOT}

const DISTANCE_HIGH_PASS := 150


var state_factory := BallStateFactory.new()
var velocity := Vector2.ZERO
var current_state: BallState = null
var carrier: Player = null
var height := 0.0
var height_velocity = 0.0

#摩擦力 空中
@export var friction_air := 25.0
#摩擦力 地面
@export var friction_ground := 250.0
#TODO 不同地面 

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var player_detection_area: Area2D = $PlayerDetection
@onready var ball_sprite: Sprite2D = %BallSprite

func _ready() -> void:
	switch_state(State.FREEFORM)

func _process(delta: float) -> void:
	ball_sprite.position = Vector2.UP * height

func switch_state(state: Ball.State) -> void:
	if current_state != null:
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self, player_detection_area, carrier, animation_player, ball_sprite)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "BallStateMachine"
	call_deferred('add_child', current_state)
	
func shoot(shot_velocity: Vector2) -> void:
	velocity = shot_velocity
	print(shot_velocity)
	carrier = null
	switch_state(Ball.State.SHOT)

func pass_to(destination: Vector2) -> void:
	var direction := position.direction_to(destination)
	var distance := position.distance_to(destination)
	#	TODO 微积分方程  https://youtu.be/-4pGf5bW4-M?t=457
	var intensity := sqrt(2 * distance * friction_ground)
	#	TODO 高度加速度方程 https://youtu.be/FHnebIUSXHk?t=345
	if distance > DISTANCE_HIGH_PASS:
		height_velocity = BallState.GRAVITY * distance / (2 * intensity)
	velocity = intensity * direction
	carrier = null
	switch_state(Ball.State.FREEFORM)

func stop() -> void:
	velocity = Vector2.ZERO

func can_air_interact() -> bool:
	return current_state != null and current_state.can_air_interact()

func is_freeform() -> bool:
	return current_state != null and current_state is BallStateFreeForm
