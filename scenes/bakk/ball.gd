class_name  Ball
extends AnimatableBody2D
enum State {CARRIED, FREEFORM, SHOT}

var state_factory :=BallStateFactory.new()
var velocity:= Vector2.ZERO
var current_state :BallState = null
var carrier :Player = null
@onready var player_detection_area :Area2D = $PlayerDetection


func _ready() -> void:
	switch_state(State.FREEFORM)

func switch_state(state: Ball.State) -> void:
	if current_state != null:
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self, player_detection_area,carrier)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "BallStateMachine"
	call_deferred('add_child', current_state)
