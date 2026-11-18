class_name RuleConfig extends RefCounted

var preset_name: String = "Custom"
var with_nines: bool = true
var dulle_second_wins: bool = true
var dulle_last_trick_exception: bool = false
var schweinchen_mode: int = 0 # 0=Aus, 1=Spielbeginn, 2=Erster Fuchs
var superschweinchen: bool = false
var fuchs_gefangen_point: bool = true
var fuchs_am_pin: bool = false
var karlchen_last_trick: bool = true
var karlchen_gefangen: bool = true
var karlchen_gefangen_all_higher: bool = false
var hochzeit_clarification: int = 0 # 0=Erster fremder Stich, 1=Erster fremder Fehlstich, 2=Erster Stich
var stille_hochzeit: bool = true
var armut_enabled: bool = true
var schmeissen_5_nines: bool = true
var schmeissen_5_kings: bool = true
var schmeissen_9_and_k: bool = false
var schmeissen_lt3_trump: bool = false
var schmeissen_no_face: bool = false

var soli_enabled: Dictionary = {
	"damen": true,
	"buben": true,
	"karo": true,
	"herz": true,
	"pik": true,
	"kreuz": true,
	"fleischlos": true,
	"koenig": false,
	"damen_buben": false
}

var pflichtsolo_enabled: bool = false

var bock_triggers: Dictionary = {
	"spaltarsch_120": false,
	"lost_re_kontra": true,
	"solo_played": false,
	"torn_hochzeit": false,
	"heart_goes_through": false,
	"manual_knock": false
}

var bock_stacking: bool = true

func to_dict() -> Dictionary:
	return {
		"preset_name": preset_name,
		"with_nines": with_nines,
		"dulle_second_wins": dulle_second_wins,
		"dulle_last_trick_exception": dulle_last_trick_exception,
		"schweinchen_mode": schweinchen_mode,
		"superschweinchen": superschweinchen,
		"fuchs_gefangen_point": fuchs_gefangen_point,
		"fuchs_am_pin": fuchs_am_pin,
		"karlchen_last_trick": karlchen_last_trick,
		"karlchen_gefangen": karlchen_gefangen,
		"karlchen_gefangen_all_higher": karlchen_gefangen_all_higher,
		"hochzeit_clarification": hochzeit_clarification,
		"stille_hochzeit": stille_hochzeit,
		"armut_enabled": armut_enabled,
		"schmeissen_5_nines": schmeissen_5_nines,
		"schmeissen_5_kings": schmeissen_5_kings,
		"schmeissen_9_and_k": schmeissen_9_and_k,
		"schmeissen_lt3_trump": schmeissen_lt3_trump,
		"schmeissen_no_face": schmeissen_no_face,
		"soli_enabled": soli_enabled,
		"pflichtsolo_enabled": pflichtsolo_enabled,
		"bock_triggers": bock_triggers,
		"bock_stacking": bock_stacking
	}

static func from_dict(d: Dictionary) -> RuleConfig:
	var cfg := RuleConfig.new()
	for key in d.keys():
		if key in cfg:
			if typeof(d[key]) == TYPE_DICTIONARY:
				(cfg.get(key) as Dictionary).merge(d[key], true)
			else:
				cfg.set(key, d[key])
	return cfg

static func preset(p_name: String) -> RuleConfig:
	var cfg := RuleConfig.new()
	cfg.preset_name = p_name
	
	match p_name:
		"DDV Turnier":
			cfg.with_nines = false
			cfg.dulle_second_wins = false
			cfg.schweinchen_mode = 0
			cfg.fuchs_gefangen_point = true
			cfg.karlchen_last_trick = true
			cfg.karlchen_gefangen = false
			cfg.hochzeit_clarification = 0
			cfg.armut_enabled = true
			cfg.schmeissen_5_nines = false
			cfg.schmeissen_5_kings = false
			cfg.soli_enabled["koenig"] = false
			cfg.bock_triggers["lost_re_kontra"] = false
			
		"Kneipen-Standard":
			cfg.with_nines = true
			cfg.dulle_second_wins = true
			cfg.schweinchen_mode = 1
			cfg.fuchs_gefangen_point = true
			cfg.karlchen_last_trick = true
			cfg.karlchen_gefangen = true
			cfg.hochzeit_clarification = 1
			cfg.schmeissen_5_nines = true
			cfg.schmeissen_5_kings = true
			cfg.bock_triggers["lost_re_kontra"] = true
			
		"Scharf (Ohne 9er)":
			cfg.with_nines = false
			cfg.dulle_second_wins = true
			cfg.schweinchen_mode = 2
			cfg.superschweinchen = true
			cfg.fuchs_gefangen_point = true
			cfg.karlchen_last_trick = true
			cfg.karlchen_gefangen = true
			cfg.hochzeit_clarification = 1
			cfg.schmeissen_5_kings = true
			cfg.bock_triggers["lost_re_kontra"] = true
			cfg.bock_triggers["spaltarsch_120"] = true
			
	return cfg
