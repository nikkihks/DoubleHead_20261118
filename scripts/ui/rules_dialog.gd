class_name RulesDialog
extends PanelContainer

## Uebersichtliches, speicherbares Regel-Preset-System fuer den Host
## (sowohl fuer das P2P-Live-Spiel als auch fuer den Schreibblock).

signal rules_applied(rules: RuleConfig)
signal closed

var current_rules: RuleConfig = RuleConfig.preset("Kneipen-Standard")
var _checks: Dictionary = {}
var _opt_preset: OptionButton
var _opt_schwein: OptionButton
var _opt_hochzeit: OptionButton


func _init() -> void:
	add_theme_stylebox_override("panel", ThemeHelper.make_slate_box(ThemeHelper.COL_BRASS, 16))
	custom_minimum_size = Vector2(780, 520)
	_build_ui()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "Regel-Werkstatt & Sonderregeln"
	ThemeHelper.style_title(title, 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var btn_close := Button.new()
	btn_close.text = "Fertig & Speichern"
	ThemeHelper.style_button(btn_close, ThemeHelper.COL_SUCCESS)
	btn_close.pressed.connect(func() -> void:
		_read_from_ui()
		rules_applied.emit(current_rules)
		closed.emit()
		visible = false
	)
	header.add_child(btn_close)

	# Preset-Zeile
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 10)
	root.add_child(preset_row)
	var p_lbl := Label.new()
	p_lbl.text = "Preset:"
	ThemeHelper.style_body(p_lbl, 17, ThemeHelper.COL_BRASS)
	preset_row.add_child(p_lbl)

	_opt_preset = OptionButton.new()
	ThemeHelper.style_option_button(_opt_preset)
	for p in ["Kneipen-Standard", "DDV Turnier", "Scharf (Ohne 9er)", "Custom"]:
		_opt_preset.add_item(p)
	_opt_preset.item_selected.connect(func(idx: int) -> void:
		var pname := _opt_preset.get_item_text(idx)
		if pname != "Custom":
			current_rules = RuleConfig.preset(pname)
			_sync_to_ui()
	)
	preset_row.add_child(_opt_preset)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	_add_check(grid, "with_nines", "Mit Neunen (48 Karten)")
	_add_check(grid, "dulle_second_wins", "Zweite Dulle sticht erste")
	_add_check(grid, "dulle_last_trick_exception", "Dulle: Ausnahme letzter Stich")
	_add_check(grid, "superschweinchen", "Superschweinchen (Karo 9er)")
	_add_check(grid, "fuchs_gefangen_point", "Fuchs gefangen (+1)")
	_add_check(grid, "fuchs_am_pin", "Fuchs am Pin (letzter Stich)")
	_add_check(grid, "karlchen_last_trick", "Karlchen am End (+1)")
	_add_check(grid, "karlchen_gefangen", "Karlchen gefangen (+1)")
	_add_check(grid, "stille_hochzeit", "Stille Hochzeit erlaubt")
	_add_check(grid, "armut_enabled", "Armut (< 3 Truempfe schieben)")
	_add_check(grid, "schmeissen_5_nines", "Schmeissen: 5 Neunen")
	_add_check(grid, "schmeissen_5_kings", "Schmeissen: 5 Koenige")
	_add_check(grid, "schmeissen_lt3_trump", "Schmeissen: < 3 Truempfe")
	_add_check(grid, "pflichtsolo_enabled", "Pflichtsolo aktiv")
	_add_check(grid, "bock_stacking", "Bockrunden stapeln (x2, x4)")
	_add_check(grid, "bock_spaltarsch", "Bock bei 120:120")
	_add_check(grid, "bock_lost_rk", "Bock bei verlorenem Re/Kontra")
	_add_check(grid, "bock_solo", "Bock nach Solo")

	# Dropdowns fuer Schweinchen & Hochzeit
	var opts_row := HBoxContainer.new()
	opts_row.add_theme_constant_override("separation", 16)
	root.add_child(opts_row)

	var l_sch := Label.new()
	l_sch.text = "Schweinchen:"
	ThemeHelper.style_body(l_sch, 15)
	opts_row.add_child(l_sch)
	_opt_schwein = OptionButton.new()
	for s in ["Aus", "Bei Spielbeginn", "Beim ersten Fuchs"]:
		_opt_schwein.add_item(s)
	opts_row.add_child(_opt_schwein)

	var l_h := Label.new()
	l_h.text = "Hochzeit-Klaerung:"
	ThemeHelper.style_body(l_h, 15)
	opts_row.add_child(l_h)
	_opt_hochzeit = OptionButton.new()
	for s in ["1. fremder Stich", "1. fremder Fehlstich", "1. Stich ueberhaupt"]:
		_opt_hochzeit.add_item(s)
	opts_row.add_child(_opt_hochzeit)

	_sync_to_ui()


func _add_check(parent: Control, key: String, label_text: String) -> void:
	var tb := Button.new()
	tb.toggle_mode = true
	tb.text = label_text
	tb.custom_minimum_size = Vector2(320, 36)
	ThemeHelper.style_button(tb, ThemeHelper.COL_BRASS_DIM)
	tb.toggled.connect(func(on: bool) -> void:
		ThemeHelper.style_button(tb, ThemeHelper.COL_SUCCESS if on else ThemeHelper.COL_BRASS_DIM)
	)
	parent.add_child(tb)
	_checks[key] = tb


func _sync_to_ui() -> void:
	_checks["with_nines"].button_pressed = current_rules.with_nines
	_checks["dulle_second_wins"].button_pressed = current_rules.dulle_second_wins
	_checks["dulle_last_trick_exception"].button_pressed = current_rules.dulle_last_trick_exception
	_checks["superschweinchen"].button_pressed = current_rules.superschweinchen
	_checks["fuchs_gefangen_point"].button_pressed = current_rules.fuchs_gefangen_point
	_checks["fuchs_am_pin"].button_pressed = current_rules.fuchs_am_pin
	_checks["karlchen_last_trick"].button_pressed = current_rules.karlchen_last_trick
	_checks["karlchen_gefangen"].button_pressed = current_rules.karlchen_gefangen
	_checks["stille_hochzeit"].button_pressed = current_rules.stille_hochzeit
	_checks["armut_enabled"].button_pressed = current_rules.armut_enabled
	_checks["schmeissen_5_nines"].button_pressed = current_rules.schmeissen_5_nines
	_checks["schmeissen_5_kings"].button_pressed = current_rules.schmeissen_5_kings
	_checks["schmeissen_lt3_trump"].button_pressed = current_rules.schmeissen_lt3_trump
	_checks["pflichtsolo_enabled"].button_pressed = current_rules.pflichtsolo_enabled
	_checks["bock_stacking"].button_pressed = current_rules.bock_stacking
	_checks["bock_spaltarsch"].button_pressed = current_rules.bock_triggers.get("spaltarsch_120", true)
	_checks["bock_lost_rk"].button_pressed = current_rules.bock_triggers.get("lost_re_kontra", true)
	_checks["bock_solo"].button_pressed = current_rules.bock_triggers.get("solo_played", true)
	_opt_schwein.selected = clampi(current_rules.schweinchen_mode, 0, 2)
	_opt_hochzeit.selected = clampi(current_rules.hochzeit_clarification, 0, 2)


func _read_from_ui() -> void:
	current_rules.with_nines = _checks["with_nines"].button_pressed
	current_rules.dulle_second_wins = _checks["dulle_second_wins"].button_pressed
	current_rules.dulle_last_trick_exception = _checks["dulle_last_trick_exception"].button_pressed
	current_rules.superschweinchen = _checks["superschweinchen"].button_pressed
	current_rules.fuchs_gefangen_point = _checks["fuchs_gefangen_point"].button_pressed
	current_rules.fuchs_am_pin = _checks["fuchs_am_pin"].button_pressed
	current_rules.karlchen_last_trick = _checks["karlchen_last_trick"].button_pressed
	current_rules.karlchen_gefangen = _checks["karlchen_gefangen"].button_pressed
	current_rules.stille_hochzeit = _checks["stille_hochzeit"].button_pressed
	current_rules.armut_enabled = _checks["armut_enabled"].button_pressed
	current_rules.schmeissen_5_nines = _checks["schmeissen_5_nines"].button_pressed
	current_rules.schmeissen_5_kings = _checks["schmeissen_5_kings"].button_pressed
	current_rules.schmeissen_lt3_trump = _checks["schmeissen_lt3_trump"].button_pressed
	current_rules.pflichtsolo_enabled = _checks["pflichtsolo_enabled"].button_pressed
	current_rules.bock_stacking = _checks["bock_stacking"].button_pressed
	current_rules.bock_triggers["spaltarsch_120"] = _checks["bock_spaltarsch"].button_pressed
	current_rules.bock_triggers["lost_re_kontra"] = _checks["bock_lost_rk"].button_pressed
	current_rules.bock_triggers["solo_played"] = _checks["bock_solo"].button_pressed
	current_rules.schweinchen_mode = _opt_schwein.selected
	current_rules.hochzeit_clarification = _opt_hochzeit.selected
