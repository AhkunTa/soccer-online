class_name PlayerState

extends Node

signal state_transition_requested(new_state: Player.State, state_data: PlayerStateData)

var player: Player = null
var animation_player: AnimationPlayer = null
var state_data: PlayerStateData = null


func setup(context_player: Player, context_data: PlayerStateData,context_animation_player: AnimationPlayer) -> void:
	player = context_player
	animation_player = context_animation_player
	state_data = context_data

func transition_state(new_state: Player.State, state_data: PlayerStateData = PlayerStateData.new()) -> void:
	state_transition_requested.emit(new_state, state_data)

func on_animation_complete() -> void:
	pass
