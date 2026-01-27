class_name TimeHelper

static func get_time_text(seconds: float) -> String:
	if seconds < 0:
		return "OVERTIME TIME !"
	else:
		var total_seconds := int(seconds)
		var minutes := total_seconds / 60
		var secs := total_seconds - minutes * 60
		return "%02d:%02d" % [minutes, secs]
