# Pistol.gd
extends WeaponBase

func _ready():
	weapon_name = "Pistol"
	damage = 25
	ammo = 12
	max_ammo = 12
	fire_rate = 0.3
	
	# Call parent's _ready
	super._ready()
