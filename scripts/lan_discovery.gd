extends Node
class_name LanDiscovery

signal sessions_updated(sessions: Array[Dictionary])

const DISCOVERY_PORT := 28442
const BROADCAST_INTERVAL_SECONDS := 1.0
const SESSION_TTL_SECONDS := 4.5

var _listener := PacketPeerUDP.new()
var _broadcaster := PacketPeerUDP.new()
var _started := false
var _host_payload: Dictionary = {}
var _sessions: Dictionary = {}
var _local_nonce := ""
var _broadcast_timer := 0.0
var _last_signature := ""


func _ready() -> void:
	_local_nonce = "%s-%s" % [Time.get_unix_time_from_system(), randi()]
	set_process(false)


func start_discovery() -> void:
	if _started:
		return
	_started = true
	_listener.close()
	_broadcaster.close()
	_listener.set_broadcast_enabled(true)
	_broadcaster.set_broadcast_enabled(true)
	var bind_result := _listener.bind(DISCOVERY_PORT, "*")
	if bind_result != OK:
		_started = false
		return
	_broadcast_timer = 0.0
	set_process(true)


func stop_discovery() -> void:
	if not _started:
		return
	_started = false
	_listener.close()
	_broadcaster.close()
	_sessions.clear()
	_emit_sessions_if_changed(true)
	set_process(false)


func set_host_payload(payload: Dictionary) -> void:
	_host_payload = payload.duplicate(true)
	_host_payload["nonce"] = _local_nonce


func clear_host_payload() -> void:
	_host_payload.clear()


func get_sessions() -> Array[Dictionary]:
	return _build_session_array()


func _process(delta: float) -> void:
	if not _started:
		return
	_poll_packets()
	_prune_stale_sessions()
	if _host_payload.is_empty():
		return
	_broadcast_timer -= delta
	if _broadcast_timer > 0.0:
		return
	_broadcast_timer = BROADCAST_INTERVAL_SECONDS
	_broadcast_host()


func _broadcast_host() -> void:
	var payload := _host_payload.duplicate(true)
	payload["timestamp"] = Time.get_unix_time_from_system()
	var packet := JSON.stringify(payload).to_utf8_buffer()
	_broadcaster.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_broadcaster.put_packet(packet)


func _poll_packets() -> void:
	while _listener.get_available_packet_count() > 0:
		var packet := _listener.get_packet()
		if packet.is_empty():
			continue
		var parsed = JSON.parse_string(packet.get_string_from_utf8())
		if not (parsed is Dictionary):
			continue
		var payload: Dictionary = parsed
		if String(payload.get("nonce", "")) == _local_nonce:
			continue
		var address := _listener.get_packet_ip()
		var port := int(payload.get("port", 0))
		if address.is_empty() or port <= 0:
			continue
		var session_id := String(payload.get("session_id", ""))
		if session_id.is_empty():
			continue
		var entry := payload.duplicate(true)
		entry["address"] = address
		entry["last_seen_msec"] = Time.get_ticks_msec()
		_sessions[session_id] = entry
	_emit_sessions_if_changed()


func _prune_stale_sessions() -> void:
	if _sessions.is_empty():
		return
	var now := Time.get_ticks_msec()
	var stale_ids: Array[String] = []
	for session_id_variant in _sessions.keys():
		var session_id := String(session_id_variant)
		var last_seen := int((_sessions[session_id] as Dictionary).get("last_seen_msec", 0))
		if now - last_seen > int(SESSION_TTL_SECONDS * 1000.0):
			stale_ids.append(session_id)
	for session_id in stale_ids:
		_sessions.erase(session_id)
	if not stale_ids.is_empty():
		_emit_sessions_if_changed()


func _build_session_array() -> Array[Dictionary]:
	var sessions: Array[Dictionary] = []
	for session_variant in _sessions.values():
		if session_variant is Dictionary:
			sessions.append((session_variant as Dictionary).duplicate(true))
	sessions.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_players := int(a.get("player_count", 0))
			var b_players := int(b.get("player_count", 0))
			if a_players == b_players:
				return String(a.get("world_name", "")) < String(b.get("world_name", ""))
			return a_players > b_players
	)
	return sessions


func _emit_sessions_if_changed(force: bool = false) -> void:
	var sessions := _build_session_array()
	var signature := JSON.stringify(sessions)
	if not force and signature == _last_signature:
		return
	_last_signature = signature
	sessions_updated.emit(sessions)
