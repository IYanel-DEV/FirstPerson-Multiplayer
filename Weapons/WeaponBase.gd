extends Node3D
class_name WeaponBase

# Weapon stats
var weapon_name: String = "Base Weapon"
var damage: int = 10
var ammo: int = 30
var max_ammo: int = 30
var fire_rate: float = 0.2
var can_fire: bool = true
var is_aiming: bool = false
var is_reloading: bool = false

# Player reference
var player: Node = null

# Nodes
@onready var muzzle_point: Marker3D = $MuzzlePoint
@onready var audio_player: AudioStreamPlayer3D = $Hand_R/Pistol/AudioStreamPlayer3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Animation states
enum AnimationState { IDLE, AIM, AIM_HOLD, AIM_HOLD_SHOOT, SHOOT, MOVE, RELOAD }
var current_animation_state: AnimationState = AnimationState.IDLE
var previous_animation_state: AnimationState = AnimationState.IDLE

# Sounds
var shoot_sound = preload("res://Weapons/Pistol/Bullet/pistol-shot-233473.ogg")
var reload_sound = preload("res://Weapons/Pistol/Bullet/glock-gun-reload-319593.ogg")

# Bullet scene
var bullet_scene = preload("res://Weapons/Pistol/Bullet/Bullet.tscn")

# Multiplayer safety
var is_fully_ready: bool = false

func _ready():
	# Make sure weapon is visible by default
	visible = true
	
	# Mark as fully ready after a short delay
	await get_tree().create_timer(0.1).timeout
	is_fully_ready = true
	
	# Connect animation finished signal
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
	
	print("WeaponBase ready: ", weapon_name, " Visible: ", visible)

func _enter_tree():
	# Force visibility when added to scene tree
	visible = true
	print("Weapon entered tree: ", weapon_name, " Visible: ", visible)

# Check if we can safely use multiplayer functions
func can_use_multiplayer() -> bool:
	return is_fully_ready and is_inside_tree() and multiplayer.has_multiplayer_peer()

# Animation helper functions
func play_animation(anim_name: String, speed: float = 1.0, blend_time: float = 0.1):
	if animation_player and animation_player.has_animation(anim_name):
		# Set global speed scale
		animation_player.speed_scale = speed
		animation_player.play(anim_name, blend_time)
		return true
	return false

func transition_to_state(new_state: AnimationState, force: bool = false):
	if current_animation_state == new_state and not force:
		return
	
	previous_animation_state = current_animation_state
	current_animation_state = new_state
	
	match new_state:
		AnimationState.IDLE:
			play_animation("Idle")
		AnimationState.AIM:
			play_animation("Aim")
		AnimationState.AIM_HOLD:
			play_animation("Aim_Hold")
		AnimationState.AIM_HOLD_SHOOT:
			play_animation("Aim_Hold_Shoot")
		AnimationState.SHOOT:
			play_animation("Shoot")
		AnimationState.MOVE:
			play_animation("Move")
		AnimationState.RELOAD:
			play_animation("Reload")

func get_current_animation_length() -> float:
	if animation_player and animation_player.current_animation:
		# Get the animation resource to access its length
		var animation = animation_player.get_animation(animation_player.current_animation)
		if animation:
			return animation.length / animation_player.speed_scale
	return 0.0

func reload():
	if is_reloading or ammo == max_ammo:
		return
	
	# Only process reloading on the authority
	if can_use_multiplayer() and is_multiplayer_authority():
		print("Reloading...")
		is_reloading = true
		can_fire = false
		
		# Play reload animation
		transition_to_state(AnimationState.RELOAD)
		
		# Play sound
		_play_sound(reload_sound)
		
		# Sync with other players
		if can_use_multiplayer():
			rpc("_sync_reload_effects")
		
		# Wait for reload animation to complete
		var reload_time = get_current_animation_length()
		if reload_time <= 0:
			reload_time = 2.0  # Fallback if animation length can't be determined
		
		print("Reload time: ", reload_time)
		await get_tree().create_timer(reload_time).timeout
		
		# Finish reloading
		ammo = max_ammo
		is_reloading = false
		can_fire = true
		print("Reload complete!")

func fire():
	if not can_fire or ammo <= 0 or is_reloading:
		print("Can't fire right now!")
		return
	
	# Only process firing on the authority
	if can_use_multiplayer() and is_multiplayer_authority():
		print("Pew! Pew!")
		ammo -= 1
		can_fire = false
		
		# Play shoot animation
		if is_aiming:
			transition_to_state(AnimationState.AIM_HOLD_SHOOT)
		else:
			transition_to_state(AnimationState.SHOOT)
		
		# Spawn bullet
		_spawn_bullet()
		
		# Play sound
		_play_sound(shoot_sound)
		
		# Sync with other players
		if can_use_multiplayer():
			rpc("_sync_fire_effects", is_aiming)
		
		# Wait before can fire again
		await get_tree().create_timer(fire_rate).timeout
		can_fire = true

# Sync fire effects across network
@rpc("any_peer", "call_local")
func _sync_fire_effects(aiming: bool):
	if can_use_multiplayer() and not is_multiplayer_authority():
		# Play fire effects on other clients
		_play_sound(shoot_sound)
		if aiming:
			transition_to_state(AnimationState.AIM_HOLD_SHOOT)
		else:
			transition_to_state(AnimationState.SHOOT)

func _spawn_bullet():
	if bullet_scene == null:
		print("No bullet scene found!")
		return
	
	if muzzle_point == null:
		print("No muzzle point found!")
		return
	
	# Only spawn bullets on the authority
	if can_use_multiplayer() and is_multiplayer_authority():
		# Create bullet instance
		var bullet = bullet_scene.instantiate()
		
		# Add bullet to the scene tree properly
		var root = get_tree().root
		var current_scene = root.get_child(root.get_child_count() - 1)
		current_scene.add_child(bullet)
		
		# Position bullet at muzzle
		bullet.global_position = muzzle_point.global_position
		bullet.global_rotation = muzzle_point.global_rotation
		
		# Setup bullet (damage and direction)
		var shoot_direction = -muzzle_point.global_transform.basis.z
		bullet.setup(damage, shoot_direction, player)
		
		print("Bullet spawned by authority!")
		
		# Sync bullet creation across network with precise data
		rpc("_sync_bullet_spawn", 
			muzzle_point.global_position, 
			shoot_direction, 
			damage, 
			multiplayer.get_unique_id())

# Sync bullet spawn across network
@rpc("any_peer", "call_local")
func _sync_bullet_spawn(position: Vector3, direction: Vector3, bullet_damage: int, shooter_id: int):
	if not is_multiplayer_authority():
		# Create bullet instance for clients
		var bullet = bullet_scene.instantiate()
		
		# Add to scene tree properly
		var root = get_tree().root
		var current_scene = root.get_child(root.get_child_count() - 1)
		current_scene.add_child(bullet)
		
		# Position bullet at the exact same position
		bullet.global_position = position
		
		# Find shooter if available
		var shooter = get_tree().root.get_node_or_null("Player_" + str(shooter_id))
		
		# Setup bullet with same parameters
		bullet.setup(bullet_damage, direction, shooter)
		
		print("Bullet spawned on client!")

func _play_sound(sound):
	if audio_player and sound:
		audio_player.stream = sound
		audio_player.play()

func set_animation_speed(speed: float):
	if animation_player:
		animation_player.speed_scale = speed

# Sync reload effects across network
@rpc("any_peer", "call_local")
func _sync_reload_effects():
	if can_use_multiplayer() and not is_multiplayer_authority():
		# Play reload effects on other clients
		_play_sound(reload_sound)
		transition_to_state(AnimationState.RELOAD)

func equip():
	print(weapon_name + " equipped! Visible: ", visible)
	visible = true
	
	# Ensure all child meshes are visible too
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = true
		elif child.has_method("set_visible"):
			child.set_visible(true)
	
	# Make sure the weapon is in the right state
	transition_to_state(AnimationState.IDLE)
	
	# Sync equipment across network
	if can_use_multiplayer() and is_multiplayer_authority():
		rpc("_sync_equip")

@rpc("any_peer", "call_local")
func _sync_equip():
	if can_use_multiplayer() and not is_multiplayer_authority():
		visible = true
		
		# Ensure all child meshes are visible too
		for child in get_children():
			if child is MeshInstance3D:
				child.visible = true
			elif child.has_method("set_visible"):
				child.set_visible(true)
		
		transition_to_state(AnimationState.IDLE)
		print("Weapon synced equip: ", weapon_name)
		
		# Force a visibility update
		for mesh in get_children():
			if mesh is MeshInstance3D:
				mesh.set_instance_shader_parameter("", null)
func unequip():
	print(weapon_name + " unequipped!")
	visible = false
	transition_to_state(AnimationState.IDLE)
	
	# Sync unequip across network
	if can_use_multiplayer() and is_multiplayer_authority():
		rpc("_sync_unequip")

@rpc("any_peer", "call_local")
func _sync_unequip():
	if can_use_multiplayer() and not is_multiplayer_authority():
		visible = false
		transition_to_state(AnimationState.IDLE)

func aim(enable: bool):
	if is_reloading:
		return
	
	is_aiming = enable
	print("Aiming: " + str(enable))
	
	if enable:
		transition_to_state(AnimationState.AIM)
	else:
		transition_to_state(AnimationState.IDLE)
	
	# Sync aiming across network
	if can_use_multiplayer() and is_multiplayer_authority():
		rpc("_sync_aim", enable)

@rpc("any_peer", "call_local")
func _sync_aim(enable: bool):
	if can_use_multiplayer() and not is_multiplayer_authority():
		is_aiming = enable
		if enable:
			transition_to_state(AnimationState.AIM)
		else:
			transition_to_state(AnimationState.IDLE)

func set_moving(moving: bool):
	if is_reloading:
		return
		
	if moving:
		if not is_aiming:
			transition_to_state(AnimationState.MOVE)
	else:
		if not is_aiming:
			transition_to_state(AnimationState.IDLE)

func _on_animation_finished(anim_name: String):
	# Handle animation finished events
	match anim_name:
		"Shoot", "Aim_Hold_Shoot":
			# After shooting, transition based on current state
			if is_aiming:
				transition_to_state(AnimationState.AIM_HOLD)
			else:
				# Check if player is moving
				if player and player.has_method("is_moving") and player.is_moving:
					transition_to_state(AnimationState.MOVE)
				else:
					transition_to_state(AnimationState.IDLE)
		"Reload":
			# After reloading, transition based on current state
			if is_aiming:
				transition_to_state(AnimationState.AIM_HOLD)
			else:
				# Check if player is moving
				if player and player.has_method("is_moving") and player.is_moving:
					transition_to_state(AnimationState.MOVE)
				else:
					transition_to_state(AnimationState.IDLE)
		"Aim":
			transition_to_state(AnimationState.AIM_HOLD)

func assign_player(player_node: Node):
	player = player_node
	print("Player assigned to weapon: ", player.name)
	
	# Set multiplayer authority to match player
	if player.has_method("get_multiplayer_authority"):
		var player_authority = player.get_multiplayer_authority()
		set_multiplayer_authority(player_authority)
		print("Weapon authority set to: ", player_authority)
	else:
		print("Player doesn't have get_multiplayer_authority method")
