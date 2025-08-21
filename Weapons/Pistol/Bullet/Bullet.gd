extends Area3D
class_name Bullet

var speed: float = 40.0
var damage: int = 10
var direction: Vector3
var shooter: Node = null
var lifetime: float = 3.0
var elapsed_time: float = 0.0

# Network synchronization
var network_position: Vector3
var network_direction: Vector3

func _ready():
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	# Set multiplayer authority to shooter
	if shooter and shooter.is_multiplayer_authority():
		set_multiplayer_authority(shooter.get_multiplayer_authority())
	
	# Sync initial position and direction
	if is_multiplayer_authority():
		network_position = global_position
		network_direction = direction
		rpc("_sync_bullet_data", network_position, network_direction)

func setup(bullet_damage: int, bullet_direction: Vector3, bullet_shooter: Node = null):
	damage = bullet_damage
	direction = bullet_direction.normalized()
	shooter = bullet_shooter

func _physics_process(delta):
	# Only move bullet on authority
	if is_multiplayer_authority():
		# Move bullet forward
		global_translate(direction * speed * delta)
		network_position = global_position
		
		# Sync position with clients periodically
		elapsed_time += delta
		if elapsed_time >= 0.1:  # Sync every 0.1 seconds
			elapsed_time = 0.0
			rpc("_sync_bullet_position", global_position)
		
		# Check lifetime
		lifetime -= delta
		if lifetime <= 0:
			_destroy_bullet()
	else:
		# Interpolate position on clients
		global_position = global_position.lerp(network_position, 0.3)

# Sync bullet data across network
@rpc("any_peer", "call_local")
func _sync_bullet_data(pos: Vector3, dir: Vector3):
	if not is_multiplayer_authority():
		network_position = pos
		network_direction = dir
		global_position = pos
		direction = dir

# Sync bullet position across network
@rpc("any_peer", "unreliable")
func _sync_bullet_position(pos: Vector3):
	if not is_multiplayer_authority():
		network_position = pos

func _on_body_entered(body):
	# Don't hit yourself or your weapon
	if body == shooter or (shooter != null and body.is_in_group("weapon")):
		return
	
	# Only process collisions on authority
	if not is_multiplayer_authority():
		return
	
	# If it's an enemy, damage it
	if body.has_method("take_damage"):
		body.take_damage(damage)
		print("Hit ", body.name, " for ", damage, " damage!")
	
	# Destroy bullet
	_destroy_bullet()

func _destroy_bullet():
	# Destroy on all clients
	if is_multiplayer_authority():
		rpc("_remove_bullet")
	else:
		queue_free()

@rpc("any_peer", "call_local")
func _remove_bullet():
	queue_free()
