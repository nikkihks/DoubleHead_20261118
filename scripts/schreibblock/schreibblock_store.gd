extends Node

# scripts/schreibblock/schreibblock_store.gd
# Autoload: SchreibblockStore

const SAVE_PATH = "user://schreibblock_db.json"

# Hauptdatenstruktur
var sessions: Array = []
var active_session_index: int = -1

func _ready() -> void:
	load_data()

# --- PERSISTENZ ---

func save_data() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(sessions)
		file.store_string(json_string)
		file.close()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		sessions = []
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			sessions = json.get_data()
		file.close()

# --- SESSION MANAGEMENT ---

func create_session(title: String, players: Array[String], cents_per_point: float) -> void:
	var new_session = {
		"id": str(int(Time.get_unix_time_from_system())) + "_" + str(randi() % 10000),
		"title": title,
		"created_at": Time.get_datetime_string_from_system(),
		"players": players,
		"cents_per_point": cents_per_point,
		"bock_stacking": true,
		"bock_queue": [], # Enthält Multiplikatoren (z.B. [2, 2, 2, 2])
		"rounds": [],
		"dealer_index": 0
	}
	sessions.append(new_session)
	active_session_index = sessions.size() - 1
	save_data()

func get_active_session() -> Dictionary:
	if active_session_index >= 0 and active_session_index < sessions.size():
		return sessions[active_session_index]
	return {}

# --- RUNDEN LOGIK ---

func add_manual_round(data: Dictionary) -> void:
	_process_round(data)

func add_live_round(engine_result: Dictionary, players: Array[String]) -> void:
	# engine_result sollte Felder wie winner_side, points, announcements, extras enthalten
	engine_result["source"] = "live"
	_process_round(engine_result)

func _process_round(data: Dictionary) -> void:
	var session = get_active_session()
	if session.is_empty(): return

	var round_no = session.rounds.size() + 1
	var bock_multiplier = 1
	
	# Bock Logik: Wenn Queue nicht leer, nimm den ersten Multiplikator
	if not session.bock_queue.is_empty():
		bock_multiplier = session.bock_queue.pop_front()

	var points = data.get("points", 0)
	var total_points = points * bock_multiplier
	
	var re_players = data.get("re_players", [])
	var kontra_players = data.get("kontra_players", [])
	var winner_side = data.get("winner_side", "draw")
	
	# Delta Berechnung (Summe muss 0 sein)
	var deltas = {}
	for p in session.players:
		deltas[p] = 0
		
	if winner_side != "draw":
		var winners = re_players if winner_side == "re" else kontra_players
		var losers = kontra_players if winner_side == "re" else re_players
		
		if data.get("is_solo", false):
			var solo_player = data.get("solo_player", "")
			# Solo: Gewinner bekommt Punkte von allen (3 Gegnern im 4er Spiel)
			# Hier vereinfacht: Solo-Spieler vs. alle anderen aktiven Kontra-Spieler
			var opponent_count = losers.size()
			deltas[solo_player] = total_points * opponent_count
			for p in losers:
				deltas[p] = -total_points
		else:
			# Normales Spiel
			for p in winners:
				deltas[p] = total_points
			for p in losers:
				deltas[p] = -total_points

	var round_dict = {
		"round_no": round_no,
		"winner_side": winner_side,
		"points": points,
		"bock_multiplier": bock_multiplier,
		"total_points": total_points,
		"re_players": re_players,
		"kontra_players": kontra_players,
		"is_solo": data.get("is_solo", false),
		"solo_kind": data.get("solo_kind", "none"),
		"solo_player": data.get("solo_player", ""),
		"announcements": data.get("announcements", []),
		"extras": data.get("extras", {}),
		"deltas": deltas,
		"source": data.get("source", "manual")
	}
	
	session.rounds.append(round_dict)
	session.dealer_index = (session.dealer_index + 1) % session.players.size()
	save_data()

func trigger_manual_bock(count: int = 1) -> void:
	var session = get_active_session()
	if session.is_empty(): return
	
	# Ein Bock bedeutet meistens: Die nächsten N Spiele (N = Spieleranzahl) sind doppelt
	var rounds_to_add = session.players.size() * count
	for i in range(rounds_to_add):
		session.bock_queue.append(2)
	save_data()

func undo_last_round() -> bool:
	var session = get_active_session()
	if session.is_empty() or session.rounds.is_empty(): return false
	
	var last_round = session.rounds.pop_back()
	# Dealer zurücksetzen
	session.dealer_index = (session.dealer_index - 1 + session.players.size()) % session.players.size()
	
	# Falls die Runde einen Bock verbraucht hat, diesen theoretisch wieder vorne anstellen
	# (Vereinfachung: Wir fügen ihn wieder ein, wenn er nicht 1 war)
	if last_round.bock_multiplier > 1:
		session.bock_queue.push_front(last_round.bock_multiplier)
		
	save_data()
	return true

# --- STATISTIKEN & AUSWERTUNG ---

func get_cumulative_series() -> Dictionary:
	var session = get_active_session()
	var series = {}
	if session.is_empty(): return series
	
	for p in session.players:
		series[p] = [0] # Start bei 0
		
	for r in session.rounds:
		for p in session.players:
			var last_val = series[p][-1]
			series[p].append(last_val + r.deltas.get(p, 0))
			
	return series

func get_player_stats() -> Dictionary:
	var session = get_active_session()
	var stats = {}
	if session.is_empty(): return stats
	
	for p in session.players:
		stats[p] = {
			"games": 0, "wins": 0, "win_rate": 0.0,
			"soli": 0, "re_count": 0, "points": 0, "euro": 0.0
		}
		
	for r in session.rounds:
		for p in session.players:
			var d = r.deltas.get(p, 0)
			stats[p].points += d
			
			# War der Spieler in dieser Runde aktiv?
			if p in r.re_players or p in r.kontra_players:
				stats[p].games += 1
				if d > 0: stats[p].wins += 1
				if p in r.re_players: stats[p].re_count += 1
				if r.is_solo and r.solo_player == p: stats[p].soli += 1
				
	for p in session.players:
		if stats[p].games > 0:
			stats[p].win_rate = float(stats[p].wins) / stats[p].games
		stats[p].euro = stats[p].points * (session.cents_per_point / 100.0)
		
	return stats

func get_settlement_transfers() -> Array[Dictionary]:
	var stats = get_player_stats()
	var balances = []
	for p in stats:
		balances.append({"name": p, "amount": stats[p].euro})
	
	# Sortiere: Wer am meisten bekommt nach oben, wer am meisten zahlt nach unten
	balances.sort_custom(func(a, b): return a.amount > b.amount)
	
	var transfers: Array[Dictionary] = []
	var i = 0
	var j = balances.size() - 1
	
	# Greedy Algorithmus zum Ausgleich
	while i < j:
		var giver = balances[j]
		var receiver = balances[i]
		var amount = min(abs(giver.amount), receiver.amount)
		
		if amount > 0.01:
			transfers.append({
				"from": giver.name,
				"to": receiver.name,
				"amount": amount
			})
			
		balances[i].amount -= amount
		balances[j].amount += amount
		
		if balances[i].amount < 0.01: i += 1
		if abs(balances[j].amount) < 0.01: j -= 1
			
	return transfers

# --- IMPORT / EXPORT ---

func export_session_json() -> String:
	var session = get_active_session()
	return JSON.stringify(session, "\t")

func import_session_json(json_str: String) -> bool:
	var json = JSON.new()
	if json.parse(json_str) == OK:
		var data = json.get_data()
		if data is Dictionary and data.has("rounds"):
			sessions.append(data)
			active_session_index = sessions.size() - 1
			save_data()
			return true
	return false
