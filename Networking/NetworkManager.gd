extends Node

const PORT = 8910
const MAX_PLAYERS = 4
var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

# Signals
signal player_update_received(peer_id, position, velocity, rotation, camera_rotation)

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func host_game():
	var error = peer.create_server(PORT, MAX_PLAYERS)
	if error:
		print("Host error: ", error)
		show_connection_error()
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
	get_tree().call_group("ui", "show_error", "Connection failed. Make sure host is running.")

func load_game_world():
	if get_tree().current_scene.name != "GameMode":
		get_tree().change_scene_to_file("res://Maps/GameMode.tscn")

@rpc("any_peer", "call_local", "reliable")
func rpc_load_game_world():
	if multiplayer.is_server():
		load_game_world()

func _on_peer_connected(id):
	print("Player connected: ", id)
	if multiplayer.is_server():
		rpc_load_game_world.rpc_id(id)

func _on_peer_disconnected(id):
	print("Player disconnected: ", id)
	var game_scene = get_tree().current_scene
	if game_scene and game_scene.has_method("remove_player"):
		game_scene.remove_player(id)

func _on_connected_to_server():
	print("Successfully connected to server")
	load_game_world()

func _on_connection_failed():
	print("Connection failed")
	show_connection_error()

# Player update functions
func send_player_update(position: Vector3, velocity: Vector3, rotation: Vector3, camera_rotation: Vector3):
	if multiplayer.multiplayer_peer:
		rpc("_receive_player_update", position, velocity, rotation, camera_rotation)

@rpc("unreliable", "any_peer")
func _receive_player_update(position: Vector3, velocity: Vector3, rotation: Vector3, camera_rotation: Vector3):
	var sender_id = multiplayer.get_remote_sender_id()
	player_update_received.emit(sender_id, position, velocity, rotation, camera_rotation)
