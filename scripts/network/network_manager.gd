# scripts/network/network_manager.gd
extends Node

# Signale
signal rooms_updated(rooms: Array)
signal room_created(code: String)
signal room_joined(code: String, peer_id: int)
signal peer_joined(peer_id: int, name: String)
signal peer_left(peer_id: int)
signal packet_received(from_peer: int, data: Dictionary)
signal connection_state_changed(state: String, detail: String)
signal error_occurred(msg: String)

# Konfiguration
const ICE_SERVERS = [
	{"urls": ["stun:stun.l.google.com:19302"]},
	{"urls": ["turns:openrelay.metered.ca:443?transport=tcp", "turn:openrelay.metered.ca:443?transport=tcp"], "username": "your_user", "credential": "your_password"}
]

# Variablen
var _signaling_client: WebSocketPeer = WebSocketPeer.new()
var _webrtc_peer: WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()
var _signaling_url: String = ""
var _is_connected: bool = false
var _room_code: String = ""
var _reconnect_token: String = ""
var _my_peer_id: int = 0
var _peers: Dictionary = {} # {peer_id: {"name": String, "type": "webrtc" | "relay"}}

func check_web_room_param() -> String:
	return _room_code


func _ready() -> void:
	# Web-Parameter auslesen
	if OS.has_feature("web"):
		var search = JavaScriptBridge.eval("window.location.search")
		if search and search.contains("room="):
			var regex = RegEx.create_from_string("room=([^&]+)")
			var result = regex.search(search)
			if result:
				_room_code = result.get_string(1)
				print("Auto-join from URL: ", _room_code)

func _process(_delta: float) -> void:
	if _signaling_client.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_signaling_client.poll()
		_handle_signaling_messages()

# --- Öffentliche Methoden ---

func connect_to_signaling(url: String) -> void:
	_signaling_url = url
	var err = _signaling_client.connect_to_url(url)
	if err != OK:
		error_occurred.emit("Signaling connection failed: " + str(err))
	else:
		connection_state_changed.emit("connecting", "Connecting to signaling...")

func request_room_list() -> void:
	_send_signaling({"type": "list_rooms"})

func host_room(host_name: String, preset: String) -> void:
	_send_signaling({"type": "create_room", "name": host_name, "preset": preset})

func join_room(code: String, player_name: String) -> void:
	_room_code = code
	_send_signaling({"type": "join_room", "code": code, "name": player_name})

func send_to_peer(peer_id: int, data: Dictionary) -> void:
	if _peers.has(peer_id) and _peers[peer_id].type == "webrtc":
		# WebRTC P2P
		var packet = JSON.stringify(data).to_utf8_buffer()
		_webrtc_peer.put_packet(packet) # Vereinfacht: In echter App über MultiplayerAPI
	else:
		# Fallback: Relay über Signaling
		_send_signaling({"type": "relay", "target": peer_id, "data": data})

func broadcast_packet(data: Dictionary) -> void:
	for peer_id in _peers:
		send_to_peer(peer_id, data)

func disconnect_all() -> void:
	_signaling_client.close()
	_webrtc_peer.close()
	_peers.clear()

# --- Interne Logik ---

func _send_signaling(data: Dictionary) -> void:
	if _signaling_client.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_signaling_client.send_text(JSON.stringify(data))

func _handle_signaling_messages() -> void:
	while _signaling_client.get_available_packet_count() > 0:
		var packet = _signaling_client.get_packet()
		var json = JSON.parse_string(packet.get_string_from_utf8())
		
		match json.type:
			"room_list":
				rooms_updated.emit(json.rooms)
			"room_created":
				_room_code = json.code
				_reconnect_token = json.token
				room_created.emit(json.code)
			"room_joined":
				_my_peer_id = json.peer_id
				room_joined.emit(json.code, json.peer_id)
			"offer":
				_handle_offer(json.from, json.sdp)
			"answer":
				_handle_answer(json.from, json.sdp)
			"ice":
				_handle_ice(json.from, json.sdp_mid, json.sdp_mline_index, json.sdp)
			"relay":
				packet_received.emit(json.from, json.data)
			"peer_joined":
				_add_peer(json.peer_id, json.name)
			"error":
				error_occurred.emit(json.message)

# --- WebRTC Handling ---

func _handle_offer(from_id: int, sdp: String) -> void:
	# Erstelle WebRTC Verbindung für diesen Peer
	var peer = WebRTCPeerConnection.new()
	peer.initialize({"iceServers": ICE_SERVERS})
	peer.set_remote_description("offer", sdp)
	var answer = peer.create_answer()
	peer.set_local_description("answer", answer)
	_send_signaling({"type": "answer", "to": from_id, "sdp": answer})
	_peers[from_id] = {"type": "webrtc", "connection": peer}

func _handle_answer(from_id: int, sdp: String) -> void:
	if _peers.has(from_id):
		_peers[from_id].connection.set_remote_description("answer", sdp)

func _handle_ice(from_id: int, mid: String, index: int, sdp: String) -> void:
	if _peers.has(from_id):
		_peers[from_id].connection.add_ice_candidate(mid, index, sdp)

func _add_peer(peer_id: int, name: String) -> void:
	_peers[peer_id] = {"name": name, "type": "relay"} # Default auf Relay
	peer_joined.emit(peer_id, name)
	
	# Versuche WebRTC Upgrade
	var peer = WebRTCPeerConnection.new()
	peer.initialize({"iceServers": ICE_SERVERS})
	peer.on_ice_candidate.connect(func(mid, index, sdp): 
		_send_signaling({"type": "ice", "to": peer_id, "sdp_mid": mid, "sdp_mline_index": index, "sdp": sdp})
	)
	peer.on_session_description_created.connect(func(type, sdp):
		_send_signaling({"type": "offer", "to": peer_id, "sdp": sdp})
	)
	_peers[peer_id].connection = peer
	_peers[peer_id].type = "webrtc"

# --- Reconnect Logik ---
# Wird aufgerufen, wenn WebSocket Verbindung abbricht
func _on_signaling_disconnected() -> void:
	if _room_code != "" and _reconnect_token != "":
		# Kurze Verzögerung für Reconnect
		await get_tree().create_timer(2.0).timeout
		connect_to_signaling(_signaling_url)
		_send_signaling({"type": "reconnect", "code": _room_code, "token": _reconnect_token})
