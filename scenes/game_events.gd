extends Node

signal ball_possessed(player_name: String)
signal ball_released

signal kickoff_ready
signal kickoff_started

signal impact_received(impact_position: Vector2, is_high_impact: bool)

signal score_changed
signal team_scored(country_scored_on: String)
signal team_reset

signal game_over(winning_country: String)
