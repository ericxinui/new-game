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
## Time between entry effect and actual reposition.
@export var teleport_travel_delay: float = 0.35
## Particle tuning for teleport wisps.
@export var teleport_wisp_amount: int = 38
@export var teleport_wisp_lifetime: float = 0.45
@export var teleport_wisp_radius: float = 26.0
@export var teleport_wisp_speed_min: float = 30.0
@export var teleport_wisp_speed_max: float = 80.0
@export var teleport_wisp_radial_accel: float = 260.0
@export var teleport_wisp_size_px: int = 8

var _rng := RandomNumberGenerator.new()
var _teleport_in_progress := false
var _wisp_texture: Texture2D


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


func _get_wisp_texture() -> Texture2D:
	if _wisp_texture != null:
		return _wisp_texture
	var size := maxi(4, teleport_wisp_size_px)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center := Vector2((size - 1) * 0.5, (size - 1) * 0.5)
	var radius := center.x
	for y in range(size):
		for x in range(size):
			var p := Vector2(x, y)
			var dist := p.distance_to(center)
			if dist > radius:
				continue
			var t := 1.0 - (dist / radius)
			var alpha := pow(t, 1.8)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_wisp_texture = ImageTexture.create_from_image(img)
	return _wisp_texture


func _spawn_teleport_wisps(world_pos: Vector2, inward: bool) -> void:
	var particles := GPUParticles2D.new()
	particles.one_shot = true
	particles.amount = teleport_wisp_amount
	particles.lifetime = teleport_wisp_lifetime
	particles.explosiveness = 1.0
	particles.texture = _get_wisp_texture()
	particles.local_coords = false
	particles.global_position = world_pos
	particles.top_level = true
	particles.z_as_relative = false
	particles.z_index = 100
	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3.ZERO
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = teleport_wisp_radius
	mat.emission_ring_inner_radius = teleport_wisp_radius * 0.55
	mat.initial_velocity_min = teleport_wisp_speed_min
	mat.initial_velocity_max = teleport_wisp_speed_max
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.angular_velocity_min = -120.0
	mat.angular_velocity_max = 120.0
	if inward:
		mat.radial_accel_min = -teleport_wisp_radial_accel
		mat.radial_accel_max = -teleport_wisp_radial_accel * 0.7
		mat.color = Color(0.65, 0.95, 1.0, 0.95)
	else:
		mat.radial_accel_min = teleport_wisp_radial_accel
		mat.radial_accel_max = teleport_wisp_radial_accel * 1.35
		mat.color = Color(0.9, 1.0, 1.0, 0.95)
	particles.process_material = mat
	get_tree().current_scene.add_child(particles)
	particles.emitting = true
	if not particles.finished.is_connected(particles.queue_free):
		particles.finished.connect(particles.queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		if _teleport_in_progress:
			return
		_teleport_in_progress = true
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
		var start_pos := character.global_position
		_spawn_teleport_wisps(start_pos, true)
		character.velocity = Vector2.ZERO
		await get_tree().create_timer(teleport_travel_delay).timeout
		if not is_instance_valid(character):
			_teleport_in_progress = false
			return
		character.call_deferred("set", "global_position", target)
		character.call_deferred("set", "velocity", Vector2.ZERO)
		_spawn_teleport_wisps(target, false)
		_teleport_in_progress = false
