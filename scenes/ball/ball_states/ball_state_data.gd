class_name BallStateData

var lock_duration: int
var shot_height: float = -1.0

static func build() -> BallStateData:
	return BallStateData.new()

func set_lock_duration(duration: int) -> BallStateData:
	lock_duration = duration
	return self

func set_shot_height(height: float) -> BallStateData:
	shot_height = height
	return self