extends Area2D

## Assign the node that uses `door.gd` (a StaticBody2D with Door script).
@export var door: Node
@export var unpressed_texture: Texture2D       
@export var pressed_texture: Texture2D 
@onready var sprite = $Sprite2D

var _characters_on_button: int = 0


func _ready() -> void:
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _refresh_door() -> void:
	if door == null or not door.has_method("set_open"):
		return
	var should_open := _characters_on_button > 0
	door.set_open(should_open)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_characters_on_button += 1
		sprite.texture = pressed_texture
		_refresh_door()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_characters_on_button = maxi(0, _characters_on_button - 1)
		sprite.texture = unpressed_texture
		_refresh_door()
