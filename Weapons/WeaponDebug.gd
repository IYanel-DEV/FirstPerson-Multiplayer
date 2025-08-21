# WeaponDebug.gd - Debug script to check weapon visibility
extends Node

@onready var player: Node = get_parent()

func _process(_delta):
	if Engine.get_frames_drawn() % 60 == 0 and player.is_multiplayer_authority():
		print("=== WEAPON DEBUG ===")
		
		# Check inventory
		if player.has_method("get_inventory"):
			var inventory = player.get_inventory()
			if inventory:
				print("Inventory weapons: ", inventory.weapons.size())
				print("Current weapon: ", inventory.current_weapon)
				if inventory.current_weapon:
					var weapon = inventory.current_weapon
					print("Weapon name: ", weapon.weapon_name)
					print("Weapon visible: ", weapon.visible)
					print("Weapon parent: ", weapon.get_parent().name if weapon.get_parent() else "None")
					print("Weapon global position: ", weapon.global_position)
		
		# Check weapon socket
		var weapon_socket = player.get_node_or_null("Camera3D/HeadPosition/WeaponSocket")
		if weapon_socket:
			print("Weapon socket children: ", weapon_socket.get_children().size())
			for child in weapon_socket.get_children():
				print("  - ", child.name, " Type: ", child.get_class(), " Visible: ", child.visible)
		
		print("====================")
