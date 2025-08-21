# PlayerCamera.gd - Handles camera controls and effects
class_name PlayerCamera
extends Node

# ===== EXPORTED SETTINGS =====
@export_category("Camera Settings")
@export var mouse_sensitivity := 0.002
@export var camera_tilt_amount := 8.0
@export var fov_normal := 80.0
@export var fov_sprint := 120.0
@export var sway_smoothness := 10.0

# ===== REFERENCES =====
var player: CharacterBody3D
var camera: Camera3D
var movement_controller: PlayerMovement

# ===== CAMERA EFFECTS =====
var camera_tilt := 0.0
var input_enabled: bool = true

func _ready():
	player = get_parent()
	camera = player.get_node("Camera3D") if player.has_node("Camera3D") else null
	
	# Get movement controller reference
	movement_controller = player.get_node("PlayerMovement") if player.has_node("PlayerMovement") else null
	
	if player.is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if camera:
			camera.current = true

# Add process function to update camera effects
func _process(delta):
	if not input_enabled or not player.is_multiplayer_authority():
		return
		
	update_camera_effects(delta)

func update_camera_effects(delta):
	if not camera: 
		return
	
	# Get movement controller if not already set
	if not movement_controller:
		movement_controller = player.get_node("PlayerMovement") if player.has_node("PlayerMovement") else null
		if not movement_controller: 
			return
	
	# Camera tilt when strafing
	var target_tilt = 0.0
	if movement_controller.is_moving and player.is_on_floor():
		target_tilt = -movement_controller.raw_input_dir.x * camera_tilt_amount
	
	camera_tilt = lerp(camera_tilt, target_tilt, delta * sway_smoothness)
	camera.rotation.z = deg_to_rad(camera_tilt)
	
	# FOV changes when sprinting
	if movement_controller.current_state == movement_controller.MovementState.SPRINTING and movement_controller.raw_input_dir.y < 0:
		camera.fov = lerp(camera.fov, fov_sprint, delta * 5.0)
	else:
		camera.fov = lerp(camera.fov, fov_normal, delta * 5.0)

func _input(event):
	if not input_enabled or not player.is_multiplayer_authority():
		return
	
	# Mouse look
	if event is InputEventMouseMotion:
		player.rotate_y(-event.relative.x * mouse_sensitivity)
		if camera:
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))



func set_input_enabled(enabled: bool):
	input_enabled = enabled
	if player.is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE)
