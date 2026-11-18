class_name DokoEngine
extends RefCounted

## Vollstaendige, host-autoritative Doppelkopf-Regel-Engine.
## Unterstuetzt 4 aktive Spieler (inkl. 5/6+ Spieler-Rotation), alle Soli,
## Hochzeit, Armut, Schmeissen, Schweinchen/Superschweinchen, Dullen-Regeln,
## alle Ansage-Zeitfenster, Sonderpunkte und Bockrunden-Trigger.

enum Phase { IDLE, VORBEHALT, PLAYING, ROUND_END }

var phase: Phase = Phase.IDLE
var all_players: Array[String] = []
var active_seats: Array[int] = [] # Indizes in all_players (immer 4 aktive Spieler)
var dealer_index: int = 0
var rules: RuleConfig = RuleConfig.preset("Kneipen-Standard")
var bock_multiplier: int = 1

var hands: Dictionary = {} # active_pos (0..3) -> Array[CardData]
var trick_cards: Array[Dictionary] = [] # [{seat: int, card: CardData}]
var trick_leader: int = 0
var current_turn: int = 0
var trick_count: int = 0
var total_tricks: int = 12
var completed_tricks: Array[Dictionary] = []

var declarations: Dictionary = {} # seat (0..3) -> {choice, solo_kind}
var solo_kind: String = "" # "" = Normalspiel, sonst damen/buben/karo/herz/pik/kreuz/fleischlos/koenig/damen_buben
var solo_seat: int = -1

var re_seats: Array[int] = []
var kontra_seats: Array[int] = []
var is_hochzeit: bool = false
var hochzeit_seat: int = -1
var hochzeit_clarified: bool = false
var is_stille_hochzeit: bool = false
var is_armut: bool = false
var armut_seat: int = -1
var schweinchen_seat: int = -1
var schweinchen_announced: bool = false
var superschweinchen_seat: int = -1

var announcements: Dictionary = {
	"re": false,
	"kontra": false,
	"re_no90": false,
	"re_no60": false,
	"re_no30": false,
	"re_schwarz": false,
	"kontra_no90": false,
	"kontra_no60": false,
	"kontra_no30": false,
	"kontra_schwarz": false,
}

var captured_points: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0}
var special_events: Array[Dictionary] = [] # [{type, side, seat, points, detail}]
var last_round_result: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func start_round(
	players: Array[String],
	p_dealer_idx: int,
	p_rules: RuleConfig,
	p_bock_mult: int = 1,
	rng_seed: int = -1
) -> void:
	all_players = players.duplicate()
	dealer_index = p_dealer_idx % maxi(1, all_players.size())
	rules = p_rules
	bock_multiplier = maxi(1, p_bock_mult)

	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	active_seats.clear()
	var n := all_players.size()
	if n <= 4:
		for i in range(n):
			active_seats.append(i)
	else:
		# Geber setzt bei 5+ Spielern aus (oder naechste 4 im Uhrzeigersinn)
		for offset in range(1, 5):
			active_seats.append((dealer_index + offset) % n)

	var deck := CardData.create_deck(rules.with_nines)
	# Fisher-Yates Shuffle
	for i in range(deck.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := deck[i]
		deck[i] = deck[j]
		deck[j] = tmp

	total_tricks = 12 if rules.with_nines else 10
	hands.clear()
	for s in range(4):
		var hand: Array[CardData] = []
		for k in range(total_tricks):
			hand.append(deck[s * total_tricks + k])
		hands[s] = hand

	trick_cards.clear()
	completed_tricks.clear()
	declarations.clear()
	special_events.clear()
	last_round_result.clear()
	solo_kind = ""
	solo_seat = -1
	is_hochzeit = false
	hochzeit_seat = -1
	hochzeit_clarified = false
	is_stille_hochzeit = false
	is_armut = false
	armut_seat = -1
	schweinchen_seat = -1
	schweinchen_announced = false
	superschweinchen_seat = -1
	trick_count = 0
	for s in range(4):
		captured_points[s] = 0

	for k in announcements.keys():
		announcements[k] = false

	_detect_initial_teams_and_schweinchen()
	trick_leader = 0 if n > 4 else (dealer_index + 1) % 4
	current_turn = trick_leader
	phase = Phase.VORBEHALT


func _detect_initial_teams_and_schweinchen() -> void:
	re_seats.clear()
	kontra_seats.clear()
	for s in range(4):
		var clubs_queens := 0
		var fox_count := 0
		var dia_nine_count := 0
		for c in hands[s]:
			if c.is_alte():
				clubs_queens += 1
			if c.is_fox():
				fox_count += 1
			if c.suit == CardData.Suit.DIAMONDS and c.rank == CardData.Rank.NINE:
				dia_nine_count += 1
		if clubs_queens > 0:
			re_seats.append(s)
		else:
			kontra_seats.append(s)
		if fox_count == 2 and rules.schweinchen_mode > 0:
			schweinchen_seat = s
			if rules.schweinchen_mode == 1:
				schweinchen_announced = true
		if dia_nine_count == 2 and rules.superschweinchen:
			superschweinchen_seat = s


func can_schmeissen(seat: int) -> String:
	var hand: Array[CardData] = hands.get(seat, [])
	var nines := 0
	var kings := 0
	var trumps := 0
	var has_high := false
	for c in hand:
		if c.rank == CardData.Rank.NINE:
			nines += 1
		if c.rank == CardData.Rank.KING:
			kings += 1
		if is_trump(c, ""):
			trumps += 1
			if trump_order(c, "") > 40: # Ueber Karo Ass
				has_high = true
	if rules.schmeissen_5_nines and nines >= 5:
		return "5 Neunen"
	if rules.schmeissen_5_kings and kings >= 5:
		return "5 Koenige"
	if rules.schmeissen_9_and_k and (nines + kings) >= 7:
		return "7+ Neunen/Koenige"
	if rules.schmeissen_lt3_trump and trumps < 3:
		return "Weniger als 3 Truempfe"
	if rules.schmeissen_no_face and not has_high:
		return "Kein Trumpf ueber Fuchs"
	return ""


func has_hochzeit(seat: int) -> bool:
	var q := 0
	for c in hands.get(seat, []):
		if c.is_alte():
			q += 1
	return q == 2


func has_armut(seat: int) -> bool:
	if not rules.armut_enabled:
		return false
	var trumps := 0
	for c in hands.get(seat, []):
		if is_trump(c, ""):
			trumps += 1
	return trumps < 3


func is_trump(card: CardData, p_solo_kind: String = "__CURRENT__") -> bool:
	var sk := solo_kind if p_solo_kind == "__CURRENT__" else p_solo_kind
	match sk:
		"fleischlos":
			return false
		"damen":
			return card.rank == CardData.Rank.QUEEN
		"buben":
			return card.rank == CardData.Rank.JACK
		"koenig":
			return card.rank == CardData.Rank.KING
		"damen_buben":
			return card.rank == CardData.Rank.QUEEN or card.rank == CardData.Rank.JACK
		"karo", "herz", "pik", "kreuz":
			var s_enum := _solo_suit_enum(sk)
			return card.is_dulle() or card.rank == CardData.Rank.QUEEN or card.rank == CardData.Rank.JACK or card.suit == s_enum
		_:
			# Normalspiel
			return card.is_dulle() or card.rank == CardData.Rank.QUEEN or card.rank == CardData.Rank.JACK or card.suit == CardData.Suit.DIAMONDS


func _solo_suit_enum(sk: String) -> CardData.Suit:
	match sk:
		"kreuz": return CardData.Suit.CLUBS
		"pik": return CardData.Suit.SPADES
		"herz": return CardData.Suit.HEARTS
		_: return CardData.Suit.DIAMONDS


func _suit_power(s: CardData.Suit) -> int:
	match s:
		CardData.Suit.CLUBS: return 4
		CardData.Suit.SPADES: return 3
		CardData.Suit.HEARTS: return 2
		CardData.Suit.DIAMONDS: return 1
	return 0


func trump_order(card: CardData, p_solo_kind: String = "__CURRENT__") -> int:
	var sk := solo_kind if p_solo_kind == "__CURRENT__" else p_solo_kind
	if not is_trump(card, sk):
		return 0

	if sk == "" and superschweinchen_seat >= 0 and card.suit == CardData.Suit.DIAMONDS and card.rank == CardData.Rank.NINE:
		return 120
	if sk == "" and schweinchen_seat >= 0 and schweinchen_announced and card.is_fox():
		return 110

	if sk == "damen":
		return 60 + _suit_power(card.suit)
	if sk == "buben":
		return 50 + _suit_power(card.suit)
	if sk == "koenig":
		return 50 + _suit_power(card.suit)
	if sk == "damen_buben":
		var base := 70 if card.rank == CardData.Rank.QUEEN else 50
		return base + _suit_power(card.suit)

	# Normalspiel oder Farbsolo
	if card.is_dulle():
		return 100
	if card.rank == CardData.Rank.QUEEN:
		return 80 + _suit_power(card.suit)
	if card.rank == CardData.Rank.JACK:
		return 60 + _suit_power(card.suit)

	# Trumpffarbe: A > 10 > K > 9
	match card.rank:
		CardData.Rank.ACE: return 40
		CardData.Rank.TEN: return 30
		CardData.Rank.KING: return 20
		CardData.Rank.NINE: return 10
	return 5


func _fehl_order(card: CardData) -> int:
	match card.rank:
		CardData.Rank.ACE: return 6
		CardData.Rank.TEN: return 5
		CardData.Rank.KING: return 4
		CardData.Rank.QUEEN: return 3
		CardData.Rank.JACK: return 2
		CardData.Rank.NINE: return 1
	return 0


func get_legal_cards(seat: int) -> Array[CardData]:
	var hand: Array[CardData] = hands.get(seat, [])
	if trick_cards.is_empty():
		return hand.duplicate()

	var lead_card: CardData = trick_cards[0].card
	var lead_is_trump := is_trump(lead_card)
	var matching: Array[CardData] = []

	for c in hand:
		if lead_is_trump:
			if is_trump(c):
				matching.append(c)
		else:
			if not is_trump(c) and c.suit == lead_card.suit:
				matching.append(c)

	return matching if not matching.is_empty() else hand.duplicate()


func declare_vorbehalt(seat: int, choice: String, p_solo_kind: String = "") -> Dictionary:
	if phase != Phase.VORBEHALT:
		return {"error": "Nicht in Vorbehalt-Phase"}
	declarations[seat] = {"choice": choice, "solo_kind": p_solo_kind}

	if declarations.size() < 4:
		current_turn = (seat + 1) % 4
		return {"status": "waiting", "next_turn": current_turn}

	# Alle 4 haben erklaert -> Aufloesen (Schmeissen > Solo > Armut > Hochzeit > Gesund)
	for s in range(4):
		if declarations[s].choice == "schmeissen" and can_schmeissen(s) != "":
			phase = Phase.ROUND_END
			last_round_result = {
				"schmeissen": true,
				"schmeissen_seat": s,
				"reason": can_schmeissen(s),
				"re_points": 120,
				"kontra_points": 120,
				"winner_side": "draw",
				"total_points": 0,
				"deltas": {0: 0, 1: 0, 2: 0, 3: 0},
				"bock_triggered": [],
			}
			return {"status": "schmeissen", "seat": s}

	# Solo pruefen
	for offset in range(4):
		var s := (trick_leader + offset) % 4
		if declarations[s].choice == "solo":
			var sk := str(declarations[s].solo_kind)
			if rules.soli_enabled.get(sk, false):
				solo_kind = sk
				solo_seat = s
				re_seats = [s]
				kontra_seats.clear()
				for k in range(4):
					if k != s:
						kontra_seats.append(k)
				trick_leader = s # Solist kommt raus (Vorhand bei Lustsolo/Pflichtsolo vereinfacht)
				current_turn = trick_leader
				phase = Phase.PLAYING
				return {"status": "started", "solo_kind": solo_kind, "solo_seat": solo_seat}

	# Hochzeit pruefen
	for s in range(4):
		if declarations[s].choice == "hochzeit" and has_hochzeit(s):
			is_hochzeit = true
			hochzeit_seat = s
			hochzeit_clarified = false
			re_seats = [s]
			kontra_seats.clear()
			for k in range(4):
				if k != s:
					kontra_seats.append(k)
			break

	# Stille Hochzeit (2 Kreuz Damen, aber "gesund" gesagt)
	if not is_hochzeit:
		for s in range(4):
			if has_hochzeit(s) and rules.stille_hochzeit:
				is_stille_hochzeit = true
				solo_seat = s
				re_seats = [s]
				kontra_seats.clear()
				for k in range(4):
					if k != s:
						kontra_seats.append(k)

	# Armut
	if not is_hochzeit:
		for s in range(4):
			if declarations[s].choice == "armut" and has_armut(s):
				is_armut = true
				armut_seat = s
				break

	current_turn = trick_leader
	phase = Phase.PLAYING
	return {"status": "started", "solo_kind": solo_kind}


func make_announcement(seat: int, kind: String) -> bool:
	if phase != Phase.PLAYING:
		return false
	var hand_sz: int = hands[seat].size()
	var is_re := re_seats.has(seat)
	var min_cards_for := {
		"re": total_tricks - 1,
		"kontra": total_tricks - 1,
		"no90": total_tricks - 2,
		"no60": total_tricks - 3,
		"no30": total_tricks - 4,
		"schwarz": total_tricks - 5,
	}
	if not min_cards_for.has(kind):
		return false
	if hand_sz < int(min_cards_for[kind]):
		return false

	if kind == "re" and is_re:
		announcements["re"] = true
		return true
	if kind == "kontra" and not is_re:
		announcements["kontra"] = true
		return true

	var prefix := "re_" if is_re else "kontra_"
	var full_key := prefix + kind
	if announcements.has(full_key):
		announcements[full_key] = true
		return true
	return false


func play_card(seat: int, card_id: String) -> Dictionary:
	if phase != Phase.PLAYING:
		return {"error": "Spiel laeuft nicht"}
	if seat != current_turn:
		return {"error": "Nicht am Zug"}

	var card := _find_card_in_hand(seat, card_id)
	if card == null:
		return {"error": "Karte nicht auf der Hand"}
	var legal := get_legal_cards(seat)
	if not legal.has(card):
		return {"error": "Bedienpflicht verletzt"}

	if rules.schweinchen_mode == 2 and seat == schweinchen_seat and card.is_fox() and not schweinchen_announced:
		schweinchen_announced = true
		special_events.append({"type": "schweinchen", "seat": seat, "detail": "Schweinchen angesagt!"})

	hands[seat].erase(card)
	trick_cards.append({"seat": seat, "card": card})

	if trick_cards.size() < 4:
		current_turn = (seat + 1) % 4
		return {"status": "ok", "next_turn": current_turn}

	# Stich auswerten
	var winner := _evaluate_trick()
	var trick_pts := 0
	var trick_copy: Array[Dictionary] = []
	for entry in trick_cards:
		trick_pts += entry.card.points()
		trick_copy.append({"seat": entry.seat, "card": entry.card.to_dict()})

	captured_points[winner] += trick_pts
	_record_trick_specials(winner, trick_pts)

	# Hochzeit-Klaerung
	if is_hochzeit and not hochzeit_clarified:
		_check_hochzeit_clarification(winner)

	completed_tricks.append({
		"trick_no": trick_count + 1,
		"winner": winner,
		"points": trick_pts,
		"cards": trick_copy,
	})

	trick_cards.clear()
	trick_count += 1
	trick_leader = winner
	current_turn = winner

	var result := {
		"status": "trick_complete",
		"trick_winner": winner,
		"trick_points": trick_pts,
		"trick_cards": trick_copy,
	}

	if trick_count >= total_tricks:
		phase = Phase.ROUND_END
		result["round_result"] = calculate_round_score()

	return result


func _evaluate_trick() -> int:
	var best_idx := 0
	var best_card: CardData = trick_cards[0].card
	var is_last_trick := (trick_count == total_tricks - 1)

	for i in range(1, 4):
		var c: CardData = trick_cards[i].card
		if _beats(c, best_card, is_last_trick):
			best_card = c
			best_idx = i

	return int(trick_cards[best_idx].seat)


func _beats(challenger: CardData, current_best: CardData, is_last_trick: bool) -> bool:
	var t_ch := trump_order(challenger)
	var t_be := trump_order(current_best)

	# Dulle-Sonderregel: Zweite Dulle sticht erste Dulle (ausser optional im letzten Stich)
	if t_ch == 100 and t_be == 100 and rules.dulle_second_wins:
		if not (is_last_trick and rules.dulle_last_trick_exception):
			return true
		return false

	if t_ch > 0 and t_be > 0:
		return t_ch > t_be
	if t_ch > 0 and t_be == 0:
		return true
	if t_ch == 0 and t_be > 0:
		return false

	# Beide Fehlfarbe: nur gleiche Farbe wie Angespieltes (current_best) zaehlt
	if challenger.suit == current_best.suit:
		return _fehl_order(challenger) > _fehl_order(current_best)
	return false


func _check_hochzeit_clarification(winner: int) -> void:
	if trick_count >= 2: # spaetestens 3. Stich (0-indexed: 2) -> Zerrissene Hochzeit
		hochzeit_clarified = true
		if winner != hochzeit_seat:
			re_seats = [hochzeit_seat, winner]
			_rebuild_kontra()
		return

	var is_trump_lead := is_trump(trick_cards[0].card)
	var matches := false
	match rules.hochzeit_clarification:
		0: matches = (winner != hochzeit_seat) # Erster fremder Stich
		1: matches = (winner != hochzeit_seat and not is_trump_lead) # Erster fremder Fehlstich
		2: matches = true # Erster Stich ueberhaupt

	if matches:
		hochzeit_clarified = true
		if winner != hochzeit_seat:
			re_seats = [hochzeit_seat, winner]
			_rebuild_kontra()


func _rebuild_kontra() -> void:
	kontra_seats.clear()
	for s in range(4):
		if not re_seats.has(s):
			kontra_seats.append(s)


func _record_trick_specials(winner: int, trick_pts: int) -> void:
	var winner_is_re := re_seats.has(winner)
	var winner_side := "re" if winner_is_re else "kontra"

	# Doppelkopf (>= 40 Augen)
	if trick_pts >= 40 and solo_kind == "":
		special_events.append({"type": "doppelkopf", "side": winner_side, "seat": winner, "points": 1, "detail": "Doppelkopf (%d Augen)" % trick_pts})

	# Fuchs gefangen (Normalspiel)
	if solo_kind == "" and rules.fuchs_gefangen_point:
		for entry in trick_cards:
			if entry.card.is_fox() and re_seats.has(int(entry.seat)) != winner_is_re:
				special_events.append({"type": "fuchs", "side": winner_side, "seat": winner, "points": 1, "detail": "Fuchs gefangen!"})

	# Letzter Stich: Fuchs am Pin & Karlchen
	if trick_count == total_tricks - 1 and solo_kind == "":
		if rules.fuchs_am_pin:
			for entry in trick_cards:
				if entry.card.is_fox() and int(entry.seat) == winner:
					special_events.append({"type": "fuchs_am_pin", "side": winner_side, "seat": winner, "points": 1, "detail": "Fuchs am Pin!"})
		for entry in trick_cards:
			if entry.card.is_karlchen():
				var k_seat := int(entry.seat)
				if k_seat == winner and rules.karlchen_last_trick:
					special_events.append({"type": "karlchen", "side": winner_side, "seat": winner, "points": 1, "detail": "Karlchen am End!"})
				elif k_seat != winner and rules.karlchen_gefangen and re_seats.has(k_seat) != winner_is_re:
					var win_card: CardData = _winning_card_in_trick()
					var valid_catcher := rules.karlchen_gefangen_all_higher or (win_card.rank == CardData.Rank.QUEEN or win_card.is_fox())
					if valid_catcher:
						special_events.append({"type": "karlchen_gefangen", "side": winner_side, "seat": winner, "points": 1, "detail": "Karlchen gefangen!"})


func _winning_card_in_trick() -> CardData:
	var best_card: CardData = trick_cards[0].card
	var is_last := (trick_count == total_tricks - 1)
	for i in range(1, 4):
		if _beats(trick_cards[i].card, best_card, is_last):
			best_card = trick_cards[i].card
	return best_card


func calculate_round_score() -> Dictionary:
	var re_pts := 0
	for s in re_seats:
		re_pts += captured_points.get(s, 0)
	var kontra_pts := 240 - re_pts

	var winner_side := "draw"
	if re_pts > 120:
		winner_side = "re"
	elif kontra_pts >= 120:
		# Kontra gewinnt bei 120:120, sofern keine besonderen Ansagen
		if re_pts == 120 and not announcements["re"] and not announcements["kontra"]:
			winner_side = "draw"
		else:
			winner_side = "kontra"

	var base_pts := 0
	var breakdown: Array[String] = []
	if winner_side != "draw":
		base_pts += 1
		breakdown.append("Gewonnen (+1)")
		var loser_pts := kontra_pts if winner_side == "re" else re_pts
		if loser_pts < 90:
			base_pts += 1
			breakdown.append("Keine 90 (+1)")
		if loser_pts < 60:
			base_pts += 1
			breakdown.append("Keine 60 (+1)")
		if loser_pts < 30:
			base_pts += 1
			breakdown.append("Keine 30 (+1)")
		if loser_pts == 0:
			base_pts += 1
			breakdown.append("Schwarz (+1)")
		if winner_side == "kontra" and solo_kind == "":
			base_pts += 1
			breakdown.append("Gegen die Alten (+1)")

	if announcements["re"]:
		base_pts += 2
		breakdown.append("Re angesagt (+2)")
	if announcements["kontra"]:
		base_pts += 2
		breakdown.append("Kontra angesagt (+2)")

	var special_net := 0
	for ev in special_events:
		var pts := int(ev.get("points", 0))
		if pts <= 0:
			continue
		if ev.get("side", "") == winner_side:
			special_net += pts
		else:
			special_net -= pts
		breakdown.append("%s (%s)" % [ev.get("detail", ""), ev.get("side", "")])

	var raw_total := maxi(0, base_pts + special_net) if winner_side != "draw" else 0
	var final_total := raw_total * bock_multiplier

	var deltas: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0}
	if winner_side != "draw":
		for s in range(4):
			var is_w := (winner_side == "re" and re_seats.has(s)) or (winner_side == "kontra" and kontra_seats.has(s))
			if solo_kind != "" or is_stille_hochzeit:
				if re_seats.has(s):
					deltas[s] = final_total * 3 if winner_side == "re" else -final_total * 3
				else:
					deltas[s] = final_total if winner_side == "kontra" else -final_total
			else:
				deltas[s] = final_total if is_w else -final_total

	# Bock-Trigger pruefen
	var bock_triggered: Array[String] = []
	if rules.bock_triggers.get("spaltarsch_120", false) and re_pts == 120:
		bock_triggered.append("120:120 Spaltarsch")
	if rules.bock_triggers.get("solo_played", false) and solo_kind != "":
		bock_triggered.append("Solo gespielt")
	if rules.bock_triggers.get("lost_re_kontra", false) and ((announcements["re"] and winner_side == "kontra") or (announcements["kontra"] and winner_side == "re")):
		bock_triggered.append("Re/Kontra verloren")

	last_round_result = {
		"schmeissen": false,
		"re_points": re_pts,
		"kontra_points": kontra_pts,
		"winner_side": winner_side,
		"base_points": base_pts,
		"special_net": special_net,
		"bock_multiplier": bock_multiplier,
		"total_points": final_total,
		"re_seats": re_seats.duplicate(),
		"kontra_seats": kontra_seats.duplicate(),
		"is_solo": solo_kind != "",
		"solo_kind": solo_kind,
		"solo_seat": solo_seat,
		"deltas": deltas,
		"breakdown": breakdown,
		"special_events": special_events.duplicate(),
		"bock_triggered": bock_triggered,
	}
	return last_round_result


func build_state_for_seat(seat: int) -> Dictionary:
	var my_hand_dicts: Array[Dictionary] = []
	for c in hands.get(seat, []):
		my_hand_dicts.append(c.to_dict())

	var legal_ids: Array[String] = []
	if phase == Phase.PLAYING and current_turn == seat:
		for c in get_legal_cards(seat):
			legal_ids.append(c.id)

	var other_counts: Dictionary = {}
	for s in range(4):
		other_counts[s] = hands.get(s, []).size()

	var trick_dicts: Array[Dictionary] = []
	for entry in trick_cards:
		trick_dicts.append({"seat": entry.seat, "card": entry.card.to_dict()})

	return {
		"phase": phase,
		"seat": seat,
		"players": all_players.duplicate(),
		"active_seats": active_seats.duplicate(),
		"dealer_index": dealer_index,
		"current_turn": current_turn,
		"trick_leader": trick_leader,
		"trick_count": trick_count,
		"total_tricks": total_tricks,
		"bock_multiplier": bock_multiplier,
		"solo_kind": solo_kind,
		"solo_seat": solo_seat,
		"is_hochzeit": is_hochzeit,
		"hochzeit_seat": hochzeit_seat,
		"my_hand": my_hand_dicts,
		"legal_ids": legal_ids,
		"hand_counts": other_counts,
		"trick_cards": trick_dicts,
		"announcements": announcements.duplicate(),
		"can_schmeissen": can_schmeissen(seat),
		"has_hochzeit": has_hochzeit(seat),
		"has_armut": has_armut(seat),
		"last_round_result": last_round_result.duplicate(),
		"special_events": special_events.duplicate(),
	}


func _find_card_in_hand(seat: int, id: String) -> CardData:
	for c in hands.get(seat, []):
		if c.id == id:
			return c
	return null
