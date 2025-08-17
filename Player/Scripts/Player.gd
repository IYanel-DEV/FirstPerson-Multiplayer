extends CharacterBody3D
class_name Player

# Exported variables
@export_category("Movement Settings")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 12.0
@export var ground_acceleration := 15.0
@export var ground_deceleration := 20.0
@export var air_control := 0.3

@export_category("Camera Settings")
@export var mouse_sensitivity := 0.002
@export var camera_tilt_amount := 8.0
@export var fov_normal := 75.0
@export var fov_sprint := 85.0

@export_category("Visual Effects")
@export var sway_smoothness := 10.0

# Nodes
@onready var camera := $Camera3D
@onready var collision_shape := $CollisionShape3D
@onready var local_controller = $LocalPlayerController
@onready var remote_controller = $RemotePlayerController

# Movement state
enum MovementState { WALKING, SPRINTING, AIRBORNE }
var current_state = MovementState.WALKING
var is_moving := false
var was_on_floor := true

# Jump system
var jump_buffer_timer := 0.0
var coyote_timer := 0.0
var can_jump := true
var jump_count := 0

# Visual effects
var camera_tilt := 0.0

func _enter_tree():
	if name.contains("_"):
		var peer_id = name.get_slice("_", 1).to_int()
		set_multiplayer_authority(peer_id)

func _ready():
	if multiplayer == null:
		return
	
	add_to_group("player")
	
	if is_multiplayer_authority():
		setup_local_player()
	else:
		setup_remote_player()
	
	print("Player ready: ", name, " | Authority: ", get_multiplayer_authority(), " | Is local: ", is_multiplayer_authority())

func setup_local_player():
	print("Setting up local player controls")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if camera:
		camera.current = true
	
	local_controller.enabled = true
	remote_controller.enabled = false

func setup_remote_player():
	print("Setting up remote player")
	if camera:
		camera.current = false
	
	local_controller.enabled = false
	remote_controller.enabled = true

func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= 35.0 * delta

func handle_landing():
	if not was_on_floor and is_on_floor():
		can_jump = true
		jump_count = 0
	was_on_floor = is_on_floor()

func update_visuals(delta: float):
	if not camera or not is_multiplayer_authority():
		return
		
	var target_tilt = 0.0
	if is_moving and is_on_floor():
		target_tilt = -local_controller.raw_input_dir.x * camera_tilt_amount
	
	camera_tilt = lerp(camera_tilt, target_tilt, delta * sway_smoothness)
	camera.rotation.z = deg_to_rad(camera_tilt)
	
	if current_state == MovementState.SPRINTING and local_controller.raw_input_dir.y < 0:
		camera.fov = lerp(camera.fov, fov_sprint, delta * 5.0)
	else:
		camera.fov = lerp(camera.fov, fov_normal, delta * 5.0)

func _physics_process(delta):
	handle_landing()
	update_visuals(delta)
