extends Area2D

@export var margin: float = 40.0
@export var use_camera_limits: bool = true
## When the camera never set limit_top (huge default), use this height band above limit_bottom.
@export var vertical_span_when_top_unlimited: float = 900.0
## Used when there is no camera or use_camera_limits is false. Global Rect2 (origin + size).
@export var manual_bounds: Rect2 = Rect2(-1950, -250, 3900, 1200)
## Ray starts this far above the top of the teleport bounds (smaller Y = higher on screen).
@export var ray_margin_above_bounds: float = 200.0
## How far below the bottom of the bounds the ray continues (search for ground).
@export var floor_probe_depth: float = 2000.0
## Push the contact point along the floor normal so the character sits on top, not inside.
@export var floor_surface_clearance: float = 4.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _bounds_global() -> Rect2:
	if not use_camera_limits:
		return manual_bounds
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return manual_bounds
	var left := float(cam.limit_left) + margin
	var right := float(cam.limit_right) - margin
	var bottom := float(cam.limit_bottom) - margin
	var top := float(cam.limit_top) + margin
	# Unset limit_top stays at a huge negative default; clamp to a playable band.
	if top < bottom - 50000.0:
		top = bottom - vertical_span_when_top_unlimited
	var w := maxf(1.0, right - left)
	var h := maxf(1.0, bottom - top)
	return Rect2(left, top, w, h)


func _shape_local_rect(shape: Shape2D) -> Rect2:
	if shape is RectangleShape2D:
		var rs := shape as RectangleShape2D
		return Rect2(rs.size * -0.5, rs.size)
	if shape is CapsuleShape2D:
		var cap := shape as CapsuleShape2D
		var w := cap.radius * 2.0
		var h := cap.height + 2.0 * cap.radius
		return Rect2(Vector2(-cap.radius, -h * 0.5), Vector2(w, h))
	if shape is CircleShape2D:
		var c := shape as CircleShape2D
		var rr := c.radius
		return Rect2(Vector2(-rr, -rr), Vector2(rr * 2.0, rr * 2.0))
	return Rect2()


func _global_aabb_bottom(character: CharacterBody2D) -> float:
	var max_y := -INF
	for child in character.get_children():
		if not (child is CollisionShape2D):
			continue
		var cs := child as CollisionShape2D
		if cs.disabled or cs.shape == null:
			continue
		var shape_xform: Transform2D = cs.global_transform
		var local_rect := _shape_local_rect(cs.shape)
		if local_rect.size == Vector2.ZERO:
			continue
		for corner in [
			local_rect.position,
			Vector2(local_rect.end.x, local_rect.position.y),
			Vector2(local_rect.position.x, local_rect.end.y),
			local_rect.end
		]:
			max_y = maxf(max_y, (shape_xform * corner).y)
	if max_y == -INF:
		return character.global_position.y + 50.0
	return max_y


func _ray_floor_at_x(character: CharacterBody2D, world_x: float, bounds: Rect2) -> Dictionary:
	var space := character.get_world_2d().direct_space_state
	var from := Vector2(world_x, bounds.position.y - ray_margin_above_bounds)
	var to := Vector2(world_x, bounds.end.y + floor_probe_depth)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [character.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		var character := body as CharacterBody2D
		var r := _bounds_global()
		var rx := _rng.randf_range(r.position.x, r.end.x)
		var rel_bottom := _global_aabb_bottom(character) - character.global_position.y
		var hit := _ray_floor_at_x(character, rx, r)
		var target: Vector2
		if hit.is_empty():
			target = character.initial_spawn_global
		else:
			var hit_pos: Vector2 = hit["position"]
			var hit_nor: Vector2 = hit["normal"]
			var anchor: Vector2 = hit_pos + hit_nor * floor_surface_clearance
			target = Vector2(rx, anchor.y - rel_bottom)
		character.call_deferred("set", "global_position", target)
		character.call_deferred("set", "velocity", Vector2.ZERO)
