class_name Shrine
extends Node2D

## Shrine: Ancient deity altar spawned in dungeon alcoves granting covenants.

signal shrine_activated(shrine_name: String, player: Node2D, bonus_mult: float, penalty_mult: float)

@export var shrine_data: ShrineData
var grid: DungeonGrid = null
var grid_pos: Vector2i = Vector2i.ZERO
var is_activated: bool = false

func _get_event_bus() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null

func setup(p_data: ShrineData, p_grid: DungeonGrid = null, p_pos: Vector2i = Vector2i.ZERO) -> void:
	shrine_data = p_data
	grid = p_grid
	grid_pos = p_pos
	is_activated = false
	if grid:
		global_position = grid.grid_to_world(grid_pos)

func can_interact(player: Node2D) -> bool:
	if is_activated or not shrine_data or not player:
		return false
	if "grid_pos" in player:
		var dist = maxi(abs(player.grid_pos.x - grid_pos.x), abs(player.grid_pos.y - grid_pos.y))
		return dist <= 1
	return true

func pray(player: Node2D) -> Dictionary:
	if not shrine_data:
		return {"success": false, "reason": "No deity assigned to this shrine"}
		
	if is_activated:
		return {"success": false, "reason": "Altar has already been exhausted"}
		
	# Check cross-run permanent betrayal in MetaProfileData
	var loop = Engine.get_main_loop()
	var mm = (loop as SceneTree).root.get_node_or_null("MetaManager") if loop and loop is SceneTree else null
	if mm and "profile" in mm and mm.profile and mm.profile.is_deity_betrayed(shrine_data.deity_id):
		return {"success": false, "reason": "%s refuses your prayers! Their wrath is eternal." % shrine_data.deity_name}
		
	# Check current run grudge
	if player.has_meta("abandoned_deities"):
		var abandoned = player.get_meta("abandoned_deities") as Array
		if abandoned.has(shrine_data.deity_id):
			return {"success": false, "reason": "%s turns away from you for breaking your covenant this run!" % shrine_data.deity_name}

	var stats = player.get_node_or_null("StatsComponent") as StatsComponent
	if not stats:
		for child in player.get_children():
			if child is StatsComponent:
				stats = child
				break
				
	var bonus_mult = 1.0
	var penalty_mult = 1.0
	if stats and stats.attributes:
		var mults = stats.attributes.get_shrine_multipliers()
		bonus_mult = mults["bonus_mult"]
		penalty_mult = mults["penalty_mult"]
		
	# Check for existing covenant on player
	var existing_covenant = null
	if "active_shrine_covenant" in player:
		existing_covenant = player.get("active_shrine_covenant")
	elif player.has_meta("active_shrine_covenant"):
		existing_covenant = player.get_meta("active_shrine_covenant")
		
	if existing_covenant is Dictionary and existing_covenant.has("deity_id"):
		var old_id = str(existing_covenant["deity_id"])
		if old_id != shrine_data.deity_id:
			var old_data = ShrineData.create_by_deity_id(old_id)
			if old_data.apostasy_temperament == ShrineData.ApostasyTemperament.JEALOUS_UNFORGIVING:
				if mm and "profile" in mm and mm.profile:
					mm.profile.record_betrayed_deity(old_id)
					if mm.has_method("save_meta_profile"):
						mm.save_meta_profile()
				player.set_meta("apostasy_debuff", {
					"name": old_data.apostasy_debuff_name,
					"turns": old_data.apostasy_debuff_turns,
					"deity": old_id,
					"description": old_data.apostasy_debuff_description
				})
			elif old_data.apostasy_temperament == ShrineData.ApostasyTemperament.VENGEFUL_GRUDGE:
				var abandoned: Array = player.get_meta("abandoned_deities") if player.has_meta("abandoned_deities") else []
				if not abandoned.has(old_id):
					abandoned.append(old_id)
				player.set_meta("abandoned_deities", abandoned)
				player.set_meta("apostasy_debuff", {
					"name": old_data.apostasy_debuff_name,
					"turns": old_data.apostasy_debuff_turns,
					"deity": old_id,
					"description": old_data.apostasy_debuff_description
				})
				
		var bus = _get_event_bus()
		if bus:
			bus.emit_signal("deity_covenant_broken", existing_covenant.get("deity_name", old_id))
			
	var scaled_blessing = shrine_data.get_scaled_blessing(bonus_mult)
	var scaled_taboo = shrine_data.get_scaled_taboo(penalty_mult)
	
	var covenant = {
		"deity_id": shrine_data.deity_id,
		"deity_name": shrine_data.deity_name,
		"title": shrine_data.title,
		"bonus_multiplier": bonus_mult,
		"penalty_multiplier": penalty_mult,
		"blessing_modifiers": scaled_blessing,
		"taboo_modifiers": scaled_taboo,
		"special_taboo_flags": shrine_data.special_taboo_flags
	}
	
	if "active_shrine_covenant" in player:
		player.active_shrine_covenant = covenant
	else:
		player.set_meta("active_shrine_covenant", covenant)
		
	is_activated = true
	
	emit_signal("shrine_activated", shrine_data.deity_name, player, bonus_mult, penalty_mult)
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("shrine_activated", shrine_data.deity_name, player)
		bus.emit_signal("shrine_covenant_formed", shrine_data.deity_name, player, bonus_mult, penalty_mult)
		
	return {
		"success": true,
		"deity_name": shrine_data.deity_name,
		"bonus_multiplier": bonus_mult,
		"penalty_multiplier": penalty_mult,
		"blessing_modifiers": scaled_blessing,
		"taboo_modifiers": scaled_taboo,
		"covenant": covenant
	}

func get_inspection_data(_viewer: Node2D = null) -> InspectionData:
	var data = InspectionData.new()
	data.category = InspectionData.Category.ITEM_OR_OBJECT
	data.grid_cell = grid_pos
	data.icon_glyph = "†"
	data.accent_color = Color(0.85, 0.65, 1.0)
	var title_str = shrine_data.title if shrine_data and shrine_data.title != "" else "Deity Shrine"
	data.title = title_str
	var deity = shrine_data.deity_name if shrine_data else "Unknown Patron"
	var state_str = "Spent Altar" if is_activated else "Active Altar"
	data.category_text = "%s • %s" % [deity, state_str]
	var desc_str = shrine_data.description if shrine_data and shrine_data.description != "" else "An ancient shrine etched with astral script."
	if shrine_data and shrine_data.blessing_description != "":
		desc_str += " Blessing: " + shrine_data.blessing_description
	data.description = desc_str
	return data
