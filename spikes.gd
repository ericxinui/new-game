extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		if body.has_method("die"):
			# Death + scene reload are handled in player.die() after the animation.
			body.die()