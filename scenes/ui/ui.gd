class_name UI
extends CanvasLayer

@onready var flag_textures: Array[TextureRect] = [%HomeFlagTexture, %AwayFlagTexture]
@onready var score_label: Label = %ScoreLabel
@onready var player_label: Label = %PlayerLabel
@onready var time_label: Label = %TimeLabel

func _ready() -> void:
	update_score();
	update_flags();
	update_clock();

	player_label.text = ""
	GameEvents.ball_possessed.connect(on_ball_possessed.bind())

	GameEvents.ball_released.connect(on_ball_released.bind())


func _process(_delta: float) -> void:
	update_clock()

func update_score() -> void:
	score_label.text = ScoreHelper.get_score_text(GameManager.score)

func update_flags() -> void:
	for i in flag_textures.size():
		flag_textures[i].texture = FlagHelper.get_texture(GameManager.countries[i])

func update_clock() -> void:
	if GameManager.time_left < 0:
		time_label.modulate = Color.RED
	time_label.text = TimeHelper.get_time_text(GameManager.time_left)

func on_ball_possessed(player_name: String) -> void:
	player_label.text = player_name

func on_ball_released() -> void:
	player_label.text = ""
