extends Control

## Haupt-Controller fuer "Uriges Doppelkopf".
## Verbindet Hauptmenue, P2P-/Bot-Kartentisch, Online-Lobby, Schreibblock und Regel-Werkstatt.

enum Screen { MENU, TABLE, LOBBY, SCHREIBBLOCK }

var _current_screen: Screen = Screen.MENU
var _engine: DokoEngine = DokoEngine.new()
var _rules: RuleConfig = RuleConfig.preset("Kneipen-Standard")
var _local_seat: int = 0
var _human_seats: Array[int] = [0]
var _player_names: Array[String] = ["Sepp", "Wirtin Resi", "Bauer Hias", "Liesl"]
var _dealer_idx: int = 0
var _bock_mult: int = 1
var _bot_timer: Timer

# Root-Container
var _bg_tex: TextureRect
var _menu_view: Control
var _table_view: Control
var _lobby_panel: LobbyPanel
var _schreibblock_panel: SchreibblockPanel
var _rules_dialog: RulesDialog

# Table UI
var _seat_badges: Array[PanelContainer] = []
var _seat_labels: Array[Label] = []
var _trick_slots: Array[Control] = [] # 0=Unten(Du), 1=Links, 2=Oben, 3=Rechts
var _hand_fan: HandFan
var _lbl_table_info: Label
var _toast_panel: PanelContainer
var _lbl_toast: Label
var _vorbehalt_overlay: PanelContainer
var _round_end_overlay: PanelContainer
var _lbl_round_summary: Label
var _btn_re: Button
var _btn_kontra: Button
var _btn_no90: Button
var _btn_knock: Button


func _ready() -> void:
	_build_root_ui()
	_bot_timer = Timer.new()
	_bot_timer.one_shot = true
	_bot_timer.wait_time = 0.55
	_bot_timer.timeout.connect(_on_bot_step)
	add_child(_bot_timer)

	# Auto-Join falls ?room=XXXX im Browser uebergeben wurde
	var pending_room: String = NetworkManager.check_web_room_param()
	if pending_room != "":
		_switch_screen(Screen.LOBBY)
		_lobby_panel._edit_room_code.text = pending_room
	else:
		_switch_screen(Screen.MENU)

	if OS.get_cmdline_user_args().has("--capture-screenshots"):
		call_deferred("_run_screenshot_capture")


func _run_screenshot_capture() -> void:
	var modes := ["menu", "table", "rules", "lobby", "schreibblock"]
	for m in modes:
		show_preview(m)
		for _i in range(6):
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(".scratch/screenshots/%s.png" % m)
		print("CAPTURED_CLEAN: ", m)
	get_tree().quit(0)


func _build_root_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_bg_tex = TextureRect.new()
	_bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/ui/oak_table_bg.png"):
		_bg_tex.texture = ResourceLoader.load("res://assets/ui/oak_table_bg.png")
	add_child(_bg_tex)

	_build_menu_view()
	_build_table_view()

	_lobby_panel = LobbyPanel.new()
	_lobby_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lobby_panel.offset_left = 40
	_lobby_panel.offset_right = -40
	_lobby_panel.offset_top = 30
	_lobby_panel.offset_bottom = -30
	_lobby_panel.back_requested.connect(func() -> void: _switch_screen(Screen.MENU))
	_lobby_panel.start_solo_bots_requested.connect(func(pname: String) -> void:
		if pname != "":
			_player_names[0] = pname
		_start_local_bot_game()
	)
	_lobby_panel.start_multiplayer_requested.connect(func(is_host: bool, _code: String, pname: String) -> void:
		if pname != "":
			_player_names[0] = pname
		if is_host:
			_start_local_bot_game()
	)
	add_child(_lobby_panel)

	_schreibblock_panel = SchreibblockPanel.new()
	_schreibblock_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_schreibblock_panel.offset_left = 36
	_schreibblock_panel.offset_right = -36
	_schreibblock_panel.offset_top = 24
	_schreibblock_panel.offset_bottom = -24
	_schreibblock_panel.back_requested.connect(func() -> void: _switch_screen(Screen.MENU))
	add_child(_schreibblock_panel)

	_rules_dialog = RulesDialog.new()
	_rules_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_rules_dialog.offset_left = -390
	_rules_dialog.offset_right = 390
	_rules_dialog.offset_top = -260
	_rules_dialog.offset_bottom = 260
	_rules_dialog.visible = false
	_rules_dialog.rules_applied.connect(func(r: RuleConfig) -> void:
		_rules = r
		_show_toast("Regel-Preset '%s' gespeichert!" % r.preset_name)
	)
	add_child(_rules_dialog)


func _build_menu_view() -> void:
	_menu_view = CenterContainer.new()
	_menu_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu_view)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ThemeHelper.make_slate_box(ThemeHelper.COL_BRASS, 20))
	card.custom_minimum_size = Vector2(560, 440)
	_menu_view.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "URIGES DOPPELKOPF"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeHelper.style_title(title, 34)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Stammtisch-Edition · App & Browser Cross-Play · Schreibblock"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeHelper.style_body(sub, 16, ThemeHelper.COL_MUTED)
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var btn_play := Button.new()
	btn_play.text = "Sofort spielen (Stammtisch mit 3 KI-Bots)"
	btn_play.custom_minimum_size = Vector2(420, 50)
	ThemeHelper.style_button(btn_play, ThemeHelper.COL_SUCCESS, Color(0.10, 0.25, 0.16, 0.96))
	btn_play.pressed.connect(_start_local_bot_game)
	vbox.add_child(btn_play)

	var btn_online := Button.new()
	btn_online.text = "Online-Lobby & Cross-Play (QR-Code / WSS + TURN)"
	btn_online.custom_minimum_size = Vector2(420, 48)
	ThemeHelper.style_button(btn_online)
	btn_online.pressed.connect(func() -> void: _switch_screen(Screen.LOBBY))
	vbox.add_child(btn_online)

	var btn_block := Button.new()
	btn_block.text = "Digitaler Schreibblock & Statistik-Tracker"
	btn_block.custom_minimum_size = Vector2(420, 48)
	ThemeHelper.style_button(btn_block)
	btn_block.pressed.connect(func() -> void:
		_schreibblock_panel.refresh_all()
		_switch_screen(Screen.SCHREIBBLOCK)
	)
	vbox.add_child(btn_block)

	var btn_rules := Button.new()
	btn_rules.text = "Regel-Werkstatt (Presets & Sonderregeln)"
	btn_rules.custom_minimum_size = Vector2(420, 46)
	ThemeHelper.style_button(btn_rules, ThemeHelper.COL_BRASS_DIM)
	btn_rules.pressed.connect(func() -> void: _rules_dialog.visible = true)
	vbox.add_child(btn_rules)


func _build_table_view() -> void:
	_table_view = Control.new()
	_table_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_table_view)

	# Obere Info-Leiste
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 16
	top_bar.offset_right = -16
	top_bar.offset_top = 10
	top_bar.offset_bottom = 52
	top_bar.add_theme_constant_override("separation", 10)
	_table_view.add_child(top_bar)

	var btn_menu := Button.new()
	btn_menu.text = "Menue"
	ThemeHelper.style_button(btn_menu)
	btn_menu.pressed.connect(func() -> void:
		_bot_timer.stop()
		_switch_screen(Screen.MENU)
	)
	top_bar.add_child(btn_menu)

	var info_pill := PanelContainer.new()
	info_pill.add_theme_stylebox_override("panel", ThemeHelper.make_slate_box(ThemeHelper.COL_BRASS_DIM, 10))
	info_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(info_pill)

	_lbl_table_info = Label.new()
	ThemeHelper.style_body(_lbl_table_info, 17, ThemeHelper.COL_CREAM)
	info_pill.add_child(_lbl_table_info)

	_btn_knock = Button.new()
	_btn_knock.text = "Klopfen (Bock)"
	ThemeHelper.style_button(_btn_knock, Color(0.92, 0.56, 0.22))
	_btn_knock.pressed.connect(func() -> void:
		AudioFX.play_knock()
		_play_knock_shake_fx()
		SchreibblockStore.trigger_manual_bock(1)
		_show_toast("Auf den Tisch geklopft – naechste Runde Bock!")
	)
	top_bar.add_child(_btn_knock)

	var btn_block := Button.new()
	btn_block.text = "Schreibblock"
	ThemeHelper.style_button(btn_block)
	btn_block.pressed.connect(func() -> void:
		_schreibblock_panel.refresh_all()
		_switch_screen(Screen.SCHREIBBLOCK)
	)
	top_bar.add_child(btn_block)

	# 4 Spieler-Badges (0=Unten/Du, 1=Links, 2=Oben, 3=Rechts)
	_seat_badges.clear()
	_seat_labels.clear()
	var badge_anchors := [
		Vector2(0.11, 0.59), # Unten/Du klar ueber dem HandFan
		Vector2(0.09, 0.35), # Links
		Vector2(0.50, 0.09), # Oben (klar ueber der Stichkarte)
		Vector2(0.91, 0.35), # Rechts
	]
	for i in range(4):
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", ThemeHelper.make_slate_box(ThemeHelper.COL_BRASS_DIM, 10))
		p.anchor_left = badge_anchors[i].x
		p.anchor_right = badge_anchors[i].x
		p.anchor_top = badge_anchors[i].y
		p.anchor_bottom = badge_anchors[i].y
		p.offset_left = -114
		p.offset_right = 114
		p.offset_top = -30
		p.offset_bottom = 30
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ThemeHelper.style_body(lbl, 17)
		p.add_child(lbl)
		_table_view.add_child(p)
		_seat_badges.append(p)
		_seat_labels.append(lbl)

	# Stich-Mitte (4 Bierdeckel-Slots ohne Ueberlappung)
	_trick_slots.clear()
	var coaster_tex: Texture2D = ResourceLoader.load("res://assets/ui/coaster_slot.png") if ResourceLoader.exists("res://assets/ui/coaster_slot.png") else null
	var slot_offsets := [
		Vector2(-62, 24),   # Unten
		Vector2(-235, -75), # Links
		Vector2(-62, -168), # Oben
		Vector2(114, -75),  # Rechts
	]
	for i in range(4):
		var slot := Control.new()
		slot.anchor_left = 0.5
		slot.anchor_right = 0.5
		slot.anchor_top = 0.44
		slot.anchor_bottom = 0.44
		slot.offset_left = slot_offsets[i].x
		slot.offset_top = slot_offsets[i].y
		slot.custom_minimum_size = Vector2(116, 168)
		if coaster_tex != null:
			var bg := TextureRect.new()
			bg.texture = coaster_tex
			bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(bg)
		_table_view.add_child(slot)
		_trick_slots.append(slot)

	# Ereignis-Toast als uriges Holzschild
	_toast_panel = PanelContainer.new()
	_toast_panel.add_theme_stylebox_override("panel", ThemeHelper.make_wood_box(12))
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 0.21
	_toast_panel.anchor_bottom = 0.21
	_toast_panel.offset_left = -220
	_toast_panel.offset_right = 220
	_toast_panel.offset_top = -20
	_toast_panel.offset_bottom = 22
	_toast_panel.visible = false
	_table_view.add_child(_toast_panel)

	_lbl_toast = Label.new()
	_lbl_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeHelper.style_title(_lbl_toast, 19, Color(0.98, 0.82, 0.35))
	_toast_panel.add_child(_lbl_toast)

	# Ansage-Leiste daumenfreundlich direkt ueber der rechten HandFan-Seite
	var call_bar := HBoxContainer.new()
	call_bar.anchor_left = 0.71
	call_bar.anchor_right = 0.97
	call_bar.anchor_top = 0.60
	call_bar.anchor_bottom = 0.67
	call_bar.alignment = BoxContainer.ALIGNMENT_END
	call_bar.add_theme_constant_override("separation", 8)
	_table_view.add_child(call_bar)

	_btn_re = Button.new()
	_btn_re.text = "Re!"
	_btn_re.custom_minimum_size = Vector2(108, 44)
	ThemeHelper.style_button(_btn_re)
	_btn_re.pressed.connect(func() -> void: _try_announce("re"))
	call_bar.add_child(_btn_re)

	_btn_kontra = Button.new()
	_btn_kontra.text = "Kontra!"
	_btn_kontra.custom_minimum_size = Vector2(112, 44)
	ThemeHelper.style_button(_btn_kontra)
	_btn_kontra.pressed.connect(func() -> void: _try_announce("kontra"))
	call_bar.add_child(_btn_kontra)

	_btn_no90 = Button.new()
	_btn_no90.text = "Keine 90"
	_btn_no90.custom_minimum_size = Vector2(118, 44)
	ThemeHelper.style_button(_btn_no90)
	_btn_no90.pressed.connect(func() -> void: _try_announce("no90"))
	call_bar.add_child(_btn_no90)

	# Kartenfaecher unten (mit Safe-Area-Abstand fuer Mobile Home-Bar)
	_hand_fan = HandFan.new()
	_hand_fan.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hand_fan.offset_top = -212
	_hand_fan.offset_bottom = -24
	_hand_fan.card_played.connect(_on_local_card_played)
	_table_view.add_child(_hand_fan)

	# Vorbehalt-Overlay (im oberen Tischbereich, damit der eigene HandFan voll sichtbar bleibt!)
	_vorbehalt_overlay = PanelContainer.new()
	_vorbehalt_overlay.add_theme_stylebox_override("panel", ThemeHelper.make_slate_box(ThemeHelper.COL_BRASS, 16))
	_vorbehalt_overlay.anchor_left = 0.5
	_vorbehalt_overlay.anchor_right = 0.5
	_vorbehalt_overlay.anchor_top = 0.32
	_vorbehalt_overlay.anchor_bottom = 0.32
	_vorbehalt_overlay.offset_left = -260
	_vorbehalt_overlay.offset_right = 260
	_vorbehalt_overlay.offset_top = -95
	_vorbehalt_overlay.offset_bottom = 95
	_vorbehalt_overlay.visible = false
	_table_view.add_child(_vorbehalt_overlay)

	var vv := VBoxContainer.new()
	vv.alignment = BoxContainer.ALIGNMENT_CENTER
	vv.add_theme_constant_override("separation", 10)
	_vorbehalt_overlay.add_child(vv)
	var vl := Label.new()
	vl.text = "Vorbehalt / Spielansage"
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeHelper.style_title(vl, 22)
	vv.add_child(vl)

	var vbtns := HBoxContainer.new()
	vbtns.alignment = BoxContainer.ALIGNMENT_CENTER
	vbtns.add_theme_constant_override("separation", 10)
	vv.add_child(vbtns)
	for pair in [["✓ Gesund", "gesund"], ["♥ Hochzeit", "hochzeit"], ["♛ Damensolo", "solo_damen"], ["♞ Bubensolo", "solo_buben"]]:
		var b := Button.new()
		b.text = pair[0]
		ThemeHelper.style_button(b)
		var tag: String = pair[1]
		b.pressed.connect(func() -> void: _on_vorbehalt_chosen(tag))
		vbtns.add_child(b)

	# Rundenende-Overlay
	_round_end_overlay = PanelContainer.new()
	_round_end_overlay.add_theme_stylebox_override("panel", ThemeHelper.make_slate_box(ThemeHelper.COL_BRASS, 16))
	_round_end_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_round_end_overlay.offset_left = -260
	_round_end_overlay.offset_right = 260
	_round_end_overlay.offset_top = -170
	_round_end_overlay.offset_bottom = 170
	_round_end_overlay.visible = false
	_table_view.add_child(_round_end_overlay)

	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 12)
	_round_end_overlay.add_child(rv)
	var rtitle := Label.new()
	rtitle.text = "Runden-Abrechnung"
	rtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeHelper.style_title(rtitle, 24)
	rv.add_child(rtitle)

	_lbl_round_summary = Label.new()
	_lbl_round_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeHelper.style_body(_lbl_round_summary, 16)
	rv.add_child(_lbl_round_summary)

	var btn_next := Button.new()
	btn_next.text = "Naechste Runde geben"
	ThemeHelper.style_button(btn_next, ThemeHelper.COL_SUCCESS)
	btn_next.pressed.connect(func() -> void:
		_dealer_idx = (_dealer_idx + 1) % _player_names.size()
		_start_new_round()
	)
	rv.add_child(btn_next)


func _switch_screen(s: Screen) -> void:
	_current_screen = s
	_menu_view.visible = (s == Screen.MENU)
	_table_view.visible = (s == Screen.TABLE)
	_lobby_panel.visible = (s == Screen.LOBBY)
	_schreibblock_panel.visible = (s == Screen.SCHREIBBLOCK)


func _start_local_bot_game() -> void:
	_switch_screen(Screen.TABLE)
	if SchreibblockStore.get_active_session().is_empty():
		SchreibblockStore.create_session("Stammtisch-Live", _player_names, 5.0)
	_start_new_round()


func _start_new_round() -> void:
	_round_end_overlay.visible = false
	_engine.start_round(_player_names, _dealer_idx, _rules, _bock_mult)
	AudioFX.play_deal()
	_refresh_table_ui()
	_schedule_bot_if_needed()


func _refresh_table_ui() -> void:
	var st := _engine.build_state_for_seat(_local_seat)
	var solo_str := "Normalspiel" if st.solo_kind == "" else ("Solo: " + str(st.solo_kind).capitalize())
	_lbl_table_info.text = "Stich %d/%d  |  %s  |  Bock x%d  |  Preset: %s" % [
		int(st.trick_count) + 1,
		int(st.total_tricks),
		solo_str,
		int(st.bock_multiplier),
		_rules.preset_name,
	]

	for rel in range(4):
		var seat := (_local_seat + rel) % 4
		var is_turn: bool = (st.phase == DokoEngine.Phase.PLAYING and int(st.current_turn) == seat)
		var tag := " (Du)" if seat == _local_seat else ""
		var dealer_mark := "  [GEBER]" if seat == int(st.dealer_index) else ""
		var ann_tag := ""
		if _engine.re_seats.has(seat) and st.announcements.get("re", false):
			ann_tag = " [RE]"
		elif not _engine.re_seats.has(seat) and st.announcements.get("kontra", false):
			ann_tag = " [KONTRA]"
		_seat_labels[rel].text = "%s%s%s%s\n%d Karten" % [
			_player_names[seat],
			tag,
			dealer_mark,
			ann_tag,
			int(st.hand_counts.get(seat, 0)),
		]
		if is_turn:
			var active_box := ThemeHelper.make_wood_box(10)
			active_box.bg_color = Color(0.28, 0.21, 0.08, 0.96)
			_seat_badges[rel].add_theme_stylebox_override("panel", active_box)
		else:
			_seat_badges[rel].add_theme_stylebox_override("panel", ThemeHelper.make_slate_box(ThemeHelper.COL_BRASS_DIM, 10))

	# Stich-Karten zeichnen (nur CardViews entfernen, Bierdeckel behalten!)
	for slot in _trick_slots:
		for c in slot.get_children():
			if c is CardView:
				c.queue_free()
	for entry in st.trick_cards:
		var rel := (int(entry.seat) - _local_seat + 4) % 4
		var cd := CardData.from_dict(entry.card)
		var cv := CardView.new()
		cv.setup(cd, true, _engine.is_trump(cd), true)
		cv.position = Vector2(3, 4)
		cv.rotation = float((rel * 17) % 5 - 2) * 0.025
		cv.scale = Vector2(1.16, 1.16)
		_trick_slots[rel].add_child(cv)

	# Kontextuelle Ansage-Buttons
	var hand_sz: int = st.my_hand.size()
	var is_re := _engine.re_seats.has(_local_seat)
	_btn_re.visible = (st.phase == DokoEngine.Phase.PLAYING and is_re and not st.announcements.get("re", false) and hand_sz >= int(st.total_tricks) - 1)
	_btn_kontra.visible = (st.phase == DokoEngine.Phase.PLAYING and not is_re and not st.announcements.get("kontra", false) and hand_sz >= int(st.total_tricks) - 1)
	_btn_no90.visible = (st.phase == DokoEngine.Phase.PLAYING and hand_sz >= int(st.total_tricks) - 2)

	var my_turn: bool = (st.phase == DokoEngine.Phase.PLAYING and int(st.current_turn) == _local_seat)
	_hand_fan.set_hand(st.my_hand, st.legal_ids, _engine, my_turn)

	_vorbehalt_overlay.visible = (st.phase == DokoEngine.Phase.VORBEHALT and not _engine.declarations.has(_local_seat))

	if st.phase == DokoEngine.Phase.ROUND_END:
		_show_round_end(st.last_round_result)


func _on_vorbehalt_chosen(tag: String) -> void:
	AudioFX.play_bid()
	if tag.begins_with("solo_"):
		_engine.declare_vorbehalt(_local_seat, "solo", tag.replace("solo_", ""))
	else:
		_engine.declare_vorbehalt(_local_seat, tag)
	_refresh_table_ui()
	_schedule_bot_if_needed()


func _try_announce(kind: String) -> void:
	if _engine.make_announcement(_local_seat, kind):
		AudioFX.play_bid()
		_show_toast(kind.to_upper() + " angesagt!")
		_refresh_table_ui()
	else:
		AudioFX.play_error()


func _on_local_card_played(card_id: String) -> void:
	var res := _engine.play_card(_local_seat, card_id)
	if res.has("error"):
		AudioFX.play_error()
		_show_toast(str(res.error))
		return
	AudioFX.play_card()
	_play_table_slam_fx()
	if res.get("status", "") == "trick_complete":
		AudioFX.play_trick_win()
		_animate_trick_collect(int(res.trick_winner))
		_show_toast("%s sticht (%d Augen)!" % [_player_names[int(res.trick_winner)], int(res.trick_points)])
	_refresh_table_ui()
	_schedule_bot_if_needed()


func _schedule_bot_if_needed() -> void:
	if _engine.phase == DokoEngine.Phase.VORBEHALT:
		if _engine.declarations.has(_local_seat):
			_bot_timer.start()
	elif _engine.phase == DokoEngine.Phase.PLAYING:
		if _engine.current_turn != _local_seat:
			_bot_timer.start()


func _on_bot_step() -> void:
	if _engine.phase == DokoEngine.Phase.VORBEHALT:
		for s in range(4):
			if not _engine.declarations.has(s) and s != _local_seat:
				var vb := DokoBot.choose_vorbehalt(_engine, s)
				_engine.declare_vorbehalt(s, vb.choice, vb.solo_kind)
		_refresh_table_ui()
		_schedule_bot_if_needed()
		return

	if _engine.phase == DokoEngine.Phase.PLAYING and _engine.current_turn != _local_seat:
		var s := _engine.current_turn
		var ann := DokoBot.maybe_make_announcement(_engine, s)
		if ann != "":
			_engine.make_announcement(s, ann)
			_show_toast("%s sagt %s!" % [_player_names[s], ann.to_upper()])
		var cid := DokoBot.choose_card(_engine, s)
		if cid != "":
			var res := _engine.play_card(s, cid)
			AudioFX.play_card()
			if res.get("status", "") == "trick_complete":
				AudioFX.play_trick_win()
		_refresh_table_ui()
		_schedule_bot_if_needed()


func _show_round_end(res: Dictionary) -> void:
	_round_end_overlay.visible = true
	var bd: Array = res.get("breakdown", [])
	_lbl_round_summary.text = "Sieger: %s  (%d Punkte)\nRe: %d Augen  |  Kontra: %d Augen\n\n%s" % [
		str(res.get("winner_side", "draw")).to_upper(),
		int(res.get("total_points", 0)),
		int(res.get("re_points", 0)),
		int(res.get("kontra_points", 0)),
		"\n".join(bd.slice(0, 6)),
	]
	# Automatisch in Schreibblock-Tracker uebernehmen
	var re_names: Array[String] = []
	var kontra_names: Array[String] = []
	for s in res.get("re_seats", []):
		re_names.append(_player_names[int(s)])
	for s in res.get("kontra_seats", []):
		kontra_names.append(_player_names[int(s)])
	SchreibblockStore.add_live_round({
		"winner_side": res.get("winner_side", "draw"),
		"points": int(res.get("total_points", 0)),
		"re_players": re_names,
		"kontra_players": kontra_names,
		"is_solo": res.get("is_solo", false),
		"solo_player": _player_names[int(res.get("solo_seat", 0))] if res.get("is_solo", false) else "",
	}, _player_names)


func _play_table_slam_fx() -> void:
	var tw := create_tween()
	tw.tween_property(_table_view, "position", Vector2(0, 3), 0.04)
	tw.tween_property(_table_view, "position", Vector2.ZERO, 0.08)


func _play_knock_shake_fx() -> void:
	var tw := create_tween()
	tw.tween_property(_table_view, "position", Vector2(-12, 10), 0.04)
	tw.tween_property(_table_view, "position", Vector2(12, -10), 0.04)
	tw.tween_property(_table_view, "position", Vector2(-8, -6), 0.04)
	tw.tween_property(_table_view, "position", Vector2(8, 6), 0.04)
	tw.tween_property(_table_view, "position", Vector2.ZERO, 0.06)


func _animate_trick_collect(winner_seat: int) -> void:
	var rel := (winner_seat - _local_seat + 4) % 4
	if rel < 0 or rel >= _seat_badges.size():
		return
	var badge := _seat_badges[rel]
	var btw := create_tween()
	btw.tween_property(badge, "scale", Vector2(1.14, 1.14), 0.12)
	btw.tween_property(badge, "scale", Vector2.ONE, 0.18)
	var center_pos := _table_view.size * 0.5 - CardView.BASE_SIZE * 0.5
	var target_pos := badge.global_position
	for slot in _trick_slots:
		for c in slot.get_children():
			if c is CardView:
				var tw := create_tween()
				tw.tween_property(c, "global_position", center_pos, 0.12).set_trans(Tween.TRANS_QUAD)
				tw.tween_property(c, "global_position", target_pos, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(c, "rotation", 0.45, 0.24)
				tw.parallel().tween_property(c, "modulate:a", 0.0, 0.24)


func _show_toast(msg: String) -> void:
	_lbl_toast.text = msg
	_toast_panel.visible = true
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func() -> void: _toast_panel.visible = false)


## Fuer automatische Screenshot-Captures (Phase 6 Critic-Loop)
func show_preview(mode: String) -> void:
	_rules_dialog.visible = false
	_round_end_overlay.visible = false
	_vorbehalt_overlay.visible = false
	match mode:
		"menu":
			_switch_screen(Screen.MENU)
		"table":
			_start_local_bot_game()
			# Vorbehalt ueberspringen & 3 Karten in die Mitte legen fuer realistischen Tisch-Screenshot
			for s in range(4):
				_engine.declare_vorbehalt(s, "gesund")
			for _k in range(3):
				var t := _engine.current_turn
				if t == _local_seat:
					break
				_engine.play_card(t, DokoBot.choose_card(_engine, t))
			_refresh_table_ui()
		"rules":
			_switch_screen(Screen.MENU)
			_rules_dialog.visible = true
		"lobby":
			_switch_screen(Screen.LOBBY)
		"schreibblock":
			if SchreibblockStore.get_active_session().get("rounds", []).is_empty():
				SchreibblockStore.add_manual_round({"winner_side": "re", "points": 3, "re_players": ["Anna", "Ben"], "kontra_players": ["Clara", "Dieter"]})
				SchreibblockStore.add_manual_round({"winner_side": "kontra", "points": 4, "re_players": ["Anna", "Clara"], "kontra_players": ["Ben", "Dieter"]})
				SchreibblockStore.add_manual_round({"winner_side": "re", "points": 2, "re_players": ["Ben", "Dieter"], "kontra_players": ["Anna", "Clara"]})
			_schreibblock_panel.refresh_all()
			_switch_screen(Screen.SCHREIBBLOCK)
