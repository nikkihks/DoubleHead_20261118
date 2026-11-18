class_name CardData extends RefCounted

enum Suit { CLUBS, SPADES, HEARTS, DIAMONDS }
enum Rank { NINE, JACK, QUEEN, KING, TEN, ACE }

var id: String
var suit: Suit
var rank: Rank
var copy: int

func _init(p_suit: Suit = Suit.CLUBS, p_rank: Rank = Rank.NINE, p_copy: int = 0) -> void:
	suit = p_suit
	rank = p_rank
	copy = p_copy
	id = "%s_%s_%d" % [Suit.keys()[suit][0], Rank.keys()[rank][0], copy]

func points() -> int:
	match rank:
		Rank.ACE: return 11
		Rank.TEN: return 10
		Rank.KING: return 4
		Rank.QUEEN: return 3
		Rank.JACK: return 2
		Rank.NINE: return 0
	return 0

func short_name() -> String:
	var r_str: String = ""
	match rank:
		Rank.NINE: r_str = "9"
		Rank.JACK: r_str = "B"
		Rank.QUEEN: r_str = "D"
		Rank.KING: r_str = "K"
		Rank.TEN: r_str = "10"
		Rank.ACE: r_str = "A"
	return suit_symbol() + r_str

func display_name() -> String:
	var s_name: String = ""
	match suit:
		Suit.CLUBS: s_name = "Kreuz"
		Suit.SPADES: s_name = "Pik"
		Suit.HEARTS: s_name = "Herz"
		Suit.DIAMONDS: s_name = "Karo"
	
	var r_name: String = ""
	match rank:
		Rank.NINE: r_name = "Neun"
		Rank.JACK: r_name = "Bube"
		Rank.QUEEN: r_name = "Dame"
		Rank.KING: r_name = "König"
		Rank.TEN: r_name = "Zehn"
		Rank.ACE: r_name = "Ass"
	
	return s_name + " " + r_name

func suit_symbol() -> String:
	match suit:
		Suit.CLUBS: return "♣"
		Suit.SPADES: return "♠"
		Suit.HEARTS: return "♥"
		Suit.DIAMONDS: return "♦"
	return "?"

func is_fox() -> bool:
	return suit == Suit.DIAMONDS and rank == Rank.ACE

func is_dulle() -> bool:
	return suit == Suit.HEARTS and rank == Rank.TEN

func is_karlchen() -> bool:
	return suit == Suit.CLUBS and rank == Rank.JACK

func is_alte() -> bool:
	return suit == Suit.CLUBS and rank == Rank.QUEEN

func to_dict() -> Dictionary:
	return {
		"id": id,
		"suit": suit,
		"rank": rank,
		"copy": copy
	}

static func from_dict(d: Dictionary) -> CardData:
	var card := CardData.new(d.get("suit", 0) as Suit, d.get("rank", 0) as Rank, d.get("copy", 0) as int)
	card.id = d.get("id", card.id)
	return card

static func create_deck(with_nines: bool) -> Array[CardData]:
	var deck: Array[CardData] = []
	for s in [Suit.CLUBS, Suit.SPADES, Suit.HEARTS, Suit.DIAMONDS]:
		for r in [Rank.NINE, Rank.JACK, Rank.QUEEN, Rank.KING, Rank.TEN, Rank.ACE]:
			if not with_nines and r == Rank.NINE:
				continue
			for c in range(2):
				deck.append(CardData.new(s as Suit, r as Rank, c))
	return deck
