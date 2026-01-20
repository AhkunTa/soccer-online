class_name NetworkManager

extends Node

const SERVER_PORT := 9999
const MAX_PLAYERS := 10
const HEARTBEAT_INTERVAL := 5.0
const HEARTBEAT_TIMEOUT := 15.0
const IP_ADDRESS := ""

enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	CONNECTED_AS_SERVER,
	CONNECTED_AS_CLIENT
}

func _ready() -> void:
	# Create server.
	var server = ENetMultiplayerPeer.new()
	server.create_server(SERVER_PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = server


	# Create client.
	var client = ENetMultiplayerPeer.new()
	client.create_client(IP_ADDRESS, SERVER_PORT)
	multiplayer.multiplayer_peer = client



func offline ()-> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()