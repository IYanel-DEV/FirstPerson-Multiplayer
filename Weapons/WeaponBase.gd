# WeaponBase.gd
extends Node3D
class_name WeaponBase   


# Weapon properties
var weapon_name: String = "Base Weapon"
var damage: int = 10
var ammo: int = 30
var max_ammo: int = 30
var fire_rate: float = 0.2
var can_fire: bool = true
var is_aiming: bool = false
# WeaponBase.gd - Add this property
var weapon_scene_path: String = ""
# References
var player: Node = null
var animation_player: AnimationPlayer = null
# WeaponBase.gd 
var is_moving: bool = false
# Signals
signal weapon_fired
signal weapon_reloaded
signal ammo_changed(ammo, max_ammo)

func _ready():
	# Find animation player
	animation_player = $AnimationPlayer
	if not animation_player:
		push_error("Weapon missing AnimationPlayer: " + weapon_name)

# Called when weapon is equipped
func equip():
	visible = true
	if animation_player:
		animation_player.play("Idle")

# Called when weapon is unequipped
func unequip():
	visible = false
	if animation_player:
		animation_player.stop()

# WeaponBase.gd - Updated fire function
func fire():
	if not can_fire or ammo <= 0:
		return false
	
	# Stop any current animation to prevent conflicts
	if animation_player:
		animation_player.stop()
		animation_player.play("Shoot")
	
	ammo -= 1
	can_fire = false
	emit_signal("weapon_fired")
	emit_signal("ammo_changed", ammo, max_ammo)
	
	# Start cooldown timer with error handling
	var timer = get_tree().create_timer(fire_rate)
	if timer:
		timer.timeout.connect(_on_fire_cooldown, CONNECT_ONE_SHOT)
	else:
		# Fallback if timer creation fails
		can_fire = true
	
	return true

func _on_fire_cooldown():
	can_fire = true
	if is_aiming and animation_player:
		animation_player.play("Aim_Hold")

# WeaponBase.gd - Improved animation functions
func aim(aiming: bool):
	if not animation_player:
		return
	
	is_aiming = aiming
	
	if aiming:
		# If reloading, wait for reload to finish
		if animation_player.current_animation == "Reload":
			await animation_player.animation_finished
		
		animation_player.play("Aim")
		await animation_player.animation_finished
		
		if can_fire:
			animation_player.play("Aim_Hold")
	else:
		# Stop aim hold and return to appropriate state
		if animation_player.current_animation == "Aim_Hold" or animation_player.current_animation == "Aim_Hold_Shoot":
			animation_player.play_backwards("Aim")
			await animation_player.animation_finished
			
			if can_fire:
				if is_moving:
					animation_player.play("Move")
				else:
					animation_player.play("Idle")

func reload():
	if not animation_player:
		return
	
	# Cancel aiming if active
	if is_aiming:
		is_aiming = false
		if animation_player.current_animation == "Aim_Hold" or animation_player.current_animation == "Aim":
			animation_player.play_backwards("Aim")
			await animation_player.animation_finished
	
	# Play reload animation
	animation_player.play("Reload")
	await animation_player.animation_finished
	
	# Refill ammo
	ammo = max_ammo
	emit_signal("weapon_reloaded")
	emit_signal("ammo_changed", ammo, max_ammo)
	
	# Return to appropriate state after reload
	if can_fire:
		if is_aiming:
			# If player wants to aim again
			aim(true)
		elif is_moving:
			animation_player.play("Move")
		else:
			animation_player.play("Idle")
# Handle movement animation
func set_moving(moving: bool):
	if not animation_player or is_aiming:
		return
	
	if moving and animation_player.current_animation != "Move":
		animation_player.play("Move")
	elif not moving and animation_player.current_animation != "Idle":
		animation_player.play("Idle")
# WeaponBase.gd - Add animation priority system
func play_animation(anim_name: String, force: bool = false):
	if not animation_player:
		return
	
	# Animation priorities (higher number = higher priority)
	var priorities = {
		"Reload": 3,
		"Shoot": 2,
		"Aim_Hold_Shoot": 2,
		"Aim": 1,
		"Aim_Hold": 1,
		"Move": 0,
		"Idle": 0
	}
	
	var current_priority = priorities.get(animation_player.current_animation, -1)
	var new_priority = priorities.get(anim_name, -1)
	
	# Only play if higher priority or forced
	if force or new_priority >= current_priority:
		animation_player.play(anim_name)
