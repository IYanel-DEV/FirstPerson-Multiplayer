extends Node3D
class_name WeaponBase

# Weapon stats
var weapon_name: String = "Assault Rifle"
var damage: int = 10
var ammo: int = 30
var max_ammo: int = 30
var fire_rate: float = 0.2
var can_fire: bool = true
var is_aiming: bool = false
var is_reloading: bool = false

# Player reference - FIXED: Use Node instead of CharacterBody3D
var player: Node = null

# Nodes
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle_point: Marker3D = $MuzzlePoint
@onready var audio_player: AudioStreamPlayer3D = $Hand_R/Pistol/AudioStreamPlayer3D

# Sounds - UPDATE THESE PATHS TO YOUR ACTUAL FILES!
var shoot_sound = preload("res://Weapons/Pistol/Bullet/pistol-shot-233473.ogg")
var reload_sound = preload("res://Weapons/Pistol/Bullet/glock-gun-reload-319593.ogg")

# Bullet scene - UPDATE THIS PATH TO YOUR ACTUAL BULLET SCENE!
var bullet_scene = preload("res://Weapons/Pistol/Bullet/Bullet.tscn")

func _ready():
	# Make sure animation tree works
	if anim_tree:
		anim_tree.active = true
		_reset_all_blends()
	
	# Connect animation finished signal
	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)

# Reset all animation blends to zero
func _reset_all_blends():
	_set_locomotion_blend(0.0)
	_set_aim_blend(0.0)
	_set_aim_shoot_blend(0.0)
	_set_shoot_blend(0.0)
	_set_reload_blend(0.0)

# --------- BLEND FUNCTIONS ---------
func set_moving(moving: bool):
	_set_locomotion_blend(1.0 if moving else 0.0)

func _set_locomotion_blend(value: float):
	if anim_tree:
		anim_tree.set("parameters/LocomotionBlend/blend_amount", value)

func _set_aim_blend(value: float):
	if anim_tree:
		anim_tree.set("parameters/AimBlend/blend_amount", value)

func _set_aim_shoot_blend(value: float):
	if anim_tree:
		anim_tree.set("parameters/AimShootBlend/blend_amount", value)

func _set_shoot_blend(value: float):
	if anim_tree:
		anim_tree.set("parameters/ShootBlend/blend_amount", value)

func _set_reload_blend(value: float):
	if anim_tree:
		anim_tree.set("parameters/ReloadBlend/blend_amount", value)

# --------- WEAPON FUNCTIONS ---------
func fire():
	if not can_fire or ammo <= 0 or is_reloading:
		print("Can't fire right now!")
		return
	
	print("Pew! Pew!")
	ammo -= 1
	can_fire = false
	
	# 1. Play shoot animation
	if is_aiming:
		_set_aim_shoot_blend(1.0)
		await get_tree().create_timer(0.1).timeout
		_set_aim_shoot_blend(0.0)
	else:
		_set_shoot_blend(1.0)
		await get_tree().create_timer(0.1).timeout
		_set_shoot_blend(0.0)
	
	# 2. SPAWN BULLET
	_spawn_bullet()
	
	# 3. PLAY SOUND
	_play_sound(shoot_sound)
	
	# 4. Wait before can fire again
	await get_tree().create_timer(fire_rate).timeout
	can_fire = true

func _spawn_bullet():
	if bullet_scene == null:
		print("No bullet scene found!")
		return
	
	if muzzle_point == null:
		print("No muzzle point found!")
		return
	
	# Create bullet instance
	var bullet = bullet_scene.instantiate()
	
	# Add bullet to the scene
	get_tree().current_scene.add_child(bullet)
	
	# Position bullet at muzzle
	bullet.global_position = muzzle_point.global_position
	bullet.global_rotation = muzzle_point.global_rotation
	
	# Setup bullet (damage and direction)
	var shoot_direction = -muzzle_point.global_transform.basis.z
	bullet.setup(damage, shoot_direction)
	
	print("Bullet spawned!")

func _play_sound(sound):
	if audio_player and sound:
		audio_player.stream = sound
		audio_player.play()

func reload():
	if is_reloading or ammo == max_ammo:
		return
	
	print("Reloading...")
	is_reloading = true
	can_fire = false
	
	# Play reload sound
	_play_sound(reload_sound)
	
	# Play reload animation
	_set_reload_blend(1.0)
	
	# Wait 2 seconds for reload
	await get_tree().create_timer(2.0).timeout
	
	# Finish reloading
	ammo = max_ammo
	is_reloading = false
	can_fire = true
	_set_reload_blend(0.0)
	print("Reload complete!")

func equip():
	print(weapon_name + " equipped!")
	visible = true
	_reset_all_blends()

func unequip():
	print(weapon_name + " unequipped!")
	visible = false

func aim(enable: bool):
	if is_reloading:
		return
	
	is_aiming = enable
	print("Aiming: " + str(enable))
	_set_aim_blend(1.0 if enable else 0.0)

func _on_animation_finished(anim_name):
	# Clean up after animations
	if anim_name == "Aim_Hold_Shoot":
		_set_aim_shoot_blend(0.0)
	elif anim_name == "Shoot":
		_set_shoot_blend(0.0)
	elif anim_name == "Reload":
		_set_reload_blend(0.0)
		ammo = max_ammo
		is_reloading = false
		can_fire = true

# Helper function to get animation length
func _get_animation_length(anim_name):
	if anim_player and anim_player.has_animation(anim_name):
		return anim_player.get_animation(anim_name).length
	return 0.3

# --------- PLAYER ASSIGNMENT ---------
# Add this function to safely assign the player
func assign_player(player_node: Node):
	player = player_node
	print("Player assigned to weapon: ", player.name)
