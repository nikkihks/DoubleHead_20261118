class_name SchreibblockPanel
extends PanelContainer

## Physischer & Digitaler Doppelkopf-Schreibblock-Tracker:
## Schnelle Punkte-Eingabe, Bockrunden-Vorschau, Verlauf, Liniendiagramm & Kassen-Abrechnung.

signal back_requested

var _lbl_session_info: Label
var _lbl_bock_banner: Label
var _tab_container: TabContainer
var _history_list: VBoxContainer
var _chart: PointsChart
var _stats_box: VBoxContainer

# Schnelleingabe Controls
var _winner_side: String = "re"
var _btn_win_re: Button
var _btn_win_kontra: Button
var _btn_win_draw: Button
var _points_val: int = 2
var _lbl_points_val: Label
var _history_grid: GridContainer
var _chk_solo: CheckBox
var _opt_solo_player: OptionButton
var _chk_fuchs: CheckBox
var _chk_karlchen: CheckBox
var _chk_doko: CheckBox
var _chk_re_ansage: CheckBox
var _chk_kontra_ansage: CheckBox
var _re_toggles: Array[Button] = []


func _init() -> void:
	add_theme_stylebox_override("panel", ThemeHelper.make_slate_box(ThemeHelper.COL_BRASS, 16))
	_build_ui()


func _ready() -> void:
	if SchreibblockStore.get_active_session().is_empty():
		var default_players: Array[String] = ["Anna", "Ben", "Clara", "Dieter"]
		SchreibblockStore.create_session("Stammtisch-Abend", default_players, 5.0)
	refresh_all()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# Kopfzeile
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var btn_back := Button.new()
	btn_back.text = "← Zurueck"
	ThemeHelper.style_button(btn_back)
	btn_back.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(btn_back)

	var title := Label.new()
	title.text = "Doppelkopf Schreibblock"
	ThemeHelper.style_title(title, 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var btn_knock := Button.new()
	btn_knock.text = "Klopfen (+Bock)"
	ThemeHelper.style_button(btn_knock, Color(0.92, 0.56, 0.22))
	btn_knock.pressed.connect(func() -> void:
		AudioFX.play_knock()
		SchreibblockStore.trigger_manual_bock(1)
		refresh_all()
	)
	header.add_child(btn_knock)

	var btn_undo := Button.new()
	btn_undo.text = "Undo"
	ThemeHelper.style_button(btn_undo, ThemeHelper.COL_DANGER)
	btn_undo.pressed.connect(func() -> void:
		SchreibblockStore.undo_last_round()
		refresh_all()
	)
	header.add_child(btn_undo)

	# Session- & Bock-Statusleiste
	var info_bar := HBoxContainer.new()
	root.add_child(info_bar)
	_lbl_session_info = Label.new()
	_lbl_session_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeHelper.style_body(_lbl_session_info, 16, ThemeHelper.COL_CREAM)
	info_bar.add_child(_lbl_session_info)

	_lbl_bock_banner = Label.new()
	ThemeHelper.style_body(_lbl_bock_banner, 16, Color(0.96, 0.72, 0.25))
	info_bar.add_child(_lbl_bock_banner)

	# Schnelleingabe-Box (fuer physischen Tisch)
	var entry_panel := PanelContainer.new()
	entry_panel.add_theme_stylebox_override("panel", ThemeHelper.make_wood_box(12))
	root.add_child(entry_panel)

	var entry_vbox := VBoxContainer.new()
	entry_vbox.add_theme_constant_override("separation", 8)
	entry_panel.add_child(entry_vbox)

	var row1 := HFlowContainer.new()
	row1.add_theme_constant_override("h_separation", 8)
	row1.add_theme_constant_override("v_separation", 6)
	entry_vbox.add_child(row1)

	var lbl_w := Label.new()
	lbl_w.text = "Sieger:"
	ThemeHelper.style_body(lbl_w, 15)
	row1.add_child(lbl_w)

	_btn_win_re = Button.new()
	_btn_win_re.text = "RE"
	_btn_win_re.toggle_mode = true
	_btn_win_re.button_pressed = true
	_btn_win_re.custom_minimum_size = Vector2(64, 38)
	ThemeHelper.style_button(_btn_win_re, ThemeHelper.COL_SUCCESS)
	_btn_win_re.pressed.connect(func() -> void: _set_winner_side("re"))
	row1.add_child(_btn_win_re)

	_btn_win_kontra = Button.new()
	_btn_win_kontra.text = "KONTRA"
	_btn_win_kontra.toggle_mode = true
	_btn_win_kontra.custom_minimum_size = Vector2(88, 38)
	ThemeHelper.style_button(_btn_win_kontra, ThemeHelper.COL_BRASS_DIM)
	_btn_win_kontra.pressed.connect(func() -> void: _set_winner_side("kontra"))
	row1.add_child(_btn_win_kontra)

	_btn_win_draw = Button.new()
	_btn_win_draw.text = "120:120"
	_btn_win_draw.toggle_mode = true
	_btn_win_draw.custom_minimum_size = Vector2(80, 38)
	ThemeHelper.style_button(_btn_win_draw, ThemeHelper.COL_BRASS_DIM)
	_btn_win_draw.pressed.connect(func() -> void: _set_winner_side("draw"))
	row1.add_child(_btn_win_draw)

	var lbl_p := Label.new()
	lbl_p.text = "Punkte:"
	ThemeHelper.style_body(lbl_p, 15)
	row1.add_child(lbl_p)

	var btn_minus := Button.new()
	btn_minus.text = " -1 "
	btn_minus.custom_minimum_size = Vector2(46, 38)
	ThemeHelper.style_button(btn_minus)
	btn_minus.pressed.connect(func() -> void:
		_points_val = maxi(0, _points_val - 1)
		_lbl_points_val.text = str(_points_val)
	)
	row1.add_child(btn_minus)

	_lbl_points_val = Label.new()
	_lbl_points_val.text = "2"
	_lbl_points_val.custom_minimum_size = Vector2(36, 0)
	_lbl_points_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeHelper.style_title(_lbl_points_val, 22)
	row1.add_child(_lbl_points_val)

	var btn_plus := Button.new()
	btn_plus.text = " +1 "
	btn_plus.custom_minimum_size = Vector2(46, 38)
	ThemeHelper.style_button(btn_plus)
	btn_plus.pressed.connect(func() -> void:
		_points_val = mini(30, _points_val + 1)
		_lbl_points_val.text = str(_points_val)
	)
	row1.add_child(btn_plus)

	# Schnellwahl-Chips (1-Tap Punkte)
	for qv in [1, 2, 3, 4, 6, 8, 12]:
		var qb := Button.new()
		qb.text = str(qv)
		qb.custom_minimum_size = Vector2(46, 44)
		ThemeHelper.style_button(qb, ThemeHelper.COL_BRASS_DIM)
		var val: int = qv
		qb.pressed.connect(func() -> void:
			_points_val = val
			_lbl_points_val.text = str(_points_val)
		)
		row1.add_child(qb)

	_chk_solo = CheckBox.new()
	_chk_solo.text = "Solo (1 vs 3)"
	row1.add_child(_chk_solo)

	_opt_solo_player = OptionButton.new()
	row1.add_child(_opt_solo_player)

	var btn_add := Button.new()
	btn_add.text = "+ Runde"
	ThemeHelper.style_button(btn_add, ThemeHelper.COL_SUCCESS)
	btn_add.pressed.connect(_on_add_round_pressed)
	row1.add_child(btn_add)

	var row2 := HFlowContainer.new()
	row2.add_theme_constant_override("h_separation", 10)
	row2.add_theme_constant_override("v_separation", 6)
	entry_vbox.add_child(row2)
	var lbl_re := Label.new()
	lbl_re.text = "Re-Spieler:"
	ThemeHelper.style_body(lbl_re, 14, ThemeHelper.COL_BRASS)
	row2.add_child(lbl_re)

	for i in range(4):
		var tb := Button.new()
		tb.toggle_mode = true
		tb.text = "P%d" % (i + 1)
		tb.custom_minimum_size = Vector2(106, 38)
		tb.button_pressed = (i < 2)
		ThemeHelper.style_button(tb, ThemeHelper.COL_BRASS if tb.button_pressed else ThemeHelper.COL_BRASS_DIM)
		row2.add_child(tb)
		_re_toggles.append(tb)

	_chk_re_ansage = CheckBox.new()
	_chk_re_ansage.text = "Re (+2)"
	row2.add_child(_chk_re_ansage)
	_chk_kontra_ansage = CheckBox.new()
	_chk_kontra_ansage.text = "Kontra (+2)"
	row2.add_child(_chk_kontra_ansage)
	_chk_fuchs = CheckBox.new()
	_chk_fuchs.text = "Fuchs (+1)"
	row2.add_child(_chk_fuchs)
	_chk_karlchen = CheckBox.new()
	_chk_karlchen.text = "Karlchen (+1)"
	row2.add_child(_chk_karlchen)
	_chk_doko = CheckBox.new()
	_chk_doko.text = "Doppelkopf (+1)"
	row2.add_child(_chk_doko)

	# Tabs: Verlauf | Graph | Statistiken & Kasse
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tab_container)

	# Dezentes kariertes Schreibblock-Papier als Hintergrund-Panel fuer Verlauf
	var paper_bg := TextureRect.new()
	if ResourceLoader.exists("res://assets/ui/lined_paper_bg.png"):
		paper_bg.texture = ResourceLoader.load("res://assets/ui/lined_paper_bg.png")
	paper_bg.stretch_mode = TextureRect.STRETCH_TILE
	paper_bg.modulate = Color(0.82, 0.76, 0.64, 0.24)
	paper_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hist_wrapper := Control.new()
	hist_wrapper.name = "Verlauf"
	hist_wrapper.add_child(paper_bg)

	var hist_scroll := ScrollContainer.new()
	hist_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_grid = GridContainer.new()
	_history_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_grid.add_theme_constant_override("h_separation", 18)
	_history_grid.add_theme_constant_override("v_separation", 6)
	_history_list.add_child(_history_grid)
	hist_scroll.add_child(_history_list)
	hist_wrapper.add_child(hist_scroll)
	_tab_container.add_child(hist_wrapper)

	_chart = PointsChart.new()
	_chart.name = "Punkte-Graph"
	_tab_container.add_child(_chart)

	var stats_scroll := ScrollContainer.new()
	stats_scroll.name = "Statistik & Kasse"
	_stats_box = VBoxContainer.new()
	_stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_box.add_theme_constant_override("separation", 6)
	stats_scroll.add_child(_stats_box)
	_tab_container.add_child(stats_scroll)


func refresh_all() -> void:
	var sess := SchreibblockStore.get_active_session()
	if sess.is_empty():
		return
	var players: Array = sess.get("players", [])
	var dealer_idx := int(sess.get("dealer_index", 0)) % maxi(1, players.size())
	var dealer_name := str(players[dealer_idx]) if not players.is_empty() else "-"
	_lbl_session_info.text = "%s  |  Runden: %d  |  Geber: %s  |  Einsatz: %.0f ct/Pkt" % [
		str(sess.get("title", "Abend")),
		sess.get("rounds", []).size(),
		dealer_name,
		float(sess.get("cents_per_point", 5.0)),
	]

	var bq: Array = sess.get("bock_queue", [])
	if bq.is_empty():
		_lbl_bock_banner.text = "Keine anstehenden Bockrunden"
	else:
		_lbl_bock_banner.text = "BOCKRUNDEN AKTIV: %d (Naechste: x%d)" % [bq.size(), int(bq[0])]

	_opt_solo_player.clear()
	for i in range(players.size()):
		_opt_solo_player.add_item(str(players[i]))
		if i < _re_toggles.size():
			_re_toggles[i].text = str(players[i])

	# Verlauf als sauberes Tabellen-Grid aktualisieren
	for c in _history_grid.get_children():
		c.queue_free()
	_history_grid.columns = 3 + players.size()
	for hdr in ["Rd", "Sieger", "Bock"]:
		var h_lbl := Label.new()
		h_lbl.text = hdr
		h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ThemeHelper.style_body(h_lbl, 17, ThemeHelper.COL_BRASS)
		_history_grid.add_child(h_lbl)
	for p in players:
		var p_lbl := Label.new()
		p_lbl.text = str(p)
		p_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ThemeHelper.style_body(p_lbl, 17, ThemeHelper.COL_BRASS)
		_history_grid.add_child(p_lbl)

	var rounds: Array = sess.get("rounds", [])
	for r_idx in range(rounds.size() - 1, -1, -1):
		var r: Dictionary = rounds[r_idx]
		var deltas: Dictionary = r.get("deltas", {})
		var c1 := Label.new()
		c1.text = "#%d" % int(r.get("round_no", r_idx + 1))
		c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ThemeHelper.style_body(c1, 17, ThemeHelper.COL_MUTED)
		_history_grid.add_child(c1)

		var c2 := Label.new()
		c2.text = str(r.get("winner_side", "")).to_upper()
		c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ThemeHelper.style_body(c2, 17, ThemeHelper.COL_CREAM)
		_history_grid.add_child(c2)

		var c3 := Label.new()
		c3.text = "x%d" % int(r.get("bock_multiplier", 1))
		c3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ThemeHelper.style_body(c3, 17, Color(0.95, 0.72, 0.25) if int(r.get("bock_multiplier", 1)) > 1 else ThemeHelper.COL_MUTED)
		_history_grid.add_child(c3)

		var re_list: Array = r.get("re_players", [])
		for p in players:
			var d := int(deltas.get(p, 0))
			var dl := Label.new()
			var re_mark := " [Re]" if re_list.has(p) else ""
			dl.text = ("%s%d%s" % ["+" if d > 0 else "", d, re_mark])
			dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var col := Color(0.42, 0.85, 0.52) if d > 0 else (Color(0.90, 0.38, 0.34) if d < 0 else ThemeHelper.COL_MUTED)
			ThemeHelper.style_body(dl, 17, col)
			_history_grid.add_child(dl)

	# Graph aktualisieren
	_chart.set_series(SchreibblockStore.get_cumulative_series())

	# Statistik & Kasse aktualisieren
	for c in _stats_box.get_children():
		c.queue_free()
	var stats: Dictionary = SchreibblockStore.get_player_stats()
	for p in players:
		var st: Dictionary = stats.get(p, {})
		var lbl := Label.new()
		lbl.text = "%s:  %d Pkt  |  Siegrate: %.0f%% (%d/%d)  |  Soli: %d  |  Bilanz: %.2f EUR" % [
			p,
			int(st.get("points", 0)),
			float(st.get("win_rate", 0.0)) * 100.0,
			int(st.get("wins", 0)),
			int(st.get("games", 0)),
			int(st.get("solos", 0)),
			float(st.get("euro", 0.0)),
		]
		ThemeHelper.style_body(lbl, 16)
		_stats_box.add_child(lbl)

	var sep := HSeparator.new()
	_stats_box.add_child(sep)
	var kasse_title := Label.new()
	kasse_title.text = "Kassen-Ausgleich (Minimale Transfers):"
	ThemeHelper.style_title(kasse_title, 18)
	_stats_box.add_child(kasse_title)

	var transfers: Array = SchreibblockStore.get_settlement_transfers()
	if transfers.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Noch keine offenen Betraege."
		ThemeHelper.style_body(empty_lbl, 15, ThemeHelper.COL_MUTED)
		_stats_box.add_child(empty_lbl)
	else:
		for tr in transfers:
			var tlbl := Label.new()
			tlbl.text = "  • %s zahlt an %s: %.2f EUR" % [tr.from, tr.to, float(tr.amount)]
			ThemeHelper.style_body(tlbl, 16, Color(0.95, 0.85, 0.55))
			_stats_box.add_child(tlbl)

		var btn_copy := Button.new()
		btn_copy.text = "Abrechnung kopieren (fuer Chat)"
		ThemeHelper.style_button(btn_copy, ThemeHelper.COL_SUCCESS)
		btn_copy.pressed.connect(func() -> void:
			var lines: Array[String] = ["Uriges Doppelkopf - Kassen-Abrechnung:"]
			for t in transfers:
				lines.append("- %s -> %s: %.2f EUR" % [t.from, t.to, float(t.amount)])
			DisplayServer.clipboard_set("\n".join(lines))
		)
		_stats_box.add_child(btn_copy)


func _set_winner_side(side: String) -> void:
	_winner_side = side
	_btn_win_re.button_pressed = (side == "re")
	_btn_win_kontra.button_pressed = (side == "kontra")
	_btn_win_draw.button_pressed = (side == "draw")
	ThemeHelper.style_button(_btn_win_re, ThemeHelper.COL_SUCCESS if side == "re" else ThemeHelper.COL_BRASS_DIM)
	ThemeHelper.style_button(_btn_win_kontra, ThemeHelper.COL_SUCCESS if side == "kontra" else ThemeHelper.COL_BRASS_DIM)
	ThemeHelper.style_button(_btn_win_draw, ThemeHelper.COL_SUCCESS if side == "draw" else ThemeHelper.COL_BRASS_DIM)


func _on_add_round_pressed() -> void:
	var sess := SchreibblockStore.get_active_session()
	var players: Array = sess.get("players", [])
	if players.size() < 4:
		return

	var winner_side := _winner_side
	var re_p: Array[String] = []
	var kontra_p: Array[String] = []
	var is_solo := _chk_solo.button_pressed
	var solo_player := _opt_solo_player.get_item_text(_opt_solo_player.selected) if is_solo else ""

	if is_solo:
		re_p.append(solo_player)
		for p in players:
			if p != solo_player:
				kontra_p.append(p)
	else:
		for i in range(mini(4, players.size())):
			if _re_toggles[i].button_pressed:
				re_p.append(str(players[i]))
			else:
				kontra_p.append(str(players[i]))

	var pts := _points_val
	if _chk_re_ansage.button_pressed:
		pts += 2
	if _chk_kontra_ansage.button_pressed:
		pts += 2
	if _chk_fuchs.button_pressed:
		pts += 1
	if _chk_karlchen.button_pressed:
		pts += 1
	if _chk_doko.button_pressed:
		pts += 1

	SchreibblockStore.add_manual_round({
		"winner_side": winner_side,
		"points": pts,
		"re_players": re_p,
		"kontra_players": kontra_p,
		"is_solo": is_solo,
		"solo_player": solo_player,
	})
	AudioFX.play_bid()
	refresh_all()
