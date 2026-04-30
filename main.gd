extends Node2D

@onready var camera = $Camera2D
@export var players: Array[CharacterBody2D] = [] # Drag your players here in the Inspector
@export_range(0.1, 20.0, 0.1) var camera_follow_speed: float = 8.0
var leader_index: int = 0

func _ready():
	camera.make_current()
	update_leader()
	var leader := _get_current_leader()
	if leader != null:
		camera.global_position = leader.global_position

func _input(_event):
	if _count_valid_players() == 0:
		return
	if Input.is_action_just_pressed("ui_focus_next"): # Or configure "change_leader" in the Input Map
		leader_index = (leader_index + 1) % players.size()
		update_leader()

func _physics_process(delta: float) -> void:
	# The camera follows the current leader's position
	var leader := _get_current_leader()
	if leader == null:
		return
	var target_position: Vector2 = leader.global_position
	var t: float = clampf(camera_follow_speed * delta, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(target_position, t)

func update_leader():
	if _count_valid_players() == 0:
		return
	if leader_index >= players.size():
		leader_index = 0
	# Notify all characters who the leader is now
	for i in range(players.size()):
		if players[i] == null or not is_instance_valid(players[i]):
			continue
		var is_leader = (i == leader_index)
		players[i].set_is_leader(is_leader)

func _get_current_leader() -> CharacterBody2D:
	if players.is_empty():
		return null
	if leader_index >= players.size():
		leader_index = 0

	var current = players[leader_index]
	if current != null and is_instance_valid(current) and current.is_inside_tree():
		return current

	for i in range(players.size()):
		var candidate = players[i]
		if candidate != null and is_instance_valid(candidate) and candidate.is_inside_tree():
			leader_index = i
			update_leader()
			return candidate

	return null

func _count_valid_players() -> int:
	var count := 0
	for player in players:
		if player != null and is_instance_valid(player):
			count += 1
	return count
