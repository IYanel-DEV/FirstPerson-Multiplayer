extends "res://Weapons/WeaponBase.gd"


# Pistol.gd - Update _ready function
func _ready():
	weapon_name = "Pistol"
	damage = 25
	ammo = 12
	max_ammo = 12
	fire_rate = 0.3
	weapon_scene_path = "res://Weapons/Pistol/Pistol.tscn"  # Make sure this path is correct
	
	# Debug print
	print("Pistol initialized with scene path: ", weapon_scene_path)
	
	super._ready() # Call parent's _ready
