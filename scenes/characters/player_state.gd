class_name PlayerState
extends Node

signal state_transition_requested(new_state: Player.State, state_data: PlayerStateData)
var ai_behavior: AIBehavior = null
var player: Player = null
var animation_player: AnimationPlayer = null
var state_data: PlayerStateData = null
var ball: Ball = null
var teammate_detection_area: Area2D = null
var ball_detection_area: Area2D = null
var own_goal: Goal = null
var target_goal: Goal = null
var tackle_damage_emitter_area: Area2D = null

func setup(context_player: Player, context_data: PlayerStateData, context_animation_player: AnimationPlayer, context_ball: Ball, context_teammate_detection_area: Area2D, context_ball_detection_area: Area2D, context_own_goal: Goal, context_target_goal: Goal, context_tackle_damage_emitter_area: Area2D, context_ai_behavior: AIBehavior) -> void:
	player = context_player
	animation_player = context_animation_player
	state_data = context_data
	ball = context_ball
	teammate_detection_area = context_teammate_detection_area
	ball_detection_area = context_ball_detection_area
	own_goal = context_own_goal
	target_goal = context_target_goal
	tackle_damage_emitter_area = context_tackle_damage_emitter_area
	ai_behavior = context_ai_behavior

func transition_state(new_state: Player.State, data: PlayerStateData = PlayerStateData.new()) -> void:
	state_transition_requested.emit(new_state, data)

# ══════════════════════════════════════════════════════════════════════════════
# 模板方法 — 子类重写这些，不要直接重写 _enter_tree / _process
# ══════════════════════════════════════════════════════════════════════════════

## 基类统一处理 _enter_tree
func _enter_tree() -> void:
	on_enter_visual()
	if not _is_remote_on_client():
		on_enter_logic()

## 所有端都执行：动画、音效
func on_enter_visual() -> void:
	pass

## 仅服务端/单机/本地玩家执行：物理初始化
func on_enter_logic() -> void:
	pass

## 基类统一处理 _process
## 联机客户端的远程/CPU 玩家：跳过逻辑，由 SyncManager 快照驱动
func _process(delta: float) -> void:
	visual_process(delta)
	if not _is_remote_on_client():
		server_process(delta)

## 所有端都执行：动画更新等
func visual_process(_delta: float) -> void:
	pass

## 仅服务端/单机执行：输入处理、物理、状态转换
func server_process(_delta: float) -> void:
	pass

# ══════════════════════════════════════════════════════════════════════════════
# 工具方法
# ══════════════════════════════════════════════════════════════════════════════

## 当前玩家在联机客户端上是否为"远程驱动"（不执行本地逻辑）
func _is_remote_on_client() -> bool:
	if not SyncManager.is_client():
		return false
	return player.control_scheme == Player.ControlScheme.ONLINE_REMOTE \
		or player.control_scheme == Player.ControlScheme.CPU

func on_animation_complete() -> void:
	pass

func can_carry_ball() -> bool:
	return false

func can_pass() -> bool:
	return false

func is_ready_for_kickoff() -> bool:
	return false
