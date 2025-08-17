extends Node3D

func _ready():
	# Spawn players after the scene is loaded
	NetworkManager.spawn_all_players()
	
	# Add spawn points
	var spawn_points = $SpawnPoints.get_children()
	for player in get_tree().get_nodes_in_group("player"):
		if spawn_points.size() > 0:
			var spawn_point = spawn_points[randi() % spawn_points.size()]
			player.global_position = spawn_point.global_position
