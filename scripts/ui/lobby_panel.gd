class_name LobbyPanel
extends PanelContainer

## Cross-Play Online-Lobby (WSS Signaling Port 443 + WebRTC TURN TCP/TLS 443 + QR-Code Beitritt).

signal back_requested
signal start_solo_bots_requested(player_name: String)
signal start_multiplayer_requested(is_host: bool, room_code: String, player_name: String)

var _edit_name: LineEdit
var _edit_signal_url: LineEdit
var _edit_room_code: LineEdit
var _lbl_status: Label
var _lbl_room_banner: Label
var _qr_rect: TextureRect
var _rooms_box: VBoxContainer


func _init() -> void:
	add_theme_stylebox_override("panel", ThemeHelper.make_slate_box(ThemeHelper.COL_BRASS, 16))
	_build_ui()


func _ready() -> void:
	NetworkManager.rooms_updated.connect(_on_rooms_updated)
	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.room_joined.connect(_on_room_joined)
	NetworkManager.connection_state_changed.connect(_on_conn_state)
	NetworkManager.error_occurred.connect(func(msg: String) -> void:
		_lbl_status.text = "Fehler: " + msg
		AudioFX.play_error()
	)


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var btn_back := Button.new()
	btn_back.text = "← Zurueck"
	ThemeHelper.style_button(btn_back)
	btn_back.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(btn_back)

	var title := Label.new()
	title.text = "Stammtisch-Lobby (Cross-Play App & Browser)"
	ThemeHelper.style_title(title, 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# Spielername & aufklappbare Technik-Details
	var row_cfg := HBoxContainer.new()
	row_cfg.add_theme_constant_override("separation", 10)
	root.add_child(row_cfg)

	var l1 := Label.new()
	l1.text = "Dein Name am Tisch:"
	ThemeHelper.style_body(l1, 16)
	row_cfg.add_child(l1)
	_edit_name = LineEdit.new()
	_edit_name.text = "Sepp"
	_edit_name.custom_minimum_size = Vector2(200, 0)
	ThemeHelper.style_line_edit(_edit_name)
	row_cfg.add_child(_edit_name)

	var spacer_cfg := Control.new()
	spacer_cfg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_cfg.add_child(spacer_cfg)

	var adv_row := HBoxContainer.new()
	adv_row.add_theme_constant_override("separation", 10)
	adv_row.visible = false

	var btn_adv := Button.new()
	btn_adv.text = "Erweitert (Server)"
	ThemeHelper.style_button(btn_adv, ThemeHelper.COL_BRASS_DIM)
	btn_adv.pressed.connect(func() -> void: adv_row.visible = not adv_row.visible)
	row_cfg.add_child(btn_adv)

	var l2 := Label.new()
	l2.text = "Signaling-Server (WSS 443):"
	ThemeHelper.style_body(l2, 14, ThemeHelper.COL_MUTED)
	adv_row.add_child(l2)
	_edit_signal_url = LineEdit.new()
	_edit_signal_url.text = "wss://doko-signal.example.com"
	_edit_signal_url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adv_row.add_child(_edit_signal_url)

	var btn_connect := Button.new()
	btn_connect.text = "Verbinden"
	ThemeHelper.style_button(btn_connect)
	btn_connect.pressed.connect(func() -> void:
		NetworkManager.connect_to_signaling(_edit_signal_url.text.strip_edges())
	)
	adv_row.add_child(btn_connect)
	root.add_child(adv_row)

	# Hauptbereich: Links Aktionen + Offene Tische | Rechts QR-Code & Raumcode
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 18)
	root.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	split.add_child(left)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	left.add_child(action_row)

	var btn_host := Button.new()
	btn_host.text = "Tisch eroeffnen (Host)"
	ThemeHelper.style_button(btn_host, ThemeHelper.COL_SUCCESS)
	btn_host.pressed.connect(func() -> void:
		NetworkManager.host_room(_edit_name.text.strip_edges(), "Kneipen-Standard")
	)
	action_row.add_child(btn_host)

	_edit_room_code = LineEdit.new()
	_edit_room_code.placeholder_text = "CODE (z.B. A7K2)"
	_edit_room_code.custom_minimum_size = Vector2(140, 0)
	ThemeHelper.style_line_edit(_edit_room_code)
	action_row.add_child(_edit_room_code)

	var btn_join := Button.new()
	btn_join.text = "Beitreten"
	ThemeHelper.style_button(btn_join)
	btn_join.pressed.connect(func() -> void:
		NetworkManager.join_room(_edit_room_code.text.strip_edges().to_upper(), _edit_name.text.strip_edges())
	)
	action_row.add_child(btn_join)

	var btn_bots := Button.new()
	btn_bots.text = "Sofort gegen 3 KI-Bots spielen"
	ThemeHelper.style_button(btn_bots, Color(0.85, 0.65, 0.25))
	btn_bots.pressed.connect(func() -> void:
		start_solo_bots_requested.emit(_edit_name.text.strip_edges())
	)
	left.add_child(btn_bots)

	var rooms_lbl := Label.new()
	rooms_lbl.text = "Offene Stammtische (Cross-Play fuer App & Browser):"
	ThemeHelper.style_body(rooms_lbl, 16, ThemeHelper.COL_BRASS)
	left.add_child(rooms_lbl)

	var rooms_panel := PanelContainer.new()
	rooms_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rooms_panel.add_theme_stylebox_override("panel", ThemeHelper.make_wood_box(10))
	left.add_child(rooms_panel)
	_rooms_box = VBoxContainer.new()
	rooms_panel.add_child(_rooms_box)

	# Rechte Spalte: QR-Code Vorschau
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(240, 0)
	right.add_theme_stylebox_override("panel", ThemeHelper.make_wood_box(12))
	split.add_child(right)
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 8)
	right.add_child(rv)

	_lbl_room_banner = Label.new()
	_lbl_room_banner.text = "Tisch-Code: ----"
	_lbl_room_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeHelper.style_title(_lbl_room_banner, 20)
	rv.add_child(_lbl_room_banner)

	_qr_rect = TextureRect.new()
	_qr_rect.custom_minimum_size = Vector2(180, 180)
	_qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_qr_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rv.add_child(_qr_rect)
	_set_qr_for_code("DEMO")

	var qr_hint := Label.new()
	qr_hint.text = "QR-Code scannen zum\nBrowser-Beitritt ohne App"
	qr_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeHelper.style_body(qr_hint, 13, ThemeHelper.COL_MUTED)
	rv.add_child(qr_hint)

	_lbl_status = Label.new()
	_lbl_status.text = "Bereit – auch im Hochschul-WLAN (eduroam) direkt spielbar"
	ThemeHelper.style_body(_lbl_status, 14, ThemeHelper.COL_MUTED)
	root.add_child(_lbl_status)


func _set_qr_for_code(code: String) -> void:
	var url := "https://doko.example.com/?room=" + code
	var tex := QRGenerator.create_texture(url, 5, 2)
	if tex != null:
		_qr_rect.texture = tex


func _on_conn_state(st: String, detail: String) -> void:
	_lbl_status.text = "Netzwerk [%s]: %s" % [st, detail]


func _on_room_created(code: String) -> void:
	_lbl_room_banner.text = "Tisch-Code: " + code
	_set_qr_for_code(code)
	start_multiplayer_requested.emit(true, code, _edit_name.text.strip_edges())


func _on_room_joined(code: String, _peer_id: int) -> void:
	_lbl_room_banner.text = "Tisch-Code: " + code
	start_multiplayer_requested.emit(false, code, _edit_name.text.strip_edges())


func _on_rooms_updated(rooms: Array) -> void:
	for c in _rooms_box.get_children():
		c.queue_free()
	if rooms.is_empty():
		var lbl := Label.new()
		lbl.text = "Noch keine offenen Tische – eroeffne einen oder spiele gegen Bots!"
		ThemeHelper.style_body(lbl, 14, ThemeHelper.COL_MUTED)
		_rooms_box.add_child(lbl)
		return
	for r in rooms:
		var btn := Button.new()
		btn.text = "Tisch %s | Host: %s (%d/%d) | %s" % [r.room_code, r.host_name, r.players, r.max_players, r.preset]
		ThemeHelper.style_button(btn)
		var code := str(r.room_code)
		btn.pressed.connect(func() -> void:
			NetworkManager.join_room(code, _edit_name.text.strip_edges())
		)
		_rooms_box.add_child(btn)
