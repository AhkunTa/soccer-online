@tool
extends EditorPlugin

var chat_panel: Control

func _enter_tree():
	# 实例化你的聊天面板场景
	chat_panel = preload("res://addons/ai_chat/chat_panel.tscn").instantiate()
	
	# 添加到编辑器的 Dock 区域
	# DOCK_SLOT_RIGHT_BL 表示右侧底部
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, chat_panel)

func _exit_tree():
	# 清理：移除面板并释放内存
	remove_control_from_docks(chat_panel)
	chat_panel.free()
