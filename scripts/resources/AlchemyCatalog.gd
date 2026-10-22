class_name AlchemyCatalog
extends RefCounted

## AlchemyCatalog: Manages randomized run-scoped potion appearances, identification checks
## (Scholarship / Alchemy), dungeon reagents, and portable Mortar and Pestle crafting recipes.

const POTION_APPEARANCES: Array[String] = [
	"Murky Blue Liquid",
	"Bubbling Crimson Vial",
	"Viscous Amber Draught",
	"Smoking Viridian Brew",
	"Sparkling Violet Phial",
	"Oily Black Flask",
	"Phosphorescent Emerald Tonic",
	"Swirling Silver Elixir",
	"Frothing Ochre Draught",
	"Effervescent Golden Nectar",
	"Cloudy White Philter",
	"Shimmering Cerulean Potion",
	"Viscous Indigo Brew",
	"Fuming Ashen Liquid",
	"Prismatic Sparkling Tonic"
]

const BENEFICIAL_POTIONS: Array[String] = [
	"potion_heal_minor",
	"potion_heal_standard",
	"potion_heal_greater",
	"potion_mana",
	"potion_giant_strength",
	"potion_haste",
	"potion_antidote",
	"potion_invisibility"
]

const HARMFUL_POTIONS: Array[String] = [
	"potion_poison_minor",
	"potion_poison_standard",
	"potion_poison_greater",
	"potion_alchemist_fire",
	"potion_acid",
	"potion_blindness",
	"potion_weakness"
]

const POTION_DEFINITIONS: Dictionary = {
	"potion_heal_minor": {
		"name": "Minor Healing Potion",
		"is_beneficial": true,
		"identify_difficulty": 15,
		"effect_type": "heal",
		"effect_val": 25,
		"description": "Restores 25 Health Points instantly."
	},
	"potion_heal_standard": {
		"name": "Standard Healing Potion",
		"is_beneficial": true,
		"identify_difficulty": 25,
		"effect_type": "heal",
		"effect_val": 50,
		"description": "Restores 50 Health Points instantly."
	},
	"potion_heal_greater": {
		"name": "Greater Healing Potion",
		"is_beneficial": true,
		"identify_difficulty": 40,
		"effect_type": "heal",
		"effect_val": 100,
		"description": "Restores 100 Health Points instantly."
	},
	"potion_mana": {
		"name": "Mana Draught",
		"is_beneficial": true,
		"identify_difficulty": 20,
		"effect_type": "mana",
		"effect_val": 40,
		"description": "Restores 40 Mana Points instantly."
	},
	"potion_giant_strength": {
		"name": "Potion of Giant Strength",
		"is_beneficial": true,
		"identify_difficulty": 30,
		"effect_type": "giant_strength",
		"effect_val": 5,
		"duration": 20,
		"description": "Increases Strength by +5 for 20 turns."
	},
	"potion_haste": {
		"name": "Potion of Haste",
		"is_beneficial": true,
		"identify_difficulty": 35,
		"effect_type": "haste",
		"effect_val": 1,
		"duration": 10,
		"description": "Grants an additional action per turn for 10 turns."
	},
	"potion_antidote": {
		"name": "Alchemical Antidote",
		"is_beneficial": true,
		"identify_difficulty": 15,
		"effect_type": "cure_poison",
		"effect_val": 0,
		"description": "Instantly purges all poison and acid from the bloodstream."
	},
	"potion_invisibility": {
		"name": "Potion of Invisibility",
		"is_beneficial": true,
		"identify_difficulty": 35,
		"effect_type": "invisibility",
		"effect_val": 1,
		"duration": 10,
		"description": "Renders the drinker invisible to monsters for 10 turns."
	},
	"potion_poison_minor": {
		"name": "Minor Poison Vial",
		"is_beneficial": false,
		"identify_difficulty": 15,
		"effect_type": "poison",
		"tier": 1,
		"duration": 5,
		"description": "Deadly venom inflicting Minor Poison (3 damage/turn for 5 turns)."
	},
	"potion_poison_standard": {
		"name": "Standard Poison Vial",
		"is_beneficial": false,
		"identify_difficulty": 25,
		"effect_type": "poison",
		"tier": 2,
		"duration": 5,
		"description": "Potent venom inflicting Standard Poison (7 damage/turn for 5 turns)."
	},
	"potion_poison_greater": {
		"name": "Greater Poison Vial",
		"is_beneficial": false,
		"identify_difficulty": 40,
		"effect_type": "poison",
		"tier": 3,
		"duration": 5,
		"description": "Lethal venom inflicting Greater Poison (15 damage/turn for 5 turns)."
	},
	"potion_alchemist_fire": {
		"name": "Alchemist's Fire Flask",
		"is_beneficial": false,
		"identify_difficulty": 25,
		"effect_type": "fire_aoe",
		"effect_val": 20,
		"area_radius": 1,
		"description": "Volatile liquid igniting on contact, dealing 15-25 Fire damage in a 3x3 blast."
	},
	"potion_acid": {
		"name": "Corrosive Acid Flask",
		"is_beneficial": false,
		"identify_difficulty": 20,
		"effect_type": "acid",
		"effect_val": 15,
		"description": "Corrosive solvent dealing 15 Acid damage and eroding armor."
	},
	"potion_blindness": {
		"name": "Blindness Brew",
		"is_beneficial": false,
		"identify_difficulty": 25,
		"effect_type": "blindness",
		"effect_val": 1,
		"duration": 10,
		"description": "Induces acute blindness for 10 turns, reducing sight to 1 tile and -30% accuracy."
	},
	"potion_weakness": {
		"name": "Weakness Draught",
		"is_beneficial": false,
		"identify_difficulty": 25,
		"effect_type": "weakness",
		"effect_val": 5,
		"duration": 15,
		"description": "Saps physical vigor, reducing Strength by 5 for 15 turns."
	}
}

const REAGENTS: Dictionary = {
	"reagent_sunpetal": {
		"name": "Sunpetal",
		"description": "Luminescent yellow flower with soothing regenerative properties.",
		"weight": 0.1,
		"base_val": 8
	},
	"reagent_nightshade": {
		"name": "Nightshade",
		"description": "Dark purple subterranean berry steeped in neurotoxic essence.",
		"weight": 0.1,
		"base_val": 8
	},
	"reagent_bloodmoss": {
		"name": "Cave Bloodmoss",
		"description": "Crimson fibrous moss thriving near ancient mineral deposits.",
		"weight": 0.1,
		"base_val": 10
	},
	"reagent_crystal_ash": {
		"name": "Crystalline Ash",
		"description": "Fine luminescent powder harvested from powdered deep geodes.",
		"weight": 0.1,
		"base_val": 12
	},
	"reagent_venom_gland": {
		"name": "Venom Gland",
		"description": "Carefully excised gland brimming with concentrated arachnid toxin.",
		"weight": 0.2,
		"base_val": 15
	}
}

const RECIPES: Array[Dictionary] = [
	{
		"recipe_id": "craft_heal",
		"name": "Healing Potion",
		"result_potion_id": "potion_heal_standard",
		"ingredients": { "reagent_sunpetal": 1, "reagent_bloodmoss": 1 },
		"difficulty": 20,
		"description": "Combines Sunpetal and Cave Bloodmoss to brew a restorative Healing Potion."
	},
	{
		"recipe_id": "craft_antidote",
		"name": "Alchemical Antidote",
		"result_potion_id": "potion_antidote",
		"ingredients": { "reagent_sunpetal": 1, "reagent_crystal_ash": 1 },
		"difficulty": 20,
		"description": "Combines Sunpetal and Crystalline Ash into a cleansing Antidote."
	},
	{
		"recipe_id": "craft_fire",
		"name": "Alchemist's Fire",
		"result_potion_id": "potion_alchemist_fire",
		"ingredients": { "reagent_crystal_ash": 1, "reagent_bloodmoss": 1 },
		"difficulty": 25,
		"description": "Combines Crystalline Ash and Cave Bloodmoss into volatile Alchemist Fire."
	},
	{
		"recipe_id": "craft_poison",
		"name": "Poison Vial",
		"result_potion_id": "potion_poison_standard",
		"ingredients": { "reagent_nightshade": 1, "reagent_venom_gland": 1 },
		"difficulty": 25,
		"description": "Combines Nightshade and Venom Gland to extract deadly Poison."
	},
	{
		"recipe_id": "craft_mana",
		"name": "Mana Draught",
		"result_potion_id": "potion_mana",
		"ingredients": { "reagent_nightshade": 1, "reagent_crystal_ash": 1 },
		"difficulty": 25,
		"description": "Combines Nightshade and Crystalline Ash to brew an arcane Mana Draught."
	},
	{
		"recipe_id": "craft_strength",
		"name": "Potion of Giant Strength",
		"result_potion_id": "potion_giant_strength",
		"ingredients": { "reagent_bloodmoss": 1, "reagent_venom_gland": 1 },
		"difficulty": 30,
		"description": "Combines Cave Bloodmoss and Venom Gland into an invigorating Strength Potion."
	}
]

# Run state
static var assigned_appearances: Dictionary = {} # potion_id -> appearance string
static var identified_potions: Dictionary = {} # potion_id -> true

static func init_run(seed_val: int = -1) -> void:
	identified_potions.clear()
	assigned_appearances.clear()

	var pool = POTION_APPEARANCES.duplicate()
	if seed_val >= 0:
		var rng = RandomNumberGenerator.new()
		rng.seed = seed_val
		# Fisher-Yates shuffle with seed
		for i in range(pool.size() - 1, 0, -1):
			var j = rng.randi_range(0, i)
			var temp = pool[i]
			pool[i] = pool[j]
			pool[j] = temp
	else:
		pool.shuffle()

	var all_potions: Array[String] = []
	all_potions.append_array(BENEFICIAL_POTIONS)
	all_potions.append_array(HARMFUL_POTIONS)

	for i in range(all_potions.size()):
		var p_id = all_potions[i]
		var app = pool[i % pool.size()]
		assigned_appearances[p_id] = app

static func identify_potion(potion_id: String) -> void:
	identified_potions[potion_id] = true

static func is_potion_identified(potion_id: String) -> bool:
	return identified_potions.get(potion_id, false)

static func get_potion_appearance(potion_id: String) -> String:
	if not assigned_appearances.has(potion_id):
		# Fallback if accessed before init_run
		init_run(1)
	return assigned_appearances.get(potion_id, "Murky Potion")

static func get_potion_display_name(potion_id: String) -> String:
	if is_potion_identified(potion_id):
		if POTION_DEFINITIONS.has(potion_id):
			return POTION_DEFINITIONS[potion_id].get("name", "Potion")
		return "Potion"
	return get_potion_appearance(potion_id)

static func get_potion_display_description(potion_id: String) -> String:
	if is_potion_identified(potion_id):
		if POTION_DEFINITIONS.has(potion_id):
			return POTION_DEFINITIONS[potion_id].get("description", "")
		return "An alchemical potion."
	var app = get_potion_appearance(potion_id)
	return "An unidentified potion containing %s. Its properties are unknown until tasted, thrown, or identified." % app

static func create_potion(potion_id: String, quantity: int = 1) -> ItemData:
	if not assigned_appearances.has(potion_id):
		init_run()

	var def = POTION_DEFINITIONS.get(potion_id, {})
	var base_gold = 25
	if def.get("is_beneficial", true):
		base_gold = 25 if def.get("identify_difficulty", 20) <= 25 else 50
	else:
		base_gold = 30

	var d_name = get_potion_display_name(potion_id)
	var d_desc = get_potion_display_description(potion_id)

	var item = ItemData.new(potion_id, d_name, ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5, quantity)
	item.description = d_desc
	item.base_value_gold = base_gold
	item.is_fragile = true
	item.tags = ["potion", "consumable"]
	item.set_meta("is_potion", true)
	item.set_meta("potion_id", potion_id)

	if def.has("area_radius"):
		item.area_radius = int(def["area_radius"])

	return item

static func create_reagent(reagent_id: String, quantity: int = 1) -> ItemData:
	var def = REAGENTS.get(reagent_id, {
		"name": "Dungeon Reagent",
		"description": "Rare alchemy reagent.",
		"weight": 0.1,
		"base_val": 10
	})
	var item = ItemData.new(reagent_id, def["name"], ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, def["weight"], quantity)
	item.description = def["description"]
	item.base_value_gold = def["base_val"]
	item.tags = ["alchemy_reagent"]
	item.set_meta("is_reagent", true)
	return item

## Attempts identification via Scholarship or Alchemy skill check against potion difficulty.
## Consumes 1 turn and trains the higher of the two skills.
static func attempt_identify_with_skill(player: Node2D, item: ItemData) -> Dictionary:
	if not item or not item.has_meta("potion_id"):
		return {"success": false, "identified": false, "message": "Item is not a potion."}

	var p_id = item.get_meta("potion_id") as String
	if is_potion_identified(p_id):
		return {"success": true, "identified": true, "message": "Already identified as %s." % get_potion_display_name(p_id)}

	var def = POTION_DEFINITIONS.get(p_id, {})
	var dc = int(def.get("identify_difficulty", 25))

	var skills = player.get_node_or_null("SkillComponent") as SkillComponent if player else null
	var stats = player.get_node_or_null("StatsComponent") as StatsComponent if player else null
	var attrs = stats.attributes if stats else null

	var sch_lvl = skills.get_effective_level(SkillData.SkillId.SCHOLARSHIP, attrs) if skills and attrs else 10.0
	var alc_lvl = skills.get_effective_level(SkillData.SkillId.ALCHEMY, attrs) if skills and attrs else 10.0

	var best_lvl = maxf(sch_lvl, alc_lvl)
	var trained_skill = SkillData.SkillId.SCHOLARSHIP if sch_lvl >= alc_lvl else SkillData.SkillId.ALCHEMY

	if skills and attrs:
		skills.train_skill(trained_skill, dc, attrs)

	# Identification Roll: standard test DC check with skill bonus
	var roll = randf_range(1.0, 100.0) + (best_lvl * 0.75)
	if roll >= float(dc) or best_lvl >= float(dc):
		identify_potion(p_id)
		item.item_name = get_potion_display_name(p_id)
		item.description = get_potion_display_description(p_id)
		var real_name = POTION_DEFINITIONS[p_id].get("name", "Potion")
		return {
			"success": true,
			"identified": true,
			"real_name": real_name,
			"message": "Identification success! Revealed as %s." % real_name
		}
	else:
		return {
			"success": false,
			"identified": false,
			"message": "You fail to identify the mysterious liquid (Difficulty %d)." % dc
		}

## Applies the potion effect to an entity (whether drunk by player or thrown at an entity).
## Automatically reveals the true identity of this potion for the rest of the run!
static func apply_potion_effect(target: Node2D, potion_id: String, is_drinking: bool = true) -> Dictionary:
	var def = POTION_DEFINITIONS.get(potion_id, {})
	var real_name = def.get("name", "Potion")

	# 1. Reveal true identity upon drinking or impact
	identify_potion(potion_id)

	if not is_instance_valid(target):
		return {"success": true, "message": "The potion shatters on the cold stone floor, revealing %s!" % real_name}

	var stats = target.get_node_or_null("StatsComponent") as StatsComponent
	var sec = target.get_node_or_null("StatusEffectComponent") as StatusEffectComponent
	var target_name = target.name if not target.has_method("get") or target.get("enemy_name") == null else str(target.get("enemy_name"))
	if target is Player:
		target_name = "You"

	var effect_type = def.get("effect_type", "")
	var effect_val = int(def.get("effect_val", 0))
	var dur = int(def.get("duration", 5))

	var msg = ""
	match effect_type:
		"heal":
			if stats:
				var healed = stats.heal(float(effect_val))
				msg = "%s restored %d HP!" % [target_name, int(healed)]
			else:
				msg = "%s felt rejuvenating warmth." % target_name
		"mana":
			if stats:
				stats.current_mana = minf(stats.current_mana + float(effect_val), stats.attributes.get_max_mana() if stats.attributes else 100.0)
				stats.emit_signal("mana_changed", stats.current_mana, stats.attributes.get_max_mana() if stats.attributes else 100.0)
				msg = "%s restored %d Mana!" % [target_name, effect_val]
		"cure_poison":
			if sec:
				sec.cure_poison()
				msg = "%s purged all toxins and poison!" % target_name
			else:
				msg = "%s felt cleansed." % target_name
		"giant_strength":
			if sec:
				sec.apply_giant_strength(dur, effect_val)
				msg = "%s gained Giant Strength (+%d STR for %dt)!" % [target_name, effect_val, dur]
		"haste":
			if sec:
				sec.apply_haste(dur)
				msg = "%s moves with blistering Haste (+1 action/turn for %dt)!" % [target_name, dur]
		"invisibility":
			if sec:
				sec.apply_invisibility(dur)
				msg = "%s faded into Invisibility for %dt!" % [target_name, dur]
		"poison":
			var tier = int(def.get("tier", 1))
			if sec:
				sec.apply_poison(tier as StatusEffectComponent.PoisonTier, dur)
				msg = "%s is poisoned by %s (Tier %s for %dt)!" % [target_name, real_name, sec.get_poison_tier_string(), dur]
			elif stats:
				stats.take_damage(effect_val)
				msg = "%s took %d poison damage!" % [target_name, effect_val]
		"fire_aoe":
			var fire_dmg = randi_range(15, 25)
			if stats:
				stats.take_damage(fire_dmg)
			msg = "%s is engulfed in Alchemist's Fire for %d damage!" % [target_name, fire_dmg]
		"acid":
			if stats:
				stats.take_damage(effect_val)
			msg = "%s is burned by Corrosive Acid for %d damage!" % [target_name, effect_val]
		"blindness":
			if sec:
				sec.apply_blindness(dur)
				msg = "%s is blinded for %dt!" % [target_name, dur]
		"weakness":
			if sec:
				sec.apply_weakness(dur, effect_val)
				msg = "%s is afflicted with Weakness (-%d STR for %dt)!" % [target_name, effect_val, dur]
		_:
			msg = "%s was struck by %s." % [target_name, real_name]

	var action_verb = "drank" if is_drinking else "was struck by"
	var reveal_tag = " [Revealed: %s]" % real_name
	return {
		"success": true,
		"message": "%s %s %s! %s%s" % [target_name, action_verb, real_name, msg, reveal_tag],
		"real_name": real_name
	}

## Executes portable Mortar and Pestle crafting.
## Checks ingredients in player's inventory, consumes reagents, trains ALCHEMY skill,
## and produces an identified potion scaling yield/potency with Alchemy and Intelligence.
static func craft_recipe(player: Node2D, recipe_id: String) -> Dictionary:
	if not is_instance_valid(player):
		return {"success": false, "message": "Player unavailable."}

	var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if not inv:
		return {"success": false, "message": "Player has no inventory."}

	# Check Mortar and Pestle
	var has_mortar = false
	for it in inv.items:
		if it.item_id == "mortar_and_pestle":
			has_mortar = true
			break
	if not has_mortar and inv.equipped_slots.has(ItemData.EquipSlot.ACCESSORY):
		var acc = inv.equipped_slots[ItemData.EquipSlot.ACCESSORY] as ItemData
		if acc and acc.item_id == "mortar_and_pestle":
			has_mortar = true

	if not has_mortar:
		return {"success": false, "message": "Crafting requires a Mortar and Pestle in inventory or equipped!"}

	# Find recipe
	var target_recipe: Dictionary = {}
	for r in RECIPES:
		if r["recipe_id"] == recipe_id:
			target_recipe = r
			break

	if target_recipe.is_empty():
		return {"success": false, "message": "Unknown crafting recipe: %s" % recipe_id}

	var ingredients: Dictionary = target_recipe["ingredients"]
	for req_id in ingredients.keys():
		var req_qty = int(ingredients[req_id])
		if inv.get_item_count(req_id) < req_qty:
			var reg_def = REAGENTS.get(req_id, {})
			return {
				"success": false,
				"message": "Missing ingredients! Requires %d x %s." % [req_qty, reg_def.get("name", req_id)]
			}

	# Consume ingredients
	for req_id in ingredients.keys():
		inv.consume_item_by_id(req_id, int(ingredients[req_id]))

	# Train Alchemy skill
	var skills = player.get_node_or_null("SkillComponent") as SkillComponent
	var stats = player.get_node_or_null("StatsComponent") as StatsComponent
	var attrs = stats.attributes if stats else null

	var alc_lvl = 10.0
	var int_val = 10
	if skills and attrs:
		alc_lvl = skills.get_effective_level(SkillData.SkillId.ALCHEMY, attrs)
		int_val = attrs.intelligence
		skills.train_skill(SkillData.SkillId.ALCHEMY, float(target_recipe.get("difficulty", 20)), attrs)

	# Yield and Potency Scaling: Base yield 1
	var yield_qty = 1
	var bonus_score = alc_lvl + float(int_val)
	if bonus_score >= 35.0 and randf() < 0.40:
		yield_qty += 1

	var result_p_id = target_recipe["result_potion_id"] as String
	# Potency upgrade chance if producing healing/poison
	if bonus_score >= 50.0 and randf() < 0.35:
		if result_p_id == "potion_heal_standard":
			result_p_id = "potion_heal_greater"
		elif result_p_id == "potion_poison_standard":
			result_p_id = "potion_poison_greater"

	# Potion produced is known and identified
	identify_potion(result_p_id)
	var produced_item = create_potion(result_p_id, yield_qty)
	inv.add_item(produced_item)

	var p_name = POTION_DEFINITIONS[result_p_id].get("name", "Potion")
	return {
		"success": true,
		"potion": produced_item,
		"quantity": yield_qty,
		"message": "Crafted %s (x%d)! Alchemy skill trained." % [p_name, yield_qty]
	}
