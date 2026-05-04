extends Area2D


func _ready() -> void:
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		var character := body as CharacterBody2D
		# Apply next physics frame so we win over any same-frame velocity writes in _physics_process.
		character.call_deferred("set", "velocity", Vector2(character.velocity.x, -800.0))
