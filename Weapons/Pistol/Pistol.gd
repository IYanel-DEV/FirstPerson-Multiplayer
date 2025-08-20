extends "res://Weapons/WeaponBase.gd"


# Pistol.gd - Update _ready function
func _ready():
	weapon_name = "Pistol"
	damage = 25
	ammo = 12
	max_ammo = 12
	fire_rate = 0.3
	
	
	super._ready() # Call parent's _ready
