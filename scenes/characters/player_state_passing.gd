class_name PlayerStatePassing
extends PlayerState

func on_enter_visual() -> void:
	animation_player.play("kick")
	player.velocity = Vector2.ZERO
	AudioPlayer.play(AudioPlayer.Sound.PASS)

func on_animation_complete() -> void:
	if SyncManager.is_client():
		transition_state(Player.State.MOVING)
		return
	var pass_target := state_data.pass_target
	if pass_target == null:
		pass_target = _find_teammate_in_view()
	if pass_target != null:
		ball.pass_to(pass_target.position + pass_target.velocity)
	else:
		ball.pass_to(ball.position + player.heading * 200)
	transition_state(Player.State.MOVING)

func _find_teammate_in_view() -> Player:
	var players_in_view := teammate_detection_area.get_overlapping_bodies()
	var teammates_in_view := players_in_view.filter(
		func(p): return p != player and p.country == player.country
	)
	teammates_in_view.sort_custom(
		func(p1: Player, p2: Player): return p1.position.distance_squared_to(player.position) < p2.position.distance_squared_to(player.position)
	)
	if teammates_in_view.size() > 0:
		return teammates_in_view[0]
	return null

func can_pass() -> bool:
	return true
