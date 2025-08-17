extends Node

const PORT = 8910
const MAX_PLAYERS = 4
var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func host_game():
	var error = peer.create_server(PORT, MAX_PLAYERS)
	if error:
		print("Host error: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	print("Hosting game on port ", PORT)
	load_game_world()
	return true

func join_game(ip: String = "localhost"):
	var error = peer.create_client(ip, PORT)
	if error:
		print("Join error: ", error)
		show_connection_error()
		return false
		
	multiplayer.multiplayer_peer = peer
	print("Joining game at ", ip)
	return true

func show_connection_error():
	print("Failed to connect to server")
	# Show error message in UI
	get_tree().call_group("ui", "show_error", "Connection failed. Make sure host is running.")

func load_game_world():
	get_tree().change_scene_to_file("res://Maps/GameMode.tscn")

# This will be called by the GameMode scene after it's loaded
func spawn_all_players():
	for id in multiplayer.get_peers():
		spawn_player(id)
	spawn_player(multiplayer.get_unique_id())

func _on_peer_connected(id):
	print("Player connected: ", id)
	# Wait for the game world to spawn players
	if get_tree().current_scene.name == "GameMode":
		spawn_player(id)

func _on_peer_disconnected(id):
	print("Player disconnected: ", id)
	delete_player(id)

func _on_connected_to_server():
	print("Successfully connected to server")
	# Players will be spawned by the GameMode scene

func _on_connection_failed():
	print("Connection failed")
	show_connection_error()

func spawn_player(id):
	var player = preload("res://Player/_Player.tscn").instantiate()
	player.name = str(id)
	
	# Add player to the current scene
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.name == "GameMode":
		current_scene.add_child(player)
	else:
		get_tree().root.add_child(player)
	
	if id == multiplayer.get_unique_id():
		player.set_multiplayer_authority(id)

func delete_player(id):
	var player = get_tree().root.get_node_or_null(str(id))
	if player:
		player.queue_free()
