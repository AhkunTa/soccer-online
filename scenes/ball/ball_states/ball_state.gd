class_name BallState
extends Node

signal state_transition_requested(new_state: Ball.State)
#基础反弹弹力 
const BOUNCINESS := 0.8
const GRAVITY := 10.0

var ball: Ball = null
var carrier: Player = null
var player_detection_area: Area2D = null
var animation_player: AnimationPlayer = null
var sprite: Sprite2D = null
var state_data: BallStateData = null
var shot_particles: GPUParticles2D = null


func setup(context_ball: Ball, context_state_data: BallStateData, context_player_detection_area: Area2D, context_carrier: Player, context_animation_player: AnimationPlayer, context_sprite: Sprite2D, context_shot_particles: GPUParticles2D) -> void:
	ball = context_ball
	player_detection_area = context_player_detection_area
	state_data = context_state_data
	carrier = context_carrier
	animation_player = context_animation_player
	sprite = context_sprite
	shot_particles = context_shot_particles

func transition_state(new_state: BallState, data: BallStateData = BallStateData.new()) -> void:
	state_transition_requested.emit(new_state, data)

# ══════════════════════════════════════════════════════════════════════════════
# 生命周期模板方法 — 子类重写 on_enter_visual / on_enter_logic / visual_process / server_process
# ══════════════════════════════════════════════════════════════════════════════

## 基类统一处理 _enter_tree，子类不要重写 _enter_tree，改写 on_enter_visual / on_enter_logic
func _enter_tree() -> void:
	on_enter_visual()
	if not SyncManager.is_client():
		on_enter_logic()

## 所有端都执行：动画、音效、特效
func on_enter_visual() -> void:
	pass

## 仅服务端/单机执行：物理初始化、速度设置、方向计算
func on_enter_logic() -> void:
	pass

## 基类统一处理 _process，子类不要重写 _process，改写 visual_process / server_process
func _process(delta: float) -> void:
	visual_process(delta)
	if not SyncManager.is_client():
		server_process(delta)

## 所有端都执行：动画更新、视觉特效
func visual_process(_delta: float) -> void:
	pass

## 仅服务端/单机执行：物理计算、碰撞检测、状态转换
func server_process(_delta: float) -> void:
	pass

# ══════════════════════════════════════════════════════════════════════════════
# 工具方法（动画、物理、伤害检测）
# ══════════════════════════════════════════════════════════════════════════════

func set_ball_animation_from_velocity(animation_name) -> void:
	if ball.velocity.x >= 0:
		animation_player.play(animation_name)
		animation_player.advance(0)
	else:
		animation_player.play_backwards(animation_name)
		animation_player.advance(0)

func set_ball_roll_animation_from_velocity() -> void:
	if ball.velocity == Vector2.ZERO:
		animation_player.play("idle")
	elif ball.velocity.x >= 0:
		animation_player.play("roll")
		animation_player.advance(0)
	else:
		animation_player.play_backwards("roll")
		animation_player.advance(0)

func process_gravity(delta: float, height_velocity_decay: float = 0.0, velocity_decay: float = 0.0) -> void:
	if ball.height > 0 or ball.height_velocity > 0:
		ball.height_velocity -= GRAVITY * delta
		ball.height += ball.height_velocity
		if ball.height < 0:
			ball.height = 0
			if height_velocity_decay > 0 and ball.height_velocity < -0.1:
				ball.height_velocity = - ball.height_velocity * height_velocity_decay
				ball.velocity *= velocity_decay

func move_and_bounce(delta: float) -> void:
	var collision := ball.move_and_collide(ball.velocity * delta)
	if collision != null:
		ball.velocity = ball.velocity.bounce(collision.get_normal()) * BOUNCINESS
		AudioPlayer.play(AudioPlayer.Sound.BOUNCE)
		ball.switch_state(Ball.State.FREEFORM)

func check_player_damage() -> bool:
	var overlapping_players := player_detection_area.get_overlapping_bodies()
	for body in overlapping_players:
		if body is Player:
			var hit_player: Player = body as Player
			if state_data.last_hit_player == hit_player:
				continue
			if hit_player.is_invincible_to_ball_damage:
				continue
			var damage := state_data.shot_power
			var player_hp := hit_player.current_hp
			if damage >= player_hp:
				if damage / 2 >= player_hp:
					hit_player.get_knocked_flying(ball.position.direction_to(hit_player.position))
				else:
					hit_player.get_hurt(ball.position.direction_to(hit_player.position))
				state_data.set_shot_power(damage - player_hp)
				state_data.set_last_hit_player(hit_player)
				if state_data.shot_power <= 0:
					ball.velocity = ball.velocity * 0.3
					state_transition_requested.emit(Ball.State.FREEFORM)
					return true
			else:
				hit_player.current_hp -= damage
				ball.carrier = hit_player
				hit_player.control_ball()
				state_transition_requested.emit(Ball.State.CARRIED)
				return true
	return false

func add_highlight_effect() -> void:
	var time = Time.get_ticks_msec() / 1000.0
	var pulse = (sin(time * 10.0) + 1.0) / 2.0
	var white = Color(2, 2, 2, 1)
	var red = Color(3, 0.3, 0.3, 1)
	sprite.modulate = white.lerp(red, pulse)

func remove_highlight_effect() -> void:
	sprite.modulate = Color(1, 1, 1, 1)

func can_air_interact() -> bool:
	return false
