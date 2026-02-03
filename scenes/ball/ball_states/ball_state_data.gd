class_name BallStateData

var lock_duration: int
var shot_height: float = -1.0
var shot_power: float = 150.0
var power_shot_type: Ball.PowerShotType = Ball.PowerShotType.NORMAL

static func build() -> BallStateData:
	return BallStateData.new()

func set_lock_duration(duration: int) -> BallStateData:
	lock_duration = duration
	return self

func set_shot_height(height: float) -> BallStateData:
	shot_height = height
	return self

func set_shot_power(power: float) -> BallStateData:
	shot_power = power
	return self

func set_power_shot_type(type: Ball.PowerShotType) -> BallStateData:
	power_shot_type = type
	return self

func set_shot_normal_data(height: float, power: float = 150.0, type: Ball.PowerShotType = Ball.PowerShotType.NORMAL) -> BallStateData:
	shot_height = height
	shot_power = power
	power_shot_type = type
	return self