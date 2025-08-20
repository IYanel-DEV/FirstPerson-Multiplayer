# DroppedWeapon.gd
extends RigidBody3D

@export var weapon_scene: PackedScene
var weapon_name: String = ""

func _ready():
	# Enable physics
	freeze = false
	# Connect area signal
	$Area3D.body_entered.connect(_on_body_entered)
	print("Dropped weapon ready: ", weapon_name)

# DroppedWeapon.gd - Update _on_body_entered method
func _on_body_entered(body):
	print("Body entered: ", body.name)
	
	# Check if the body is a player and has authority
	if body.is_in_group("player") and body.is_multiplayer_authority():
		print("Player touched weapon: ", weapon_name)
		
		# Try to add weapon to inventory
		var weapon_instance = weapon_scene.instantiate()
		
		# Check if body has inventory directly or through a node
		var inventory = null
		if body.has_method("get_inventory"):
			inventory = body.get_inventory()
		elif body.has_node("inventory"):
			inventory = body.get_node("inventory")
		
		if inventory and inventory.has_method("add_weapon"):
			var success = inventory.add_weapon(weapon_instance)
			if success:
				print("Weapon picked up: ", weapon_name)
				queue_free()  # Remove the pickup
			else:
				print("Failed to add weapon to inventory")
				# Clean up the weapon instance if it wasn't added
				weapon_instance.queue_free()
		else:
			print("Player doesn't have a valid inventory system")
			# Clean up the weapon instance
			weapon_instance.queue_free()
# DroppedWeapon.gd - Update set_weapon_properties method
func set_weapon_properties(scene: PackedScene, name: String):
	weapon_scene = scene
	weapon_name = name
	print("Set weapon properties - Scene: ", scene, " Name: ", name)
