class_name BallState
extends Node

signal state_transition_requested(new_state: Ball.State)
#基础反弹弹力 
const BOUNCINESS :=0.8
const GRAVITY := 10.0

var ball: Ball = null
var carrier: Player = null
var player_detection_area :Area2D = null
var animation_player: AnimationPlayer = null
var sprite :Sprite2D = null
var state_data: BallStateData = null
var shot_particles : GPUParticles2D = null


func setup(context_ball:Ball, context_state_data: BallStateData,context_player_detection_area:Area2D,context_carrier: Player, context_animation_player: AnimationPlayer, context_sprite: Sprite2D, context_shot_particles: GPUParticles2D) -> void:
	ball = context_ball
	player_detection_area = context_player_detection_area
	state_data = context_state_data
	carrier = context_carrier
	animation_player = context_animation_player
	sprite = context_sprite
	shot_particles = context_shot_particles

func transition_state(new_state: BallState, data: BallStateData = BallStateData.new()) -> void:
	state_transition_requested.emit(new_state, data)

func set_ball_animation_from_velocity()-> void:
	if ball.velocity  ==  Vector2.ZERO:
		animation_player.play("idle")
	elif ball.velocity.x >= 0:
		animation_player.play("roll")
		animation_player.advance(0)
	else:
		animation_player.play_backwards("roll")
		animation_player.advance(0)

func process_gravity(delta: float, bounciness: float =0.0)-> void:
	if ball.height > 0 or ball.height_velocity > 0:
		ball.height_velocity -= GRAVITY * delta
		ball.height += ball.height_velocity
		
		if ball.height < 0:
			ball.height = 0
			if bounciness > 0 and ball.height_velocity < 0:
				ball.height_velocity = -ball.height_velocity * bounciness
				ball.velocity *= bounciness

func move_and_bounce(delta: float)-> void:
	var collision := ball.move_and_collide(ball.velocity * delta)
	if collision !=null:
		ball.velocity = ball.velocity.bounce(collision.get_normal()) * BOUNCINESS
		ball.switch_state(Ball.State.FREEFORM)

func can_air_interact() -> bool:
	return false

# func get_state() -> Ball.State:
# 	if ball.carrier != null:
# 		return Ball.State.CARRIED
# 	elif ball.velocity == Vector2.ZERO and ball.height == 0:
# 		return Ball.State.FREEFORM
# 	else:
# 		return Ball.State.SHOT
