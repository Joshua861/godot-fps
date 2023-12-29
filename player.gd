extends CharacterBody3D

@export var air_control: float = 0.3
@export var speed: float = 10
@export var jump_velocity: float = 15
@export var acceleration: float = 10.0
@export var gravity: float = 20
# The speed that the camera turns on mouse movement, needs to be a super small number.
@export var mouse_sensitivity: float = 0.012
@export var dash_speed: float = 300
@export var dash_duration: float = 0.1
@export var max_stamina: int = 3
# In seconds per stamina bar
@export var stamina_regen_speed: float = 1
@export var midair_stamina_regen_speed = 2
@export var max_walljumps: int = 3
@export var walljump_force: float = 20

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
var is_dashing = false
var dash_timer: float = 0
var stamina: float
var walljumps: int = 3
var was_in_air = false

const path_to_stamina_bars = "/root/World/HUD/Stamina bars/"

func _ready():
	# Capture the mouse inside the window.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	footsteps_timer.timeout.connect(footsteps)
	footsteps_timer.start()
	stamina = max_stamina
	
	for i in range(3):
		var bar = get_node(str(path_to_stamina_bars, i + 1))
		var fill_stylebox = StyleBoxFlat.new()
		fill_stylebox.set_corner_radius_all(4)
		fill_stylebox.bg_color = Color.hex(0xafe4fc)
		fill_stylebox.border_color = Color.hex(0x217194)
		bar.add_theme_stylebox_override("fill", fill_stylebox)

func _process(delta):
	update_stamina_bars()

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
	if is_on_floor() and was_in_air:
		print("Landing")
		play_footstep("grass")
	
	# Add the gravity.
	if not is_on_floor() and not is_dashing:
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		play_sound_from_folder('res://assets/sounds/jump')
		velocity.y = jump_velocity
		
	if is_on_wall() and walljumps != 0 and Input.is_action_just_pressed("jump"):
		velocity = get_wall_normal() * walljump_force
		play_sound_from_folder('res://assets/sounds/jump') 
		velocity.y = jump_velocity
		walljumps -= 1
	
	if is_on_floor:
		walljumps = max_walljumps
	
	# Handle dashing.
	if Input.is_action_just_pressed("dash"):
		# Start the dash timer if not already dashing
		if not is_dashing and stamina >= 1:
			is_dashing = true
			stamina -= 1
			dash_timer = dash_duration
			camera.fov *= 1.1
			
			# Play dash dound
			var dash_sound = load("res://assets/sounds/dash.mp3")
			audio_player.stream = dash_sound
			audio_player.play()
			
	
	var target_fov: float
	
	if is_dashing:
		# Decrement timer.
		dash_timer -= delta
		velocity.y = 0
		# Calculate dash direction based on where you are facing.
		var dash_direction = (global_transform.basis * Vector3.FORWARD).normalized()
		# Add dash to velocity.
		velocity += dash_direction * dash_speed * delta
		
		# End dash if timer runs out.
		if dash_timer <= 0:
			is_dashing = false
		
		target_fov = 110 * 1.1
		
	else:
		var current_regen_speed
		if is_on_floor():
			current_regen_speed = stamina_regen_speed
		else:
			current_regen_speed = midair_stamina_regen_speed
		stamina = clamp(stamina + delta / current_regen_speed, 0, 3)
		target_fov = 110

	camera.fov = lerp(camera.fov, target_fov, delta * 10)
	
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
	
	# THIS MUST GO AT THE END
	if is_on_floor():
		was_in_air = false
	else:
		was_in_air = true
		

func game_over():
	get_tree().reload_current_scene()

func play_sound_from_folder(path):
	var dir = DirAccess.open(path)
	if dir:
		var files = dir.get_files()
		var file = 'import'
		while file.contains("import"):
			file = files[randi() % files.size()]
		var sound = load(str(path + "/", file))
		audio_player.stream = sound
		audio_player.play()

func play_footstep(type):
	play_sound_from_folder("res://assets/sounds/footsteps/" + type)

func footsteps():
	if moving and is_on_floor():
		if lastTouched == "bridge":
			play_footstep("wood")
		elif lastTouched == 'platform':
			play_footstep("grass")

func update_stamina_bars():
	for i in range(3):
		var bar = get_node(path_to_stamina_bars + str(i + 1))
		bar.value = clamp(stamina - i, 0, 1)
