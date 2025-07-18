class_name PlayerStatePassing
extends PlayerState

func _enter_tree() -> void:
	animation_player.play("kick")
	player.velocity = Vector2.ZERO

func _process(delta: float) -> void:
	pass
	
func on_animation_complete() -> void:
	var pass_target := find_teammate_in_view()
	if  pass_target == null:
		ball.pass_to(ball.position + player.heading * player.speed)
	else :
		ball.pass_to(pass_target.position + pass_target.velocity)
	transition_state(Player.State.MOVING)

# 获取视野范围内最短距离队友
func find_teammate_in_view() -> Player:
	var players_in_view := teammate_detection_area.get_overlapping_bodies()
	var teammates_in_view := players_in_view.filter(
		func(p): return p != player
	)
	teammates_in_view.sort_custom(
		func (p1: Player,p2: Player):  return p1.position.distance_squared_to(player.position) < p2.position.distance_squared_to(player.position)
	)
	
	if teammates_in_view.size() > 0:
		return teammates_in_view[0]
	return null
