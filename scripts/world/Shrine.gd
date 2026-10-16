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
	if existing_covenant is Dictionary and existing_covenant.has("deity_name"):
		var bus = _get_event_bus()
		if bus:
			bus.emit_signal("deity_covenant_broken", existing_covenant["deity_name"])
			
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
