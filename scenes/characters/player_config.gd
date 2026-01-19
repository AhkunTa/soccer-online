class_name PlayerConfig
extends Resource

# 角色移动速度
@export var speed: float = 80.0

# 角色能力/力量
@export var power: float = 150.0

# 跳跃下降速度
@export var jump_velocity: float = -400.0

# 身体强度/防御力
@export var strength: int = 5

# 跳跃冲击力
@export var jump_impulse: int = 20

# 角色
@export var player_name: String = "Player"


# 构造函数，提供默认值
func _init(
	p_speed: float = 80.0,
	p_power: float = 150.0,
	p_jump_velocity: float = -400.0,
	p_strength: int = 5,
	p_jump_impulse: int = 20,
	p_name: String = "Player",
):
	speed = p_speed
	power = p_power
	jump_velocity = p_jump_velocity
	strength = p_strength
	jump_impulse = p_jump_impulse
	player_name = p_name

# 从字典创建配置
static func from_dict(data: Dictionary) -> PlayerConfig:
	var config = PlayerConfig.new()
	if data.has("speed"):
		config.speed = data["speed"]
	if data.has("power"):
		config.power = data["power"]
	if data.has("jump_velocity"):
		config.jump_velocity = data["jump_velocity"]
	if data.has("strength"):
		config.strength = data["strength"]
	if data.has("jump_impulse"):
		config.jump_impulse = data["jump_impulse"]
	if data.has("player_name"):
		config.player_name = data["player_name"]
	if data.has("team_id"):
		config.team_id = data["team_id"]
	return config

# 转换为字典
func to_dict() -> Dictionary:
	return {
		"speed": speed,
		"power": power,
		"jump_velocity": jump_velocity,
		"strength": strength,
		"jump_impulse": jump_impulse,
		"player_name": player_name
	}

# 创建预设配置
static func create_default_config() -> PlayerConfig:
	return PlayerConfig.new()

static func create_fast_player() -> PlayerConfig:
	return PlayerConfig.new(120.0, 100.0, -350.0, 3, 15, "Fast Player")

static func create_strong_player() -> PlayerConfig:
	return PlayerConfig.new(60.0, 200.0, -450.0, 8, 25, "Strong Player")

static func create_balanced_player() -> PlayerConfig:
	return PlayerConfig.new(80.0, 150.0, -400.0, 5, 20, "Balanced Player")
