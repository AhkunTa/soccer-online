class_name PlayStateRevocering

extends  PlayerState
const DURATION_REVOCER :=500

var time_start_revocery := Time.get_ticks_msec()

func _enter_tree() -> void:
	time_start_revocery = Time.get_ticks_msec()
	player.velocity = Vector2.ZERO
	animation_player.play("recover")

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - time_start_revocery > DURATION_REVOCER:
		transition_state(Player.State.MOVING)
