class_name MainMenuScreen
extends Screen

@onready var selection_icon: TextureRect = %SelectionIcon
@onready var selectable_menu_nodes: Array[TextureRect] = [%SinglePlayerTexture, %TwoPlayerTexture, %OnlineGame]

const MENU_TEXTURES := [
	[preload("res://assets/art/ui/mainmenu/1-player.png"), preload("res://assets/art/ui/mainmenu/1-player-selected.png")],
	[preload("res://assets/art/ui/mainmenu/2-players.png"), preload("res://assets/art/ui/mainmenu/2-players-selected.png")]
]

var current_selected_index := 0
var is_active := false

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if is_active:
		if KeyUtils.is_action_just_pressed(Player.ControlScheme.P1, KeyUtils.Action.UP):
			change_selected_index(current_selected_index - 1)
		elif KeyUtils.is_action_just_pressed(Player.ControlScheme.P1, KeyUtils.Action.DOWN):
			change_selected_index(current_selected_index + 1)
		elif KeyUtils.is_action_just_pressed(Player.ControlScheme.P1, KeyUtils.Action.SHOOT):
			submit_selection(current_selected_index)
			
		
func submit_selection(_index: int) -> void:

	var country_default := DataLoader.get_countries()[1]

	var player_two := ""
	if current_selected_index == 0:
		player_two = ""
	elif current_selected_index == 1:
		player_two = country_default
	else:
		AudioPlayer.play(AudioPlayer.Sound.UI_SELECT)
		transition_screen(SoccerGame.ScreenType.ONLINE_LOBBY)
		return
	AudioPlayer.play(AudioPlayer.Sound.UI_SELECT)

	GameManager.player_setup = [country_default, player_two]
	transition_screen(SoccerGame.ScreenType.TEAM_SELECTION)


func refresh_ui() -> void:
	for i in range(selectable_menu_nodes.size()):
		if current_selected_index == i:
			selection_icon.position = selectable_menu_nodes[i].position + Vector2.LEFT * 25
			# TODO
			if i == 2:
				return
			selectable_menu_nodes[i].texture = MENU_TEXTURES[i][1]
		else:
			# TODO
			if i == 2:
				return
			selectable_menu_nodes[i].texture = MENU_TEXTURES[i][0]

func change_selected_index(index: int) -> void:
	current_selected_index = clamp(index, 0, selectable_menu_nodes.size() - 1)
	AudioPlayer.play(AudioPlayer.Sound.UI_NAV)
	refresh_ui()

func on_set_active() -> void:
	refresh_ui();
	is_active = true
