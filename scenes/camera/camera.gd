class_name Camera
extends Camera2D

const DISTANCE_TARGET :=100.0
const SMOOTHING_BALL_CARRIED :=2
const SMOOTHING_BALL_DEFAULT :=5

@export var ball: Ball


#噪声采样 相机震动
@export var shake_noise : FastNoiseLite
# 震动幅度
@export var shake_amplitude: float = 25
# 震动频率
@export var shake_frequency: float =1000
# 震动时长
@export var shake_duration: float = .5

var noise_sample: Vector2
var current_amplitude: float = 0


func _process(delta: float) -> void:
	#shake(delta)
	if ball.carrier !=null:
		position = ball.carrier.position + ball.carrier.heading * DISTANCE_TARGET
		position_smoothing_speed = SMOOTHING_BALL_CARRIED
	else:
		position = ball.position
		position_smoothing_speed = SMOOTHING_BALL_DEFAULT


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p1_shoot"):
		current_amplitude = shake_amplitude

func shake(delta: float)->void:
	if current_amplitude > 0: 
		noise_sample.x +=shake_frequency *delta
		noise_sample.y +=shake_frequency *delta
		
		var x_sample = shake_noise.get_noise_2d(noise_sample.x,0)
		var y_sample = shake_noise.get_noise_2d(0, noise_sample.y)
		
		offset = Vector2(current_amplitude * x_sample, current_amplitude * y_sample)
		
		current_amplitude -= shake_amplitude / shake_duration * delta
	else:
		current_amplitude = 0
		offset = Vector2.ZERO
		
	
	
