class_name DokoBot
extends RefCounted

## Intelligente KI fuer fehlende Mitspieler am Doppelkopf-Tisch.


static func choose_vorbehalt(engine: DokoEngine, seat: int) -> Dictionary:
	var hand: Array = engine.hands.get(seat, [])
	if engine.can_schmeissen(seat) != "":
		return {"choice": "schmeissen", "solo_kind": ""}

	# Solo pruefen: z.B. 6+ Damen -> Damensolo, 6+ Buben -> Bubensolo, 7+ Trumpf in einer Farbe -> Farbsolo
	var queens := 0
	var jacks := 0
	var trumps := 0
	for c in hand:
		if c.rank == CardData.Rank.QUEEN:
			queens += 1
		elif c.rank == CardData.Rank.JACK:
			jacks += 1
		if engine.is_trump(c, ""):
			trumps += 1

	if queens >= 6 and engine.rules.soli_enabled.get("damen", false):
		return {"choice": "solo", "solo_kind": "damen"}
	if jacks >= 6 and engine.rules.soli_enabled.get("buben", false):
		return {"choice": "solo", "solo_kind": "buben"}

	if engine.has_hochzeit(seat):
		return {"choice": "hochzeit", "solo_kind": ""}
	if engine.has_armut(seat):
		return {"choice": "armut", "solo_kind": ""}

	# Sehr viele Truempfe -> ggf. Karosolo
	if trumps >= 9 and engine.rules.soli_enabled.get("karo", false):
		return {"choice": "solo", "solo_kind": "karo"}

	return {"choice": "gesund", "solo_kind": ""}


static func maybe_make_announcement(engine: DokoEngine, seat: int) -> String:
	var hand: Array = engine.hands.get(seat, [])
	if hand.size() < engine.total_tricks - 1:
		return ""
	var high_trumps := 0
	for c in hand:
		if engine.trump_order(c) >= 80:
			high_trumps += 1
	var is_re := engine.re_seats.has(seat)
	if is_re and not engine.announcements.get("re", false) and high_trumps >= 4:
		return "re"
	if not is_re and not engine.announcements.get("kontra", false) and high_trumps >= 4:
		return "kontra"
	return ""


static func choose_card(engine: DokoEngine, seat: int) -> String:
	var legal := engine.get_legal_cards(seat)
	if legal.is_empty():
		return ""
	if legal.size() == 1:
		return legal[0].id

	# 1. Anspieler: Fehlass oder kleinen Trumpf / hoechsten Trumpf
	if engine.trick_cards.is_empty():
		for c in legal:
			if not engine.is_trump(c) and c.rank == CardData.Rank.ACE:
				return c.id
		# Kleinsten Trumpf oder kleinste Fehlfarbe
		var best := legal[0]
		for c in legal:
			if c.points() < best.points():
				best = c
		return best.id

	# 2. Bedienen / Stechen: Aktuell fuehrende Karte finden
	var best_entry: Dictionary = engine.trick_cards[0]
	var best_card: CardData = best_entry.card
	var is_last := (engine.trick_count == engine.total_tricks - 1)
	for i in range(1, engine.trick_cards.size()):
		var c: CardData = engine.trick_cards[i].card
		if engine._beats(c, best_card, is_last):
			best_card = c
			best_entry = engine.trick_cards[i]

	var leader_seat := int(best_entry.seat)
	var partner_leading := (engine.re_seats.has(seat) == engine.re_seats.has(leader_seat))

	if partner_leading:
		# Schmieren: Hoechste Punktzahl (ausser Fuchs/Dulle) oder kleinste Karte
		var smear: CardData = null
		for c in legal:
			if not c.is_fox() and not c.is_dulle():
				if smear == null or c.points() > smear.points():
					smear = c
		return smear.id if smear != null else legal[0].id

	# Gegner fuehrt: Mit kleinstmoeglicher Gewinnkarte stechen
	var winning_choices: Array[CardData] = []
	for c in legal:
		if engine._beats(c, best_card, is_last):
			winning_choices.append(c)

	if not winning_choices.is_empty():
		var cheapest := winning_choices[0]
		for c in winning_choices:
			if engine.trump_order(c) < engine.trump_order(cheapest):
				cheapest = c
		return cheapest.id

	# Kann nicht stechen: Fuchs schuetzen, kleinste Punkte abwerfen
	var dump := legal[0]
	for c in legal:
		if c.is_fox() and not dump.is_fox():
			continue
		if dump.is_fox() and not c.is_fox():
			dump = c
		elif c.points() < dump.points():
			dump = c
	return dump.id
