class_name AIBehaviorFactory
extends Node

var roles: Dictionary

func _init() -> void:
	roles = {
		Player.Role.FIELD: AIBehaviorField,
		Player.Role.GOALIE: AIBehaviorGoalie,
		Player.Role.DEFENDER: AIBehaviorDefender,
		Player.Role.OFFENDER: AIBehaviorOffender,
	}

func get_ai_behavior(role: Player.Role) -> AIBehavior:
	assert(roles.has(role), "AI behavior for role doesn't exist!")
	return roles.get(role).new()