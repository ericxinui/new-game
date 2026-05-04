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
	var standing_on_ally = false

	# Verifica todas as colisões que aconteceram no último movimento
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		# Se o ângulo da colisão for para cima (chão) e o objeto for outro Player
		if collision.get_normal().dot(Vector2.UP) > 0.5 and collision.get_collider() is CharacterBody2D:
			standing_on_ally = true
			break

	# Nova lógica de gravidade
	if is_on_floor() or standing_on_ally:
		# Reseta o pulo se estiver no chão OU em cima de um amigo
		jumps_left = MAX_JUMPS
		# Pega a normal do chão (o vetor que aponta "para fora" da rampa)
		var normal = get_floor_normal()
		# Rotaciona o CharacterBody2D inteiro
		rotation = lerp_angle(rotation, normal.angle() + PI/2, 0.2)

	elif not is_on_floor() and not standing_on_ally:
		velocity += get_gravity() * delta
		# Volta para a rotação 0 quando estiver no ar
		$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, 0, 0.2)

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

	# Após o move_and_slide, verifique se tem alguém em cima de você
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_normal().dot(Vector2.DOWN) > 0.5: # Colisão vindo do teto
			var object_above = collision.get_collider()
			if object_above is CharacterBody2D:
				# "Empresta" um pouco da sua velocidade para o de cima
				# para que ele não atue como uma âncora (tira o efeito de lag)
				object_above.velocity = velocity
