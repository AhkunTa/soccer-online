class_name Ball
extends AnimatableBody2D
enum State {
	CARRIED,
	FREEFORM,
	SHOT,
	POWER_SHOT_NORMAL,
	POWER_SHOT_HEIGHT_LIGHT,
	POWER_SHOT_RISING,
	POWER_SHOT_STRONG,
	POWER_SHOT_CURVE,
	POWER_SHOT_INVISIBLE,
	POWER_SHOT_JUMP,
	# TODO 可以在这里添加更多绝招状态...,
}


enum PowerShotType {
	NULL,
	NORMAL, # 普通绝招射门
	HEIGHT_LIGHT, # 高亮射门 闪烁发光 通常用于 头球和凌空抽射
	RISING, # 上升射门：球缓慢上升然后直射球门
	STRONG, # 强力射门：球速度更快，球扁平状
	CURVE, # 弧线射门：球以弧线轨迹飞向球门
	INVISIBLE, # 隐形射门：球在飞行过程中变得隐形
	JUMP # 跳跃射门：球在飞行过程中会有跳跃效果
}

const DISTANCE_HIGH_PASS := 100
const TUMBLE_HEIGHT_VELOCITY := 3.0

const DURATION_TUMBLE_LOCK := 200
const DURATION_PASS_LOCK := 500

const KICKOFF_PASS_DISTANCE := 50.0
# 绝招最短释放距离
const MIN_POWER_SHOT_DISTANCE := 100.0

# 一般角色 power >150 也就是 需要完全蓄力 或者二段跳 才能触发绝招射门
const POWER_SHOT_STRENGTH := 300.0
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
@onready var shot_particles: GPUParticles2D = %shot_particles
@onready var player_proximity_area: Area2D = %PlayerProximityArea
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
	current_state.setup(self , data, player_detection_area, carrier, animation_player, ball_sprite, shot_particles)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "BallStateMachine"
	call_deferred('add_child', current_state)
	
func shoot(shot_velocity: Vector2, initial_height: float = -1.0, power: float = 150, power_shot_type: PowerShotType = PowerShotType.NULL) -> void:
	velocity = shot_velocity
	var player_power_shot_type := power_shot_type if power_shot_type != PowerShotType.NULL else carrier.power_shot_type
	print("力量 %s 使用 %s" % [power, player_power_shot_type])
	# FIXME 添加 player 添加 
	if carrier != null:
		carrier.is_invincible_to_ball_damage = true
	if power >= POWER_SHOT_STRENGTH and carrier.is_facing_target_goal() and position.distance_to(carrier.target_goal.position) >= MIN_POWER_SHOT_DISTANCE:
		# 根据绝招类型选择不同的状态
		match player_power_shot_type:
			PowerShotType.STRONG:
				switch_state(Ball.State.POWER_SHOT_STRONG, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
			PowerShotType.HEIGHT_LIGHT:
				switch_state(Ball.State.POWER_SHOT_HEIGHT_LIGHT, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
			PowerShotType.RISING:
				switch_state(Ball.State.POWER_SHOT_RISING, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
			PowerShotType.CURVE:
				switch_state(Ball.State.POWER_SHOT_CURVE, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
			PowerShotType.NORMAL:
				switch_state(Ball.State.SHOT, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
			PowerShotType.INVISIBLE:
				switch_state(Ball.State.POWER_SHOT_INVISIBLE, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
			PowerShotType.JUMP:
				switch_state(Ball.State.POWER_SHOT_JUMP, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
			_:
				switch_state(Ball.State.SHOT, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
	else:
		switch_state(Ball.State.SHOT, BallStateData.build().set_shot_normal_data(initial_height, power, PowerShotType.NORMAL))

	carrier = null

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

func get_proximity_teammates_count(country: String) -> int:
	var players := player_proximity_area.get_overlapping_areas()
	return players.filter(func(p: Player): return p.country == country).size()

func on_team_reset() -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	height = 0
	switch_state(State.FREEFORM)
	
func on_kickoff_started() -> void:
	pass_to(spawn_position + Vector2.DOWN * KICKOFF_PASS_DISTANCE, 0)
