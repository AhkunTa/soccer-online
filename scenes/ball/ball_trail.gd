class_name BallTrail
extends Node2D

enum TrailStyle {
	RAINBOW,
}

const RAINBOW_COLORS: Array[Color] = [
	Color(1.0, 0.05, 0.05, 1.0),
	Color(1.0, 0.45, 0.0, 1.0),
	Color(1.0, 0.95, 0.05, 1.0),
	Color(0.1, 0.9, 0.2, 1.0),
	Color(0.1, 0.55, 1.0, 1.0),
	Color(0.55, 0.15, 1.0, 1.0),
]

@export var max_points := 8
@export var min_sample_distance := 3.0
@export var stripe_width := 1.0
@export var stripe_gap := 0.0
@export var preview_length := 10.0
@export var target_path: NodePath

var style := TrailStyle.RAINBOW
var target: Node2D = null
var points: Array[Vector2] = []
var active := false


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	visible = false
	if target_path != NodePath():
		target = get_node_or_null(target_path) as Node2D
		start(TrailStyle.RAINBOW, target)


func start(new_style: TrailStyle = TrailStyle.RAINBOW, new_target: Node2D = null) -> void:
	style = new_style
	if new_target != null:
		target = new_target
	points.clear()
	active = true
	visible = true
	if target != null:
		points.append(target.global_position)
	queue_redraw()


func stop() -> void:
	active = false
	visible = false
	points.clear()
	queue_redraw()


func _process(_delta: float) -> void:
	if not active or target == null:
		return
	var target_position := target.global_position
	if points.is_empty() or points[0].distance_to(target_position) >= min_sample_distance:
		points.push_front(target_position)
		if points.size() > max_points:
			points.resize(max_points)
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	match style:
		TrailStyle.RAINBOW:
			_draw_rainbow_trail()


func _draw_rainbow_trail() -> void:
	var stripe_count := RAINBOW_COLORS.size()
	var total_height := stripe_count * stripe_width + (stripe_count - 1) * stripe_gap
	var top_offset := -total_height * 0.5
	var fade_denominator := float(max(points.size() - 1, 1))
	for stripe_index in range(stripe_count):
		var y_offset := top_offset + stripe_index * (stripe_width + stripe_gap) + stripe_width * 0.5
		var stripe_color := RAINBOW_COLORS[stripe_index]
		for point_index in range(points.size() - 1):
			var fade_start := 1.0 - float(point_index) / fade_denominator
			var fade_end := 1.0 - float(point_index + 1) / fade_denominator
			var alpha = min(fade_start, fade_end)
			var color := Color(stripe_color.r, stripe_color.g, stripe_color.b, alpha * alpha)
			var from_point := points[point_index] + Vector2(0, y_offset)
			var to_point := points[point_index + 1] + Vector2(0, y_offset)
			draw_line(from_point, to_point, color, stripe_width, true)
