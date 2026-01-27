@tool
extends Control

@onready var chat_display: RichTextLabel = $VBoxContainer/ChatDisplay
@onready var input_field: LineEdit = $VBoxContainer/InputField
@onready var send_button: Button = $VBoxContainer/SendButton

func _ready():
	send_button.pressed.connect(_on_send_pressed)
	#input_field.text_submitted.connect(_on_text_submitted)

func _on_send_pressed():
	var message = input_field.text
	if message.is_empty():
		return
	
	# 发送到 AI 服务
	send_to_ai(message)
	input_field.clear()

func send_to_ai(message: String):
	# 这里集成你的 AI API
	# 例如 OpenAI, Claude, 或本地模型
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_ai_response)
	
	# 示例 API 调用
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"model": "gpt-4",
		"messages": [{"role": "user", "content": message}]
	})
	http_request.request("https://api.openai.com/v1/chat/completions", headers, HTTPClient.METHOD_POST, body)

func _on_ai_response(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("choices"):
		var ai_message = json["choices"][0]["message"]["content"]
		chat_display.append_text("\n[AI]: " + ai_message)
