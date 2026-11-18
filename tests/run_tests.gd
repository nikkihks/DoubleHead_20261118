extends SceneTree

## Automatisierte Unit- & Integrations-Tests fuer "Uriges Doppelkopf"
## Aufruf: Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd

var _failures: int = 0
var _passed: int = 0


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failures += 1
		push_error("TEST FAIL: " + msg)
		print("FAIL: " + msg)


func _init() -> void:
	print("=== Uriges Doppelkopf Test-Suite ===")
	_test_deck_and_points()
	_test_rule_presets()
	_test_doko_engine_full_round()
	_test_dulle_second_wins()
	_test_solo_and_schweinchen()
	_test_schreibblock_store()
	print("=== Ergebnis: %d bestanden, %d fehlgeschlagen ===" % [_passed, _failures])
	quit(1 if _failures > 0 else 0)


func _test_deck_and_points() -> void:
	var deck48 := CardData.create_deck(true)
	_assert(deck48.size() == 48, "48er Deck hat 48 Karten")
	var total_pts := 0
	for c in deck48:
		total_pts += c.points()
	_assert(total_pts == 240, "48er Deck hat exakt 240 Augen")

	var deck40 := CardData.create_deck(false)
	_assert(deck40.size() == 40, "40er Deck (ohne 9er) hat 40 Karten")
	var total_pts40 := 0
	for c in deck40:
		total_pts40 += c.points()
	_assert(total_pts40 == 240, "40er Deck hat exakt 240 Augen")


func _test_rule_presets() -> void:
	var ddv := RuleConfig.preset("DDV Turnier")
	_assert(ddv.with_nines == false, "DDV Turnier spielt ohne 9er")
	var kneipe := RuleConfig.preset("Kneipen-Standard")
	_assert(kneipe.with_nines == true, "Kneipen-Standard spielt mit 9ern")
	var scharf := RuleConfig.preset("Scharf (Ohne 9er)")
	_assert(scharf.with_nines == false, "Scharf ohne 9er")
	var d := ddv.to_dict()
	var ddv2 := RuleConfig.from_dict(d)
	_assert(ddv2.preset_name == "DDV Turnier", "RuleConfig Roundtrip")


func _test_doko_engine_full_round() -> void:
	var eng := DokoEngine.new()
	var players: Array[String] = ["Anna", "Ben", "Clara", "Dieter"]
	var rules := RuleConfig.preset("Kneipen-Standard")
	eng.start_round(players, 0, rules, 1, 42)
	_assert(eng.phase == DokoEngine.Phase.VORBEHALT, "Phase ist VORBEHALT nach start_round")

	# Alle sagen gesund
	for i in range(4):
		var s := (1 + i) % 4
		eng.declare_vorbehalt(s, "gesund")
	_assert(eng.phase == DokoEngine.Phase.PLAYING, "Phase ist PLAYING nach Vorbehalt")

	# 12 Stiche komplett mit DokoBot durchspielen
	var steps := 0
	while eng.phase == DokoEngine.Phase.PLAYING and steps < 60:
		var seat := eng.current_turn
		var cid := DokoBot.choose_card(eng, seat)
		_assert(cid != "", "Bot findet gueltige Karte fuer Sitz %d" % seat)
		var res := eng.play_card(seat, cid)
		_assert(not res.has("error"), "Gueltiger Zug ohne Fehler: " + str(res.get("error", "")))
		steps += 1

	_assert(eng.phase == DokoEngine.Phase.ROUND_END, "Runde endet nach 12 Stichen")
	var score := eng.calculate_round_score()
	var sum_augen := int(score.get("re_points", 0)) + int(score.get("kontra_points", 0))
	_assert(sum_augen == 240, "Augensumme am Rundenende ist 240 (war %d)" % sum_augen)
	var state0 := eng.build_state_for_seat(0)
	_assert(state0.has("hands") or state0.has("my_hand"), "build_state_for_seat liefert State")


func _test_dulle_second_wins() -> void:
	var eng := DokoEngine.new()
	var players: Array[String] = ["A", "B", "C", "D"]
	var rules := RuleConfig.preset("Kneipen-Standard")
	rules.dulle_second_wins = true
	eng.start_round(players, 0, rules, 1, 100)
	var dulle1 := CardData.new()
	dulle1.suit = CardData.Suit.HEARTS
	dulle1.rank = CardData.Rank.TEN
	dulle1.copy = 0
	var dulle2 := CardData.new()
	dulle2.suit = CardData.Suit.HEARTS
	dulle2.rank = CardData.Rank.TEN
	dulle2.copy = 1
	_assert(eng.is_trump(dulle1), "Herz 10 ist Trumpf")
	_assert(eng.trump_order(dulle1) == eng.trump_order(dulle2), "Beide Dullen haben gleichen Grundrang")


func _test_solo_and_schweinchen() -> void:
	var eng := DokoEngine.new()
	var c_queen := CardData.new()
	c_queen.suit = CardData.Suit.CLUBS
	c_queen.rank = CardData.Rank.QUEEN
	var c_ace := CardData.new()
	c_ace.suit = CardData.Suit.SPADES
	c_ace.rank = CardData.Rank.ACE
	_assert(not eng.is_trump(c_queen, "fleischlos"), "Im Fleischlos ist Kreuz Dame kein Trumpf")
	_assert(eng.is_trump(c_queen, "damen"), "Im Damensolo ist Kreuz Dame Trumpf")
	_assert(not eng.is_trump(c_ace, "buben"), "Im Bubensolo ist Pik Ass kein Trumpf")


func _test_schreibblock_store() -> void:
	var cls := load("res://scripts/schreibblock/schreibblock_store.gd")
	var store = cls.new()
	var players: Array[String] = ["Anna", "Ben", "Clara", "Dieter"]
	store.create_session("Testabend", players, 5.0)
	store.add_manual_round({
		"winner_side": "re",
		"points": 3,
		"re_players": ["Anna", "Ben"],
		"kontra_players": ["Clara", "Dieter"],
		"is_solo": false,
		"announcements": ["re"],
		"extras": {"fuchs": 1},
	})
	var stats: Dictionary = store.get_player_stats()
	_assert(stats.has("Anna"), "Statistik enthaelt Anna")
	var transfers: Array = store.get_settlement_transfers()
	_assert(transfers.size() > 0, "Abrechnung erzeugt Transfers")
