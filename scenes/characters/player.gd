class_name Player
extends CharacterBody2D

signal swap_requested(player: Player)

const CONTROL_SCENE_MAP: Dictionary = {
	ControlScheme.CPU: preload("res://assets/art/props/cpu.png"),
	ControlScheme.P1: preload("res://assets/art/props/1p.png"),
	ControlScheme.P2: preload("res://assets/art/props/2p.png"),
	ControlScheme.ONLINE_LOCAL: preload("res://assets/art/props/1p.png"),
	ControlScheme.ONLINE_REMOTE: preload("res://assets/art/props/2p.png"),
}
const BALL_CONTROL_HEIGHT_MAX := 10.0

const GRAVITY := 8.0
const MAX_JUMPS := 2
const BASE_GROUND_ACCELERATION := 760.0
const BASE_STOP_FRICTION := 860.0
# 只在从低摩擦地块切到高抓地地块时，额外追回一部分惯性。
const PATCH_TRANSITION_GRIP := 2.5
const SLIP_MIN_SPEED := 35.0
const SLIP_COOLDOWN := 0.8

@export var speed: float = 80.0
@export var power: float = 150.0
@export var JUMP_VELOCITY: float = -400.0
@export var strength := 5
@export var JUMP_IMPULES := 20
@export var control_scheme: ControlScheme
@export var ball: Ball
@export var own_goal: Goal
@export var target_goal: Goal
var field_condition: FieldCondition = FieldCondition.grass()
var field_patch_map: FieldPatchMap = null
# max hp 后续为 临时效果系统预留
@export var max_hp: float = 100.0
@export var current_hp: float = 100.0
@export var jump_count := 0

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var player_sprite: Sprite2D = %PlayerSprite
@onready var teammate_detection_area: Area2D = %TeammateDetectionArea
@onready var control_sprite: Sprite2D = %ControlSprite
@onready var ball_detection_area: Area2D = %BallDetectionArea
@onready var tackle_damage_emitter_area: Area2D = %TackleDamageEmitterArea
@onready var opponent_detection_area: Area2D = %OpponentDetectionArea
@onready var permanent_damage_emitter_area: Area2D = %PermanentDamageEmitterArea
@onready var goalie_hands_collider: CollisionShape2D = %GoalieHandsCollider

@onready var root_particles: Node2D = %RootParticles
@onready var run_particles: GPUParticles2D = %RunParticles


enum ControlScheme {CPU, P1, P2, ONLINE_LOCAL, ONLINE_REMOTE}
enum State {MOVING, RUNNING, TACKLING, JUMPING, RECOVERING, PREPPING_SHOT, SHOOTING, JUMPING_SHOT, PASSING, HEADER, VOLLEY_KICK, BICYCLE_KICK, CHEST_CONTROL, HURT, DIVING, CELEBRATING, MOURNING, RESETTING}


enum Role {GOALIE, DEFENDER, MIDFIELDER, FORWARD, FIELD}
enum SkinColor {LIGHT, MEDIUM, DARK}
# TODO 更多 动作
# 跳跃技巧：0 无，1 普通二段跳，2 空中飞行但不能踢球，3 带球高跳并空中旋转一圈
enum JumpSkill {NONE, DOUBLE_JUMP, AIR_FLY, BALL_SPIN_JUMP}
# 运球技巧：0 无，1 跑动中双击上下方向键折跃过人，2 带球旋转并造成伤害
enum DribbleSkill {NONE, WARP_UP, SPIN_DAMAGE}
# 冲刺技巧：0 无，1 跑动中双击前进方向短冲，2 原地留下幻影并向前冲刺
enum ChargeSkill {NONE, SHORT_DASH, PHANTOM_DASH}
# 守门技巧：0 无，1 冲刺扑球，2 旋转扑球
enum GoalieSkill {NONE, DIVING_SAVE, SPIN_SAVE}

var ai_behavior_factory := AIBehaviorFactory.new()
var current_ai_behavior: AIBehavior = null
var country := ""
# 基础属性
var fullname := ""
var role := Player.Role.MIDFIELDER
var skin_color := Player.SkinColor.MEDIUM
var jump_skill := Player.JumpSkill.DOUBLE_JUMP
var dribble_skill := Player.DribbleSkill.WARP_UP
var charge_skill := Player.ChargeSkill.SHORT_DASH
var goalie_skill := Player.GoalieSkill.NONE
var heading := Vector2.RIGHT
var height := 0.0
var height_velocity := 0.0
var air_time_since_jump := 0.0
var kickoff_position := Vector2.ZERO
var current_state: PlayerState = null
var state_factory := PlayerStateFactory.new()
var spawn_position := Vector2.ZERO
var weight_on_duty_steering := 0.0
var power_shot_type := Ball.PowerShotType.STRONG
# 临时效果系统
var active_boosts: Dictionary = {}
var healing_active: bool = false
var healing_rate: float = 0.0
# 网络同步属性
var network_index: int = -1
var owner_peer_id: int = -1
var current_state_enum: int = -1 # 当前状态枚举值，用于网络同步
var slip_cooldown_left := 0.0
# 缓存上一帧脚下地块参数，用来判断是否刚跨过特殊地块边界。
var last_ground_patch := FieldCondition.PatchSet.NONE
var last_stopping_friction_multiplier := 1.0
var last_acceleration_multiplier := 1.0

func _ready() -> void:
	set_ai_behavior()
	# 应用配置到玩家属性
	set_control_texture()
	set_shader_properties()
	permanent_damage_emitter_area.monitoring = role == Role.GOALIE
	goalie_hands_collider.disabled = role != Role.GOALIE
	tackle_damage_emitter_area.body_entered.connect(on_tackle_player.bind())
	permanent_damage_emitter_area.body_entered.connect(on_tackle_player.bind())
	spawn_position = position
	GameEvents.team_scored.connect(on_team_scored.bind())
	GameEvents.game_over.connect(on_game_over.bind())
	var initial_position := kickoff_position if country == GameManager.current_match.country_home else spawn_position
	switch_state(Player.State.RESETTING, PlayerStateData.build().set_reset_position(initial_position))

# 着色器
func set_shader_properties() -> void:
	player_sprite.material.set_shader_parameter('skin_color', skin_color)
	var countries = DataLoader.get_countries()

	var country_color_index := countries.find(country)
	var team_color_index = clampi(country_color_index, 0, countries.size() - 1)

	player_sprite.material.set_shader_parameter('team_color', team_color_index)

func set_ai_behavior() -> void:
	current_ai_behavior = ai_behavior_factory.get_ai_behavior(role)
	current_ai_behavior.setup(self , ball, opponent_detection_area, teammate_detection_area);

	current_ai_behavior.name = "AI Behavior"
	add_child(current_ai_behavior)

func _process(delta: float) -> void:
	# 联机客户端的远程/CPU 玩家：所有状态由 SyncManager 快照驱动
	var is_remote_on_client := SyncManager.is_client() and (control_scheme == ControlScheme.ONLINE_REMOTE or control_scheme == ControlScheme.CPU)
	if is_remote_on_client:
		# 仅更新精灵显示（位置、速度、朝向、高度由 SyncManager 设置）
		flip_sprites()
		set_sprite_visiable()
		player_sprite.position = Vector2.UP * height
		return
	flip_sprites()
	set_sprite_visiable()
	process_gravity(delta)
	# update_temporary_effects(delta)
	move_and_slide()

func initialize(context_position: Vector2, context_kickoff_position: Vector2, context_ball: Ball, context_own_goal: Goal, context_target_goal: Goal, context_player_data: PlayerResource, context_country: String) -> void:
	position = context_position
	kickoff_position = context_kickoff_position
	ball = context_ball
	own_goal = context_own_goal
	target_goal = context_target_goal
	speed = context_player_data.speed
	power = context_player_data.power
	role = context_player_data.role
	skin_color = context_player_data.skin_color
	fullname = context_player_data.full_name
	power_shot_type = context_player_data.power_shot_type
	max_hp = context_player_data.hp
	current_hp = context_player_data.hp
	heading = Vector2.LEFT if target_goal.position.x < position.x else Vector2.RIGHT
	country = context_country
	
func switch_state(state: State, state_data: PlayerStateData = PlayerStateData.new()) -> void:
	var old_state := current_state_enum
	current_state_enum = state
	if current_state != null:
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self , state_data, animation_player, ball, teammate_detection_area, ball_detection_area, own_goal, target_goal, tackle_damage_emitter_area, current_ai_behavior)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "PlayerStateMachine: " + str(state)
	call_deferred("add_child", current_state)
	# 联机服务端：状态变化时立即广播给客户端
	if SyncManager.is_server() and network_index >= 0 and old_state != state:
		SyncManager.server_sync_player_state(network_index, state)

func set_tackling_animation() -> void:
	animation_player.play("tackle")

func set_movement_animation() -> void:
	if velocity.length() < 1:
		animation_player.play('idle')
	elif current_state_enum == State.RUNNING:
		animation_player.play("run")
	else:
		animation_player.play('walk')
	

func set_control_scheme(scheme: ControlScheme) -> void:
	control_scheme = scheme
	set_control_texture()


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

func face_towards_goal() -> void:
	if not is_facing_target_goal():
		heading = heading * -1

func flip_sprites() -> void:
	if heading == Vector2.RIGHT:
		player_sprite.flip_h = false
		tackle_damage_emitter_area.scale.x = 1
		opponent_detection_area.scale.x = 1
		root_particles.scale.x = 1
	elif heading == Vector2.LEFT:
		player_sprite.flip_h = true
		tackle_damage_emitter_area.scale.x = -1
		opponent_detection_area.scale.x = -1
		root_particles.scale.x = -1


func set_sprite_visiable() -> void:
	control_sprite.visible = has_ball() or not control_scheme == ControlScheme.CPU
	run_particles.emitting = current_state_enum == State.RUNNING and velocity.length() >= 1

func has_ball() -> bool:
	return ball.carrier == self

func is_ready_for_kickoff() -> bool:
	return current_state != null and current_state.is_ready_for_kickoff()

func get_hurt(hurt_origin: Vector2) -> void:
	switch_state(Player.State.HURT, PlayerStateData.build().set_hurt_direction(hurt_origin))

# TODO 击飞状态 倒地状态 倒地后站立恢复状态 ...
func get_knocked_flying(hurt_origin: Vector2) -> void:
	switch_state(Player.State.HURT, PlayerStateData.build().set_hurt_direction(hurt_origin))

func apply_ground_movement(input_direction: Vector2, delta: float, movement_speed_scale: float = 1.0) -> void:
	var direction := input_direction.limit_length(1.0)
	var previous_patch := last_ground_patch
	var previous_stopping_friction := last_stopping_friction_multiplier
	var previous_acceleration := last_acceleration_multiplier
	var current_patch := _get_current_ground_patch()
	var target_velocity := Vector2.ZERO
	var speed_multiplier := _get_player_speed_multiplier() * movement_speed_scale
	var acceleration_multiplier := _get_acceleration_multiplier()
	var stopping_friction_multiplier := _get_stopping_friction_multiplier()
	if direction != Vector2.ZERO:
		target_velocity = direction * speed * speed_multiplier
		target_velocity += _get_wind_velocity_effect()
	var acceleration := BASE_GROUND_ACCELERATION * acceleration_multiplier
	if direction == Vector2.ZERO:
		acceleration = BASE_STOP_FRICTION * stopping_friction_multiplier
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	_apply_patch_transition_grip(
		previous_patch,
		current_patch,
		previous_stopping_friction,
		stopping_friction_multiplier,
		previous_acceleration,
		acceleration_multiplier,
		target_velocity,
		direction,
		delta
	)
	last_ground_patch = current_patch as FieldCondition.PatchSet
	last_stopping_friction_multiplier = stopping_friction_multiplier
	last_acceleration_multiplier = acceleration_multiplier
	_try_slip(direction, delta)

func apply_field_modifiers_to_velocity(delta: float) -> void:
	var desired_direction := velocity.normalized() if velocity != Vector2.ZERO else Vector2.ZERO
	var target_velocity := velocity * _get_player_speed_multiplier()
	if velocity != Vector2.ZERO:
		target_velocity += _get_wind_velocity_effect()
	var acceleration := BASE_GROUND_ACCELERATION * _get_acceleration_multiplier()
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	_try_slip(desired_direction, delta)

func _get_wind_velocity_effect() -> Vector2:
	return field_condition.get_wind_vector() * field_condition.get_wind_player_force()

func get_stopping_friction_multiplier_at_current_patch() -> float:
	return _get_stopping_friction_multiplier()

func _get_current_ground_patch() -> FieldCondition.PatchSet:
	if field_patch_map == null:
		return FieldCondition.PatchSet.NONE
	return field_patch_map.get_patch_at(global_position)

func reset_field_patch_tracking() -> void:
	# 初始化后先记录当前地块，避免第一帧被误判为跨地块。
	last_ground_patch = _get_current_ground_patch()
	last_stopping_friction_multiplier = _get_stopping_friction_multiplier()
	last_acceleration_multiplier = _get_acceleration_multiplier()

func _apply_patch_transition_grip(
	previous_patch: FieldCondition.PatchSet,
	current_patch: FieldCondition.PatchSet,
	previous_stopping_friction: float,
	current_stopping_friction: float,
	previous_acceleration: float,
	current_acceleration: float,
	target_velocity: Vector2,
	direction: Vector2,
	delta: float
) -> void:
	if previous_patch == current_patch:
		return
	if direction == Vector2.ZERO:
		# 停止输入时，进入更高抓地地块应更快吃掉从冰/泥地带出的滑行。
		var friction_gain := current_stopping_friction - previous_stopping_friction
		if friction_gain <= 0.0:
			return
		velocity = velocity.move_toward(Vector2.ZERO, BASE_STOP_FRICTION * friction_gain * PATCH_TRANSITION_GRIP * delta)
		return

	if velocity.length() <= target_velocity.length():
		return
	var acceleration_gain := current_acceleration - previous_acceleration
	if acceleration_gain <= 0.0:
		return
	# 仍在移动时，把低摩擦地块带出的超额速度拉回到新地块目标速度。
	velocity = velocity.move_toward(target_velocity, BASE_GROUND_ACCELERATION * acceleration_gain * PATCH_TRANSITION_GRIP * delta)

# TODO 去掉滑倒 没必要
func _try_slip(direction: Vector2, delta: float) -> void:
	slip_cooldown_left = maxf(0.0, slip_cooldown_left - delta)
	var slip_chance_per_second := _get_slip_chance_per_second()
	if height > 0 or slip_chance_per_second <= 0.0 or slip_cooldown_left > 0.0:
		return
	if velocity.length() < SLIP_MIN_SPEED:
		return
	var stopping_hard := direction == Vector2.ZERO
	var turning_hard := direction != Vector2.ZERO and velocity.normalized().dot(direction) < -0.25
	if not stopping_hard and not turning_hard:
		return
	var chance := slip_chance_per_second * delta
	if randf() <= chance:
		slip_cooldown_left = SLIP_COOLDOWN
		var slip_direction := velocity.normalized()
		switch_state(Player.State.HURT, PlayerStateData.build().set_hurt_direction(slip_direction))

func _get_player_speed_multiplier() -> float:
	var patch_multiplier := field_patch_map.get_player_speed_multiplier(global_position) if field_patch_map != null else 1.0
	return field_condition.get_player_speed_multiplier() * patch_multiplier

func _get_acceleration_multiplier() -> float:
	var patch_multiplier := field_patch_map.get_acceleration_multiplier(global_position) if field_patch_map != null else 1.0
	return field_condition.get_acceleration_multiplier() * patch_multiplier

func _get_stopping_friction_multiplier() -> float:
	var patch_multiplier := field_patch_map.get_stopping_friction_multiplier(global_position) if field_patch_map != null else 1.0
	return field_condition.get_stopping_friction_multiplier() * patch_multiplier

func _get_slip_chance_per_second() -> float:
	var patch_bonus := field_patch_map.get_slip_chance_bonus(global_position) if field_patch_map != null else 0.0
	return field_condition.get_slip_chance_per_second() + patch_bonus

func set_control_texture() -> void:
	control_sprite.texture = CONTROL_SCENE_MAP[control_scheme]

func get_pass_request(player: Player) -> void:
	if ball.carrier == self and current_state != null and current_state.can_pass():
		switch_state(Player.State.PASSING, PlayerStateData.build().set_pass_target(player))

func on_animation_complete() -> void:
	if current_state != null:
		current_state.on_animation_complete()

func on_team_scored(team_scored_on: String) -> void:
	if country == team_scored_on:
		switch_state(Player.State.MOURNING)
	else:
		switch_state(Player.State.CELEBRATING)

func on_game_over(winning_country: String) -> void:
	if country == winning_country:
		switch_state(Player.State.CELEBRATING)
	else:
		switch_state(Player.State.MOURNING)

func can_carry_ball() -> bool:
	return current_state != null and current_state.can_carry_ball()

func on_tackle_player(player: Player) -> void:
	if player != self and player.country != country and player == ball.carrier:
		print("Tackled player get hurt: ", player.fullname)
		player.get_hurt(position.direction_to(player.position))


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


func control_ball() -> void:
	if ball.height >= BALL_CONTROL_HEIGHT_MAX:
		switch_state(Player.State.CHEST_CONTROL, PlayerStateData.new())

func is_facing_target_goal() -> bool:
	var direction_to_target_goal := position.direction_to(target_goal.position)
	return heading.dot(direction_to_target_goal) > 0

func get_direction_to_opponent_goal() -> Vector2:
	return position.direction_to(target_goal.get_random_target_position())

func get_direction_to_bounce_goal() -> Vector2:
	return position.direction_to(target_goal.get_bounce_target_position())
