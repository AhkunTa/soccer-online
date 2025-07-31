class_name PlayerResource

extends Resource


@export var full_name: String = "Default Player"
@export var skin_color: Player.SkinColor = Player.SkinColor.MEDIUM
@export var role: Player.Role = Player.Role.MIDFIELDER
@export var speed: float = 80.0
@export var power: float = 150.0

func _init(player_name: String, player_skin: Player.SkinColor, player_role: Player.Role, player_speed: float, player_power: float) -> void:
	# 初始化玩家资源
	full_name = player_name
	skin_color = player_skin
	role = player_role
	speed = player_speed
	power = player_power
