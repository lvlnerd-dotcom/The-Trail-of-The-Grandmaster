class_name BestiaryModal
extends PanelContainer

## BestiaryModal: Displays creature knowledge codex with tiered intelligence based on kill count.

signal closed()

@onready var item_list: ItemList = $VBox/HSplit/ItemList
@onready var label_creature_name: Label = $VBox/HSplit/DetailVBox/LabelCreatureName
@onready var label_creature_type: Label = $VBox/HSplit/DetailVBox/LabelCreatureType
@onready var label_kills_count: Label = $VBox/HSplit/DetailVBox/LabelKillsCount
@onready var label_knowledge_tier: Label = $VBox/HSplit/DetailVBox/LabelKnowledgeTier
@onready var text_tier1: RichTextLabel = $VBox/HSplit/DetailVBox/TextTier1
@onready var text_tier2: RichTextLabel = $VBox/HSplit/DetailVBox/TextTier2
@onready var text_tier3: RichTextLabel = $VBox/HSplit/DetailVBox/TextTier3
@onready var btn_close: Button = $VBox/BtnClose

const CREATURE_DATABASE: Dictionary = {
	"The Grandmaster": {
		"display_name": "The Grandmaster",
		"type": "Final Boss (Martial & Astral Ascendant)",
		"tier1": "HP: 450 | Base Soak: 8 | Master of the Floor 20 Sanctum.",
		"tier2": "Phase 1: Bulwark/Frenzy/Riposte stances.\nPhase 2 (<300 HP): 35 HP Arcane Ward, Ascendant Nova, Blink kiting, Fireball barrage & Radiant Smite.",
		"tier3": "Phase 3 (<150 HP): Spawns Shadow & Light Clones. Harmonic Equilibrium (alternates Physical/Magic immunity every 3 turns). 3.0x lethal crits. Guaranteed drop: Mantle of the Grandmaster."
	},
	"Skeleton Guard": {
		"display_name": "Skeleton Guard",
		"type": "Undead Sentinel",
		"tier1": "HP: 22-45 | Melee Dmg: 9-18 | Ancient skeletal sentinels patrolling dungeon corridors.",
		"tier2": "Defenses: Moderate armor soak (2-4), High parry with shield (45-60 skill). Resistant to piercing arrows; vulnerable to heavy bludgeoning maces.",
		"tier3": "Drop Table: Iron Shortswords, Ancient Relic Bones, 10-40 Gold. Completely immune to bleed and poison effects."
	},
	"Dungeon Goblin": {
		"display_name": "Dungeon Goblin",
		"type": "Humanoid Scavenger",
		"tier1": "HP: 16-36 | Melee Dmg: 7-15 | Agile tunnel stalkers hunting in packs.",
		"tier2": "Defenses: Low armor (0-1 soak), Dodge evasion specialist (35-50 skill). Vulnerable to heavy cleave and fire magic.",
		"tier3": "Drop Table: Crude Daggers, Rations, 5-25 Gold. Susceptible to intimidation and morale routs."
	},
	"Shadow of the Grandmaster": {
		"display_name": "Shadow of the Grandmaster",
		"type": "Spectral Manifestation",
		"tier1": "HP: 75 | Melee Dmg: 14 | Martial shadow manifestation summoned during Phase 3.",
		"tier2": "Defenses: High dodge evasion, relentlessly chases player with rapid melee strikes.",
		"tier3": "Dissolves immediately upon Grandmaster's demise. Purely offensive tactical distraction."
	},
	"Light of the Grandmaster": {
		"display_name": "Light of the Grandmaster",
		"type": "Astral Manifestation",
		"tier1": "HP: 75 | Ranged Dmg: 12 | Astral light entity summoned during Phase 3.",
		"tier2": "Abilities: Casts 12 dmg Radiant Bolts; Channels +15 HP holy restoration to Grandmaster when damaged.",
		"tier3": "Priority target: eliminate rapidly to prevent prolonged boss healing cycles."
	}
}

var _indexed_keys: Array[String] = []

func _ready() -> void:
	BaseModal.apply_opaque_styling(self)
	visible = false
	if btn_close:
		btn_close.pressed.connect(_on_close_pressed)
	if item_list:
		item_list.item_selected.connect(_on_item_selected)

func open_modal() -> void:
	visible = true
	_populate_list()
	if _indexed_keys.size() > 0:
		item_list.select(0)
		_display_creature(_indexed_keys[0])

func close_modal() -> void:
	visible = false
	emit_signal("closed")

func _on_close_pressed() -> void:
	close_modal()

func _get_meta_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("MetaManager")
	return null

func _populate_list() -> void:
	item_list.clear()
	_indexed_keys.clear()
	
	var records = {}
	var mm = _get_meta_mgr()
	if mm and mm.profile:
		records = mm.profile.bestiary_records
		
	# Populate database entries first
	for c_id in CREATURE_DATABASE.keys():
		_indexed_keys.append(c_id)
		var kills = 0
		var tier = 0
		if records.has(c_id):
			kills = int(records[c_id].get("kills", 0))
			tier = int(records[c_id].get("tier", 0))
		var title = "%s (Tier %d)" % [CREATURE_DATABASE[c_id]["display_name"], tier]
		item_list.add_item(title)
		
	# Check any additional custom records
	for c_id in records.keys():
		if not CREATURE_DATABASE.has(c_id):
			_indexed_keys.append(c_id)
			var kills = int(records[c_id].get("kills", 0))
			var tier = int(records[c_id].get("tier", 0))
			item_list.add_item("%s (Tier %d)" % [c_id, tier])

func _on_item_selected(index: int) -> void:
	if index >= 0 and index < _indexed_keys.size():
		_display_creature(_indexed_keys[index])

func _display_creature(creature_id: String) -> void:
	var records = {}
	var mm = _get_meta_mgr()
	if mm and mm.profile:
		records = mm.profile.bestiary_records
		
	var kills = 0
	var tier = 0
	if records.has(creature_id):
		kills = int(records[creature_id].get("kills", 0))
		tier = int(records[creature_id].get("tier", 0))
		
	var db_entry = CREATURE_DATABASE.get(creature_id, {
		"display_name": creature_id,
		"type": "Unknown Encounter",
		"tier1": "Encountered in the depths of the Trail.",
		"tier2": "Detailed defensive attributes pending further combat logs.",
		"tier3": "Drop tables and tactical weaknesses pending mastery."
	})
	
	label_creature_name.text = db_entry["display_name"]
	label_creature_type.text = "Classification: %s" % db_entry["type"]
	label_kills_count.text = "Total Slain: %d" % kills
	
	var tier_names = ["Tier 0: Undiscovered", "Tier 1: Novice Knowledge", "Tier 2: Tactical Defenses Unlocked", "Tier 3: Master Codex & Drops"]
	var tier_colors = [Color(0.6, 0.6, 0.6), Color(0.4, 0.8, 1.0), Color(0.3, 1.0, 0.5), Color(1.0, 0.85, 0.2)]
	label_knowledge_tier.text = tier_names[clampi(tier, 0, 3)]
	label_knowledge_tier.add_theme_color_override("font_color", tier_colors[clampi(tier, 0, 3)])
	
	# Tier 1 Info
	if tier >= 1:
		text_tier1.text = "[b]Basic Stats & Vitals:[/b]\n%s" % db_entry["tier1"]
	else:
		text_tier1.text = "[color=gray][i]Classified (Slay 1 to uncover vitals)[/i][/color]"
		
	# Tier 2 Info
	if tier >= 2:
		text_tier2.text = "[b]Combat Defenses & Vulnerabilities:[/b]\n%s" % db_entry["tier2"]
	else:
		text_tier2.text = "[color=gray][i]Classified (Slay 5 to uncover defensive ratings)[/i][/color]"
		
	# Tier 3 Info
	if tier >= 3:
		text_tier3.text = "[b]Codex Mastery & Drop Tables:[/b]\n%s" % db_entry["tier3"]
	else:
		text_tier3.text = "[color=gray][i]Classified (Slay 15 to master codex and loot tables)[/i][/color]"
