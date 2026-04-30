extends CharacterBody2D

@export var SPEED = 600.0
@export var CHAR_COLOR: Color = Color.WHITE
const JUMP_VELOCITY = -400.0
const MAX_JUMPS = 2

var jumps_left = MAX_JUMPS

var is_active_leader: bool = false

func set_is_leader(value: bool):
	is_active_leader = value
	# Visual feedback: leader keeps normal color, others are grayed out
	modulate = Color.WHITE if is_active_leader else Color(0.5, 0.5, 0.5)


func _ready():
	# Set the color of the Sprite2D to match the exported CHAR_COLOR variable.
	$Sprite2D.modulate = CHAR_COLOR

func _physics_process(delta: float) -> void:
	# EARLY RETURN: if not the leader, only apply gravity and stop
	if not is_active_leader:
		if not is_on_floor():
			velocity += get_gravity() * delta
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return

	# From here onward, continue normal movement and jump behavior...
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Reset jumps when on the floor.
	if is_on_floor():
		jumps_left = MAX_JUMPS

	# Handle jump and double jump.
	if Input.is_action_just_pressed("jump") and jumps_left > 0:
		velocity.y = JUMP_VELOCITY
		jumps_left -= 1

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
