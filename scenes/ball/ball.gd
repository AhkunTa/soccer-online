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
	POWER_SHOT_FISH,
	POWER_SHOT_TAIJI,
	POWER_SHOT_GEMINI,
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
	JUMP, # 跳跃射门：球在飞行过程中会有跳跃效果
	# TODO
	# PENCIL, # 画笔射门：球在飞行过程中会留下彩色轨迹
	FISH, # 鱼跃射门：球在飞行过程中会有鱼跃效果
	# UNDERGROUND, # 地下射门：球会挖地前进
	TAIJI, # 太极射门：球在飞行过程中会有太极旋转效果
	GEMINI, # 双子射门：球会分裂成两个球飞向球门
}

const DISTANCE_HIGH_PASS := 100
const TUMBLE_HEIGHT_VELOCITY := 3.0

const DURATION_TUMBLE_LOCK := 200
const DURATION_PASS_LOCK := 500
const SHOOTER_DAMAGE_GRACE_MS := 500

const KICKOFF_PASS_DISTANCE := 50.0
# 绝招最短释放距离
const MIN_POWER_SHOT_DISTANCE := 100.0

# 一般角色 power >150 也就是 需要完全蓄力 或者二段跳 才能触发绝招射门
const POWER_SHOT_STRENGTH := 300.0
var state_factory := BallStateFactory.new()
var velocity := Vector2.ZERO
var current_state: BallState = null
var current_state_enum: int = -1
var carrier: Player = null
var last_shooter: Player = null
var last_shooter_damage_grace_until := 0
var height := 0.0
var height_velocity := 0.0
var spawn_position := Vector2.ZERO

#摩擦力 空中
@export var friction_air := 25.0
#摩擦力 地面
@export var friction_ground := 250.0
#TODO 不同地面 
var field_condition: FieldCondition = FieldCondition.grass()
var field_patch_map: FieldPatchMap = null
var base_friction_air := 25.0
var base_friction_ground := 250.0

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var player_detection_area: Area2D = $PlayerDetection
@onready var ball_sprite: Sprite2D = %BallSprite
@onready var scoring_ratcast: RayCast2D = %ScoringRayCast
@onready var shot_particles: GPUParticles2D = %shot_particles
@onready var player_proximity_area: Area2D = %PlayerProximityArea
func _ready() -> void:
	base_friction_air = friction_air
	base_friction_ground = friction_ground
	apply_field_condition(field_condition)
	player_detection_area.monitoring = true
	switch_state(State.FREEFORM)
	spawn_position = position
	GameEvents.team_reset.connect(on_team_reset.bind())
	GameEvents.kickoff_started.connect(on_kickoff_started.bind())

func _process(_delta: float) -> void:
	ball_sprite.position = Vector2.UP * height
	scoring_ratcast.rotation = velocity.angle()

func switch_state(state: Ball.State, data: BallStateData = BallStateData.new()) -> void:
	_do_switch_state(state, data)
	# 联机模式：服务端广播球状态切换给客户端
	# _do_switch_state 现在同步执行 on_enter_logic，velocity/height 已是正确初始值
	if SyncManager.is_server():
		SyncManager.server_sync_ball_state(state, data)


## 内部状态切换（客户端收到广播后也走这里）
func _do_switch_state(state: Ball.State, data: BallStateData = BallStateData.new()) -> void:
	# var role := "服务端" if SyncManager.is_server() else ("客户端" if SyncManager.is_client() else "本地")
	# print("[Ball][%s] 切换状态: %d → %d" % [role, current_state_enum, int(state)])
	current_state_enum = int(state)
	if current_state != null:
		# 先断开信号，防止旧状态在 queue_free 前的最后一帧再触发切换
		if current_state.state_transition_requested.is_connected(switch_state):
			current_state.state_transition_requested.disconnect(switch_state)
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self , data, player_detection_area, carrier, animation_player, ball_sprite, shot_particles)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "BallStateMachine"
	# 直接 add_child（非 deferred），确保 _enter_tree → on_enter_logic 在同一帧执行
	# 这样 velocity/height 在广播前就已经是正确的初始值
	add_child(current_state)
	
func shoot(shot_velocity: Vector2, initial_height: float = -1.0, power: float = 150, power_shot_type: PowerShotType = PowerShotType.NULL, shooter: Player = null) -> void:
	# 联机客户端：射门由服务端执行，客户端不直接操作球
	if SyncManager.is_client():
		return
	velocity = shot_velocity
	var shot_player := shooter if shooter != null else carrier
	clear_last_shooter_damage_grace()
	last_shooter = shot_player
	last_shooter_damage_grace_until = Time.get_ticks_msec() + SHOOTER_DAMAGE_GRACE_MS
	var player_power_shot_type := power_shot_type if power_shot_type != PowerShotType.NULL else (shot_player.power_shot_type if shot_player != null else PowerShotType.NORMAL)
	print("力量 %s 使用 %s" % [power, player_power_shot_type])
	if carrier != null and power >= POWER_SHOT_STRENGTH and carrier.is_facing_target_goal() and position.distance_to(carrier.target_goal.position) >= MIN_POWER_SHOT_DISTANCE:
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
			PowerShotType.INVISIBLE:
				switch_state(Ball.State.POWER_SHOT_INVISIBLE, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
			PowerShotType.JUMP:
				switch_state(Ball.State.POWER_SHOT_JUMP, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
			PowerShotType.FISH:
				switch_state(Ball.State.POWER_SHOT_FISH, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
			PowerShotType.TAIJI:
				switch_state(Ball.State.POWER_SHOT_TAIJI, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
			PowerShotType.GEMINI:
				switch_state(Ball.State.POWER_SHOT_GEMINI, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
			_:
				switch_state(Ball.State.SHOT, BallStateData.build().set_shot_normal_data(initial_height, power, player_power_shot_type))
	else:
		switch_state(Ball.State.SHOT, BallStateData.build().set_shot_normal_data(initial_height, power, PowerShotType.NORMAL))

	carrier = null

func tumble(shot_velocity: Vector2) -> void:
	# 联机客户端：由服务端驱动
	if SyncManager.is_client():
		return
	velocity = shot_velocity
	height_velocity = TUMBLE_HEIGHT_VELOCITY
	carrier = null
	clear_last_shooter_damage_grace()
	switch_state(Ball.State.FREEFORM, BallStateData.build().set_lock_duration(DURATION_TUMBLE_LOCK))

func pass_to(destination: Vector2, lock_duration: int = DURATION_PASS_LOCK) -> void:
	# 联机客户端：传球由服务端执行
	if SyncManager.is_client():
		return
	var direction := position.direction_to(destination)
	var distance := position.distance_to(destination)
	#	TODO 微积分方程  https://youtu.be/-4pGf5bW4-M?t=457
	var intensity := sqrt(2 * distance * get_ground_friction_at_current_patch())
	#	TODO 高度加速度方程 https://youtu.be/FHnebIUSXHk?t=345
	velocity = intensity * direction
	if distance > DISTANCE_HIGH_PASS:
		height_velocity = BallState.GRAVITY * distance / (1.8 * intensity)
	carrier = null
	clear_last_shooter_damage_grace()
	switch_state(Ball.State.FREEFORM, BallStateData.build().set_lock_duration(lock_duration))

func stop() -> void:
	velocity = Vector2.ZERO

func can_air_interact() -> bool:
	return current_state != null and current_state.can_air_interact()

func can_air_connect(air_connect_min_height: float, air_connect_max_height: float) -> bool:
	return height >= air_connect_min_height and height <= air_connect_max_height

func is_freeform() -> bool:
	return current_state != null and current_state is BallStateFreeForm

func is_player_protected_from_own_shot(player: Player) -> bool:
	if player == null or player != last_shooter:
		return false
	if Time.get_ticks_msec() <= last_shooter_damage_grace_until:
		return true
	clear_last_shooter_damage_grace()
	return false

func clear_last_shooter_damage_grace() -> void:
	last_shooter = null
	last_shooter_damage_grace_until = 0

func apply_field_condition(condition: FieldCondition, patch_map: FieldPatchMap = null) -> void:
	field_condition = condition
	field_patch_map = patch_map
	friction_air = base_friction_air * field_condition.get_ball_air_friction_multiplier()
	friction_ground = base_friction_ground * field_condition.get_ball_ground_friction_multiplier()

func get_ground_friction_at_current_patch() -> float:
	var patch_multiplier := field_patch_map.get_ball_ground_friction_multiplier(position) if field_patch_map != null else 1.0
	return friction_ground * patch_multiplier

func is_header_for_scoring_area(scoring_area: Area2D) -> bool:
	if not scoring_ratcast.is_colliding():
		return false
	return scoring_ratcast.get_collider() == scoring_area

func get_proximity_teammates_count(country: String) -> int:
	var players := player_proximity_area.get_overlapping_areas()
	return players.filter(func(p: Player): return p.country == country).size()

func on_team_reset() -> void:
	# 联机客户端：球重置由服务端驱动，客户端通过快照同步
	if SyncManager.is_client():
		return
	position = spawn_position
	velocity = Vector2.ZERO
	height = 0
	clear_last_shooter_damage_grace()
	switch_state(State.FREEFORM)
	
func on_kickoff_started() -> void:
	# 联机客户端：开球由服务端驱动
	if SyncManager.is_client():
		return
	pass_to(spawn_position + Vector2.DOWN * KICKOFF_PASS_DISTANCE, 0)
