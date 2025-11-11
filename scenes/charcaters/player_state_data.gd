class_name PlayerStateData

var shot_direction: Vector2
var shot_power: float
var hurt_direction: Vector2
var pass_target: Player

static func build() -> PlayerStateData:
	return PlayerStateData.new()


func set_shot_direction(direction: Vector2) -> PlayerStateData:
	shot_direction = direction
	return self

func set_hurt_direction(direction: Vector2) -> PlayerStateData:
	hurt_direction = direction
	return self

func set_shot_power(power: float) -> PlayerStateData:
	shot_power = power
	return self

func reset() -> PlayerStateData:
	shot_direction = Vector2.ZERO
	shot_power = 0.0
	hurt_direction = Vector2.ZERO
	return self

func set_pass_target(player: Player) -> PlayerStateData:
	pass_target = player
	return self
