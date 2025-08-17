extends Node3D

func _enter_tree():
	if multiplayer != null:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _ready():
	print("GameMode ready")
	
	if multiplayer != null && multiplayer.is_server():
		spawn_player(multiplayer.get_unique_id())

func _on_peer_connected(peer_id: int):
	if multiplayer.is_server():
		print("Peer connected to GameMode: ", peer_id)
		spawn_player(peer_id)

func _on_peer_disconnected(peer_id: int):
	print("Peer disconnected from GameMode: ", peer_id)
	remove_player(peer_id)

func spawn_player(peer_id: int):
	if has_node("Player_" + str(peer_id)):
		return
	
	var player_scene = load("res://Player/_Player.tscn")
	var player = player_scene.instantiate()
	
	player.name = "Player_" + str(peer_id)
	add_child(player, true)
	player.global_position = get_random_spawn_position()
	
	print("Spawned player: ", player.name)

func remove_player(peer_id: int):
	var player = get_node_or_null("Player_" + str(peer_id))
	if player:
		player.queue_free()
		print("Removed player: ", peer_id)

func get_random_spawn_position() -> Vector3:
	var spawn_points_node = get_node_or_null("SpawnPoints")
	if spawn_points_node:
		var spawn_points = spawn_points_node.get_children()
		if spawn_points.size() > 0:
			var spawn_point = spawn_points[randi() % spawn_points.size()]
			return spawn_point.global_position
	return Vector3(0, 1, 0)
