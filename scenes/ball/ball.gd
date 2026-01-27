class_name Ball
extends AnimatableBody2D
enum State {CARRIED, FREEFORM, SHOT}

const DISTANCE_HIGH_PASS := 100
const TUMBLE_HEIGHT_VELOCITY := 3.0

const DURATION_TUMBLE_LOCK := 200
const DURATION_PASS_LOCK := 500

const KICKOFF_PASS_DISTANCE := 50.0

var state_factory := BallStateFactory.new()
var velocity := Vector2.ZERO
var current_state: BallState = null
var carrier: Player = null
var height := 0.0
var height_velocity := 0.0
var spawn_position := Vector2.ZERO

#摩擦力 空中
@export var friction_air := 25.0
#摩擦力 地面
@export var friction_ground := 250.0
#TODO 不同地面 

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var player_detection_area: Area2D = $PlayerDetection
@onready var ball_sprite: Sprite2D = %BallSprite
@onready var scoring_ratcast: RayCast2D = %ScoringRayCast
@onready var shot_particles : GPUParticles2D = %shot_particles

func _ready() -> void:
	switch_state(State.FREEFORM)
	spawn_position = position
	GameEvents.team_reset.connect(on_team_reset.bind())
	GameEvents.kickoff_started.connect(on_kickoff_started.bind())

func _process(_delta: float) -> void:
	ball_sprite.position = Vector2.UP * height
	scoring_ratcast.rotation = velocity.angle()

func switch_state(state: Ball.State, data: BallStateData = BallStateData.new()) -> void:
	if current_state != null:
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self, data, player_detection_area, carrier, animation_player, ball_sprite, shot_particles)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "BallStateMachine"
	call_deferred('add_child', current_state)
	
func shoot(shot_velocity: Vector2) -> void:
	velocity = shot_velocity
	carrier = null
	switch_state(Ball.State.SHOT)

func tumble(shot_velocity: Vector2) -> void:
	velocity = shot_velocity
	height_velocity = TUMBLE_HEIGHT_VELOCITY
	carrier = null
	switch_state(Ball.State.FREEFORM, BallStateData.build().set_lock_duration(DURATION_TUMBLE_LOCK))

func pass_to(destination: Vector2, lock_duration: int = DURATION_PASS_LOCK) -> void:
	var direction := position.direction_to(destination)
	var distance := position.distance_to(destination)
	#	TODO 微积分方程  https://youtu.be/-4pGf5bW4-M?t=457
	var intensity := sqrt(2 * distance * friction_ground)
	#	TODO 高度加速度方程 https://youtu.be/FHnebIUSXHk?t=345
	velocity = intensity * direction
	if distance > DISTANCE_HIGH_PASS:
		height_velocity = BallState.GRAVITY * distance / (1.8 * intensity)
	carrier = null
	switch_state(Ball.State.FREEFORM, BallStateData.build().set_lock_duration(lock_duration))

func stop() -> void:
	velocity = Vector2.ZERO

func can_air_interact() -> bool:
	return current_state != null and current_state.can_air_interact()

func can_air_connect(air_connect_min_height: float, air_connect_max_height: float) -> bool:
	return height >= air_connect_min_height and height <= air_connect_max_height

func is_freeform() -> bool:
	return current_state != null and current_state is BallStateFreeForm

func is_header_for_scoring_area(scoring_area: Area2D) -> bool:
	if not scoring_ratcast.is_colliding():
		return false
	return scoring_ratcast.get_collider() == scoring_area

func on_team_reset() -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	height = 0
	switch_state(State.FREEFORM)
	
func on_kickoff_started() -> void:
	pass_to(spawn_position + Vector2.DOWN * KICKOFF_PASS_DISTANCE, 0)
