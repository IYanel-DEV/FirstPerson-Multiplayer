extends Area3D
class_name Bullet

var speed: float = 40.0
var damage: int = 10
var direction: Vector3
var shooter: Node = null  # Changed from specific type to Node

func _ready():
	# Connect signals
	body_entered.connect(_on_body_entered)
	$Timer.timeout.connect(_on_timer_timeout)
	$Timer.start()

func setup(bullet_damage: int, bullet_direction: Vector3):
	damage = bullet_damage
	direction = bullet_direction

func _physics_process(delta):
	# Move bullet forward
	global_translate(direction * speed * delta)

func _on_body_entered(body):
	# Don't hit yourself or your weapon
	if body == shooter or (shooter != null and body.is_in_group("weapon")):
		return
	
	# If it's an enemy, damage it
	if body.has_method("take_damage"):
		body.take_damage(damage)
		print("Hit ", body.name, " for ", damage, " damage!")
	
	# Remove bullet
	queue_free()

func _on_timer_timeout():
	# Bullet disappears after 3 seconds if it doesn't hit anything
	queue_free()
