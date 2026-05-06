extends StaticBody2D
class_name Door

var _open: bool = false


func set_open(is_open: bool) -> void:
	if _open == is_open:
		return
	_open = is_open
	$AnimationPlayer.play("open" if is_open else "close")
	_set_collision_shapes_enabled(not is_open)


func _set_collision_shapes_enabled(enabled: bool) -> void:
	_apply_collision_recursive(self, enabled)


func _apply_collision_recursive(node: Node, collision_enabled: bool) -> void:
	for child in node.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = not collision_enabled
		elif child is CollisionPolygon2D:
			(child as CollisionPolygon2D).disabled = not collision_enabled
		elif child.get_child_count() > 0:
			_apply_collision_recursive(child, collision_enabled)
