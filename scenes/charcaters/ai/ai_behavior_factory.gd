class_name AIBehaviorFactory
extends Node

var roles: Dictionary

func _init() -> void:
	roles = {
		Player.Role.FIELD: AIBehaviorField,
		Player.Role.GOALIE: AIBehaviorGoalie,
	}

func get_ai_behavior(role: Player.Role) -> AIBehavior:
	# assert(roles.has(role), "AI behavior for role doesn't exist! ")
	if not roles.has(role):
		role = Player.Role.FIELD
	return roles.get(role).new()
