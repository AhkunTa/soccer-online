
class_name AIBehavior
extends Node

const DURATION_AI_TICK_FREQUENCY :=200

var ball:Ball = null
var player :Player = null
var time_since_last_ai_tick :=Time.get_ticks_msec()


func _ready() -> void:
	time_since_last_ai_tick = Time.get_ticks_msec() + randi_range(0, DURATION_AI_TICK_FREQUENCY)


func setup(context_player: Player, context_ball:Ball) -> void:
	player = context_player
	ball = context_ball
	

func process_ai() -> void:
	if  Time.get_ticks_msec() - time_since_last_ai_tick > DURATION_AI_TICK_FREQUENCY:
		time_since_last_ai_tick = Time.get_ticks_msec()
		perform_ai_movement()
		perform_ai_decisions()

func perform_ai_movement() -> void:
	
	
	
	pass
func perform_ai_decisions() -> void:
	pass
