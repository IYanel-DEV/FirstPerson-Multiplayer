# Inventory.gd - Debug version with more logging
class_name Inventory
extends Node

# Signals
signal weapon_changed(weapon)
signal inventory_updated

# Inventory slots
var weapons: Array = []
var current_weapon_index: int = -1
var current_weapon: WeaponBase = null

# Track if we're properly in the tree
var is_fully_ready: bool = false

func _ready():
	print("Inventory _ready() called")
	# Set up multiplayer authority
	if get_parent() and get_parent().has_method("get_multiplayer_authority"):
		set_multiplayer_authority(get_parent().get_multiplayer_authority())
	
	# Use call_deferred to avoid await in _ready
	call_deferred("_initialize_after_ready")

func _initialize_after_ready():
	print("Inventory initializing after ready")
	# Mark as fully ready after a short delay
	await get_tree().create_timer(0.2).timeout
	is_fully_ready = true
	print("Inventory fully ready")



# Check if we can safely use multiplayer functions
func can_use_multiplayer() -> bool:
	return is_fully_ready and is_inside_tree() and multiplayer.has_multiplayer_peer()

func add_weapon(weapon: WeaponBase) -> bool:
	if not is_instance_valid(weapon) or not weapon is WeaponBase:
		print("Error: Tried to add an invalid or non-WeaponBase to inventory")
		return false
	
	print("Adding weapon to inventory: ", weapon.weapon_name, " Weapon instance: ", weapon)
	print("Weapon parent: ", weapon.get_parent().name if weapon.get_parent() else "None")
	print("Weapon visible: ", weapon.visible)
	
	# Ensure weapon has proper name
	if weapon.weapon_name == "Base Weapon":
		weapon.weapon_name = "Pistol"  # Set proper name
	
	weapons.append(weapon)
	emit_signal("inventory_updated")
	
	# If this is our first weapon, equip it
	if current_weapon_index == -1:
		equip_weapon(0)
	
	# Sync inventory across network if we're the authority
	if can_use_multiplayer() and is_multiplayer_authority():
		# Sync weapon with all properties
		rpc("_sync_add_weapon", weapon.weapon_name, weapon.damage, weapon.ammo, weapon.max_ammo)
	
	return true

	
	# Sync inventory across network if we're the authority
	if can_use_multiplayer() and is_multiplayer_authority():
		# Sync weapon with all properties
		rpc("_sync_add_weapon", weapon.weapon_name, weapon.damage, weapon.ammo, weapon.max_ammo)
	
	return true

@rpc("any_peer", "call_local", "reliable")
func _sync_add_weapon(weapon_name: String, damage: int, ammo: int, max_ammo: int):
	if can_use_multiplayer() and not is_multiplayer_authority():
		# Create a new weapon instance based on type
		var weapon_scene_path = "res://Weapons/Pistol/Pistol.tscn"  # Default
		if weapon_name == "Pistol":
			weapon_scene_path = "res://Weapons/Pistol/Pistol.tscn"
		# Add more weapon types here as needed
		
		var weapon_scene = load(weapon_scene_path)
		if weapon_scene == null:
			print("Failed to load weapon scene: ", weapon_scene_path)
			return
			
		var weapon_instance = weapon_scene.instantiate()
		
		# Find the WeaponBase component
		var weapon = null
		if weapon_instance is WeaponBase:
			weapon = weapon_instance
		elif weapon_instance.has_node("WeaponBase"):
			weapon = weapon_instance.get_node("WeaponBase")
		
		if not weapon:
			print("Failed to find WeaponBase in synced weapon")
			weapon_instance.queue_free()
			return
		
		# Set weapon properties from sync data
		weapon.weapon_name = weapon_name
		weapon.damage = damage
		weapon.ammo = ammo
		weapon.max_ammo = max_ammo
		
		# Add to inventory
		weapons.append(weapon)
		emit_signal("inventory_updated")
		
		# If this is our first weapon, equip it
		if current_weapon_index == -1:
			equip_weapon(0)

func equip_weapon(index: int):
	if index < 0 or index >= weapons.size():
		print("Invalid weapon index: ", index)
		return
	
	# Check if weapon is valid
	var weapon = weapons[index]
	if not is_instance_valid(weapon):
		print("Trying to equip invalid weapon at index ", index)
		return
	
	print("Equipping weapon: ", weapon.weapon_name, " Index: ", index)
	print("Weapon parent before equip: ", weapon.get_parent().name if weapon.get_parent() else "None")
	print("Weapon visible before equip: ", weapon.visible)
	
	# Unequip current weapon
	if current_weapon and is_instance_valid(current_weapon):
		current_weapon.unequip()
	
	# Equip new weapon
	current_weapon_index = index
	current_weapon = weapon
	current_weapon.equip()
	
	print("Weapon parent after equip: ", weapon.get_parent().name if weapon.get_parent() else "None")
	print("Weapon visible after equip: ", weapon.visible)
	
	emit_signal("weapon_changed", current_weapon)
	
	# Sync weapon equip across network
	if can_use_multiplayer() and is_multiplayer_authority():
		rpc("_sync_equip_weapon", index)

# Sync weapon equip across network
@rpc("any_peer", "call_local")
func _sync_equip_weapon(index: int):
	if can_use_multiplayer() and not is_multiplayer_authority():
		if index < 0 or index >= weapons.size():
			return
		
		# Check if weapon is valid
		var weapon = weapons[index]
		if not is_instance_valid(weapon):
			print("Trying to equip invalid weapon at index ", index)
			return
		
		# Unequip current weapon
		if current_weapon and is_instance_valid(current_weapon):
			current_weapon.unequip()
		
		# Equip new weapon
		current_weapon_index = index
		current_weapon = weapon
		current_weapon.equip()
		
		emit_signal("weapon_changed", current_weapon)

func drop_current_weapon():
	if current_weapon and is_instance_valid(current_weapon):
		# Store weapon info before removing
		var weapon_type = current_weapon.weapon_name
		var weapon_scene_path = "res://Weapons/Pistol/Pistol.tscn"
		
		# Debug print
		print("Dropping weapon - Type: ", weapon_type, " Path: ", weapon_scene_path)
		
		# Unequip and remove
		current_weapon.unequip()
		weapons.remove_at(current_weapon_index)
		current_weapon = null
		
		# Equip next weapon if available
		if weapons.size() > 0:
			equip_weapon(0)
		else:
			current_weapon_index = -1
		
		emit_signal("inventory_updated")
		
		# Sync weapon drop across network
		if can_use_multiplayer() and is_multiplayer_authority():
			rpc("_sync_drop_weapon", current_weapon_index)
		
		# Return the dropped weapon info as a dictionary
		return {
			"type": weapon_type,
			"scene_path": weapon_scene_path
		}
	
	return null

# Sync weapon drop across network
@rpc("any_peer", "call_local")
func _sync_drop_weapon(index: int):
	if can_use_multiplayer() and not is_multiplayer_authority():
		if index < 0 or index >= weapons.size():
			return
		
		# Unequip and remove
		if current_weapon and is_instance_valid(current_weapon) and current_weapon_index == index:
			current_weapon.unequip()
		
		weapons.remove_at(index)
		current_weapon = null
		
		# Equip next weapon if available
		if weapons.size() > 0:
			equip_weapon(0)
		else:
			current_weapon_index = -1
		
		emit_signal("inventory_updated")
