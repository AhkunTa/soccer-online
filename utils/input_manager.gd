extends Node

## InputManager - 全局输入管理器
var debug_mode: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	KeyUtils._init_dicts()


func _input(event: InputEvent) -> void:
	# 监听所有按键事件，更新待定状态
	if event is InputEventKey and event.pressed and debug_mode:
		print( '[input manager] key pressed: %s' % event.as_text()  , "dicts %s" % KeyUtils._pending_actions)
		# _update_pending_actions(event)
