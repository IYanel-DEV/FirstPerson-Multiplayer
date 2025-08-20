# Inventory.gd
class_name Inventory
extends Node

# This makes the script globally accessible

# Signals
signal weapon_changed(weapon)
signal inventory_updated


# This makes the script globally accessible
# Inventory slots
var weapons: Array = []
var current_weapon_index: int = -1
var current_weapon: WeaponBase = null

# Inventory.gd - Update add_weapon method
func add_weapon(weapon: WeaponBase):
	print("Adding weapon to inventory: ", weapon.weapon_name)
	weapons.append(weapon)
	emit_signal("inventory_updated")
	
	# If this is our first weapon, equip it
	if current_weapon_index == -1:
		equip_weapon(0)
	
	return true  # Add this line to return success

# Equip a weapon by index
func equip_weapon(index: int):
	if index < 0 or index >= weapons.size():
		return
	
	# Unequip current weapon
	if current_weapon:
		current_weapon.unequip()
	
	# Equip new weapon
	current_weapon_index = index
	current_weapon = weapons[index]
	current_weapon.equip()
	
	emit_signal("weapon_changed", current_weapon)

# Inventory.gd - Update drop_current_weapon method
func drop_current_weapon():
	if current_weapon:
		# Store weapon info before removing
		var weapon_type = current_weapon.weapon_name
		var weapon_scene_path = current_weapon.weapon_scene_path
		
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
		
		# Return the dropped weapon info as a dictionary
		return {
			"type": weapon_type,
			"scene_path": weapon_scene_path
		}
	
	return null
