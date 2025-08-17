extends Node

const PORT = 8910
const MAX_PLAYERS = 4

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func host_game():
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	spawn_player(1) # Host player

func join_game(ip: String):
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer

func _on_peer_connected(id):
	print("Player connected: ", id)
	spawn_player(id)

func _on_peer_disconnected(id):
	print("Player disconnected: ", id)
	delete_player(id)

func spawn_player(id):
	var player = preload("res://Player/_Player.tscn").instantiate()
	player.name = str(id)
	get_tree().root.add_child(player)
	
	if id == multiplayer.get_unique_id():
		# This is our local player
		player.set_multiplayer_authority(id)

func delete_player(id):
	var player = get_tree().root.get_node_or_null(str(id))
	if player:
		player.queue_free()
