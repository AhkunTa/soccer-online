class_name ActorsContainer
extends Node2D

const PLAYER_PREFAB := preload('res://scenes/charcaters/player.tscn')

const DURATION_WEIGHT_CACHE := 200


@export var ball: Ball
@export var goal_home: Goal
@export var goal_away: Goal

@export var team_home: String
@export var team_away: String

@onready var spawns: Node2D = %Spawns

# AI
var squad_home: Array[Player] = []
var squad_away: Array[Player] = []
var time_since_last_cache_refresh := Time.get_ticks_msec()

func _ready() -> void:
	squad_home = spawn_players(team_home, goal_home)
	spawns.scale.x = -1
	squad_away = spawn_players(team_away, goal_away)
	var player: Player = get_children().filter(func(c): return c is Player)[3]
	player.control_scheme = Player.ControlScheme.P1
	player.set_control_texture()

func _process(_delta: float) -> void:
	# 每 200 ms 触发AI 逻辑
	if Time.get_ticks_msec() - time_since_last_cache_refresh > DURATION_WEIGHT_CACHE:
		time_since_last_cache_refresh = Time.get_ticks_msec()
		set_on_duty_weights()
	

func spawn_players(country: String, own_goal: Goal) -> Array[Player]:
	var player_nodes: Array[Player] = []
	
	var players := DataLoader.get_squad(country)
	var target_goal := goal_home if own_goal == goal_away else goal_away
	for i in players.size():
		var player_position := spawns.get_child(i).global_position as Vector2
		var player_data := players[i] as PlayerResource
		var player := spawn_player(player_position, ball, own_goal, target_goal, player_data, country)
		player_nodes.append(player)
		add_child(player)
	return player_nodes

func spawn_player(player_position: Vector2, player_ball: Ball, own_goal: Goal, target_goal: Goal, player_data: PlayerResource, country: String) -> Player:
	var player := PLAYER_PREFAB.instantiate()
	print("Spawning player: ", player_data.full_name, ", skin: ", player_data.skin_color, ", country: ", country)
	player.initialize(player_position, player_ball, own_goal, target_goal, player_data, country)
	return player

func set_on_duty_weights() -> void:
	for squad in [squad_away, squad_home]:
		var cpu_players: Array[Player] = squad.filter(
			func(p:Player): return p.control_scheme == Player.ControlScheme.CPU and p.role != Player.Role.GOALIE
		)
		cpu_players.sort_custom(
			func(p1: Player, p2: Player): return p1.spawn_position.distance_squared_to(ball.position) < p2.spawn_position.distance_squared_to(ball.position)
		)
		# TODO 
		for i in range(cpu_players.size()):
			cpu_players[i].weight_on_duty_steering = 1 - ease(float(i)/ 10.0, 0.1)
	
