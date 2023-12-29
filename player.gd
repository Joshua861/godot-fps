extends CharacterBody3D

@export var air_control: float = 0.3
@export var speed: float = 15
@export var jump_velocity: float = 15
@export var acceleration: float = 10.0
@export var gravity: float = 40
# The speed that the camera turns on mouse movement, needs to be a super small number.
@export var mouse_sensitivity: float = 0.005

@onready var camera = $Camera3D
@onready var audio_player = $AudioStreamPlayer
@onready var footsteps_timer = $"Footsteps timer"

const layers = {
	"platform": 4,
	"bridge": 8,
	"sea": 2,
	"wall": 16
}

var lastTouched: String
var moving = false

func _ready():
	# Capture the mouse inside the window.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	footsteps_timer.timeout.connect(footsteps)
	footsteps_timer.start()

func _unhandled_input(event):
	# Get mouse movement.
	if event is InputEventMouseMotion:
		# Rotate camera and player according to the mouse movement.
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		# Stop camera movement when looking straight up or straight down. So you can't so somersault infinitely.
		# Hard to explain, try removing it and see what happens when you look around.
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Movement.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	# Turn your movement key presses into a direction vector.
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		moving = true
		# A target velocity to move at, we will lerp to it, so there is a gradual increase.
		var target_velocity = Vector3(direction.x * speed, velocity.y, direction.z * speed)
		if is_on_floor():
			# Move with target_velocity; lerping so there is a gradual increase.
			velocity = lerp(velocity, target_velocity, acceleration * delta)
		else:
			# Reduce control over movement when in air.
			velocity = lerp(velocity, target_velocity, acceleration * delta * air_control)
	else:
		moving = false
		# Gradually decrease speed when not pressing any movement buttons. This is such a fucking mess I don't really understand what's going on.
		var target_velocity = Vector3(lerp(velocity.x, 0.0, acceleration * delta), velocity.y, lerp(velocity.z, 0.0, acceleration * delta))
		velocity = target_velocity

	move_and_slide()
	
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var body := collision.get_collider()
		var layer = body.collision_layer
		
		if layer == layers.sea:
			game_over()
		elif layer == layers.bridge:
			lastTouched = "bridge"
		elif layer == layers.platform:
			lastTouched = 'platform'
		elif layer == layers.wall:
			lastTouched = 'wall'
		

func game_over():
	# TODO: Add gameover logic.
	pass

func play_random_sfx_type(type):
	var dir = DirAccess.open("res://assets/sounds/footsteps/" + type)
	if dir:
		var files = dir.get_files()
		var file = 'import'
		while file.contains("import"):
			file = files[randi() % files.size()]
		var sound = load(str("res://assets/sounds/footsteps/" + type + "/", file))
		audio_player.stream = sound
		audio_player.play()

func footsteps():
	if moving and is_on_floor():
		if lastTouched == "bridge":
			play_random_sfx_type("wood")
		elif lastTouched == 'platform':
			play_random_sfx_type("grass")
