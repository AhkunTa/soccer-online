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

func process_gravity(delta: float, bounciness: float = 0.0) -> void:
	if ball.height > 0 or ball.height_velocity > 0:
		ball.height_velocity -= GRAVITY * delta
		ball.height += ball.height_velocity
		if ball.height < 0:
			ball.height = 0
			if bounciness > 0 and ball.height_velocity < -0.1:
				ball.height_velocity = - ball.height_velocity * bounciness
				ball.velocity *= bounciness

func move_and_bounce(delta: float) -> void:
	var collision := ball.move_and_collide(ball.velocity * delta)
	if collision != null:
		ball.velocity = ball.velocity.bounce(collision.get_normal()) * BOUNCINESS
		AudioPlayer.play(AudioPlayer.Sound.BOUNCE)
		ball.switch_state(Ball.State.FREEFORM)

# 处理球与玩家碰撞造成伤害的逻辑
func check_player_damage() -> bool:
	# 获取所有与球碰撞的玩家
	var overlapping_players := player_detection_area.get_overlapping_bodies()

	for body in overlapping_players:
		if body is Player:
			var hit_player: Player = body as Player
			# 跳过已经击中过的玩家（避免重复伤害）
			if state_data.last_hit_player == hit_player:
				continue

			# 跳过处于球伤害无敌状态的玩家（射击者刚射击后）
			if hit_player.is_invincible_to_ball_damage:
				continue
			var damage := state_data.shot_power
			var player_hp := hit_player.current_hp
			print("球击中玩家: %s, 当前power: %.1f, 玩家HP: %.1f" % [hit_player.fullname, damage, player_hp])

			if damage >= player_hp:
				if damage / 2 >= player_hp:
					# 伤害足以击飞玩家
					hit_player.get_knocked_flying(ball.position.direction_to(hit_player.position))
				else:
					# 仅击倒玩家
					hit_player.get_hurt(ball.position.direction_to(hit_player.position))
				state_data.set_shot_power(damage - player_hp)
				state_data.set_last_hit_player(hit_player)

				print("剩余power: %.1f" % state_data.shot_power)

				# 如果power耗尽，球转换为自由状态
				if state_data.shot_power <= 0:
					ball.velocity = ball.velocity * 0.3 # 减速
					state_transition_requested.emit(Ball.State.FREEFORM)
					return true
			else:
				# 伤害小于HP，玩家接住球
				print("玩家 %s 接住了球！" % hit_player.fullname)
				hit_player.current_hp -= damage

				# 球被接住，转换为carried状态
				ball.carrier = hit_player
				hit_player.control_ball()
				state_transition_requested.emit(Ball.State.CARRIED)
				return true
	return false

func can_air_interact() -> bool:
	return false

# func get_state() -> Ball.State:
# 	if ball.carrier != null:
# 		return Ball.State.CARRIED
# 	elif ball.velocity == Vector2.ZERO and ball.height == 0:
# 		return Ball.State.FREEFORM
# 	else:
# 		return Ball.State.SHOT
