@tool
class_name TargetingSystem
extends Node

## TargetingSystem: Manages Manual Line-of-Fire (LoF) raycasting, obstruction detection,
## intermediate entity interception (Pass-Through / Obstacle Targeting Rule),
## Area-of-Effect (AoE) radius footprints, and interactive cursor state.

enum ActionMode {
	NONE,
	RANGED_WEAPON,
	SPELL,
	THROWN_ITEM,
	COMPANION_ATTACK_TARGET,
	TAME_BEAST
}

enum BlockerType {
	NONE,
	WALL,
	ENTITY,
	OUT_OF_RANGE,
	INVALID_DESTINATION
}

signal targeting_started(context: Dictionary)
signal cursor_updated(cursor_cell: Vector2i, lof_data: Dictionary)
signal targeting_confirmed(effective_cell: Vector2i, lof_data: Dictionary, context: Dictionary)
signal targeting_canceled()

var grid: DungeonGrid = null
var turn_manager: TurnManager = null
var fow: FogOfWarSystem = null
var player: Node2D = null

var is_active: bool = false
var cursor_cell: Vector2i = Vector2i(-1, -1)
var active_context: Dictionary = {}
var current_lof: Dictionary = {}
var _cycle_index: int = -1

func setup(p_player: Node2D, p_grid: DungeonGrid, p_turn_manager: TurnManager, p_fow: FogOfWarSystem = null) -> void:
	player = p_player
	grid = p_grid
	turn_manager = p_turn_manager
	fow = p_fow

func _get_event_bus() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null

## Pure static/instance raycast calculator for grid-based Line of Fire.
## Evaluates wall obstructions, intermediate entity interception (Pass-Through Rule),
## range boundaries, and AoE blast footprints centered on the effective impact cell.
static func calculate_line_of_fire(
	origin: Vector2i,
	target_cell: Vector2i,
	p_grid: DungeonGrid,
	max_range: int,
	area_radius: int = 0,
	is_beam: bool = false,
	is_teleport: bool = false,
	caster: Node2D = null,
	p_fow: FogOfWarSystem = null
) -> Dictionary:
	var ray_cells: Array[Vector2i] = VisionComponent.get_line_cells(origin, target_cell)
	var clear_cells: Array[Vector2i] = []
	var blocked_cells: Array[Vector2i] = []
	var blocker_type: BlockerType = BlockerType.NONE
	var blocker_cell: Vector2i = Vector2i(-1, -1)
	var blocker_entity: Node2D = null
	var effective_target_cell: Vector2i = target_cell

	var dist = maxi(abs(target_cell.x - origin.x), abs(target_cell.y - origin.y))

	# Walk ray from index 1 (first step after origin) to end
	for i in range(1, ray_cells.size()):
		var cell = ray_cells[i]
		var step_dist = maxi(abs(cell.x - origin.x), abs(cell.y - origin.y))

		if blocker_type != BlockerType.NONE:
			blocked_cells.append(cell)
			continue

		# 1. Check solid wall obstruction
		if p_grid and p_grid.wall_cells.has(cell):
			blocker_type = BlockerType.WALL
			blocker_cell = cell
			effective_target_cell = ray_cells[i - 1]
			blocked_cells.append(cell)
			continue

		# 2. Check range limit along the ray
		if step_dist > max_range:
			blocker_type = BlockerType.OUT_OF_RANGE
			blocker_cell = cell
			effective_target_cell = ray_cells[i - 1]
			blocked_cells.append(cell)
			continue

		# 3. Check intermediate entity obstruction (Pass-Through / Obstacle Interception Rule)
		var is_intermediate = (i < ray_cells.size() - 1)
		if is_intermediate and p_grid and p_grid.is_occupied(cell):
			var occ = p_grid.get_occupant(cell)
			var occ_visible = (p_fow == null) or p_fow.is_visible(cell)
			if is_instance_valid(occ) and occ != caster and occ_visible:
				if not is_beam and not is_teleport:
					blocker_type = BlockerType.ENTITY
					blocker_cell = cell
					blocker_entity = occ
					effective_target_cell = cell
					clear_cells.append(cell)
					continue

		clear_cells.append(cell)

	# 4. Teleport destination validation (must be walkable and unoccupied)
	if is_teleport and blocker_type == BlockerType.NONE and p_grid:
		if not p_grid.can_enter(target_cell):
			blocker_type = BlockerType.INVALID_DESTINATION
			blocker_cell = target_cell

	# 5. Determine direct target entity at effective_target_cell
	var target_entity: Node2D = blocker_entity
	if not target_entity and p_grid and p_grid.is_occupied(effective_target_cell):
		var occ = p_grid.get_occupant(effective_target_cell)
		if is_instance_valid(occ):
			target_entity = occ

	# 6. Calculate AoE blast footprint centered on effective_target_cell (or beam path)
	var aoe_cells: Array[Vector2i] = []
	var affected_entities: Array[Node2D] = []

	if is_beam:
		for c in clear_cells:
			aoe_cells.append(c)
			if p_grid and p_grid.is_occupied(c):
				var occ = p_grid.get_occupant(c)
				if is_instance_valid(occ) and occ != caster and not affected_entities.has(occ):
					affected_entities.append(occ)
	elif area_radius > 0 and blocker_type != BlockerType.WALL and blocker_type != BlockerType.OUT_OF_RANGE:
		for dy in range(-area_radius, area_radius + 1):
			for dx in range(-area_radius, area_radius + 1):
				var blast_cell = effective_target_cell + Vector2i(dx, dy)
				if p_grid:
					if blast_cell.x < 0 or blast_cell.x >= p_grid.grid_width or blast_cell.y < 0 or blast_cell.y >= p_grid.grid_height:
						continue
					if p_grid.wall_cells.has(blast_cell):
						continue
				aoe_cells.append(blast_cell)
				if p_grid and p_grid.is_occupied(blast_cell):
					var occ = p_grid.get_occupant(blast_cell)
					if is_instance_valid(occ) and not affected_entities.has(occ):
						affected_entities.append(occ)
	else:
		if blocker_type != BlockerType.WALL and blocker_type != BlockerType.OUT_OF_RANGE:
			aoe_cells.append(effective_target_cell)
			if target_entity and is_instance_valid(target_entity):
				affected_entities.append(target_entity)

	# 7. Determine overall validity
	var is_valid: bool = true
	if dist > max_range and blocker_type != BlockerType.ENTITY:
		is_valid = false
	elif blocker_type == BlockerType.WALL or blocker_type == BlockerType.OUT_OF_RANGE or blocker_type == BlockerType.INVALID_DESTINATION:
		is_valid = false
	elif target_cell == origin and not is_teleport and area_radius == 0:
		# Allow self-targeting only if context permits (e.g. Minor Heal on self)
		pass

	# 8. Build tactical status description
	var status_text: String = ""
	if blocker_type == BlockerType.WALL:
		status_text = "BLOCKED by Wall at (%d, %d)!" % [blocker_cell.x, blocker_cell.y]
	elif blocker_type == BlockerType.OUT_OF_RANGE:
		status_text = "OUT OF RANGE (%d / %d tiles)!" % [dist, max_range]
	elif blocker_type == BlockerType.INVALID_DESTINATION:
		status_text = "INVALID DESTINATION (%d, %d) is occupied or blocked!" % [target_cell.x, target_cell.y]
	elif blocker_type == BlockerType.ENTITY and blocker_entity:
		var b_name = blocker_entity.get("enemy_name") if "enemy_name" in blocker_entity else blocker_entity.name
		status_text = "INTERCEPTED by %s at (%d, %d)! [Will hit %s]" % [b_name, blocker_cell.x, blocker_cell.y, b_name]
	elif target_entity and target_entity != caster:
		var t_name = target_entity.get("enemy_name") if "enemy_name" in target_entity else target_entity.name
		status_text = "Target: %s at (%d, %d) [Dist: %d/%d]" % [t_name, effective_target_cell.x, effective_target_cell.y, dist, max_range]
	else:
		status_text = "Aiming at (%d, %d) [Dist: %d/%d]" % [effective_target_cell.x, effective_target_cell.y, dist, max_range]

	return {
		"origin_cell": origin,
		"cursor_cell": target_cell,
		"effective_target_cell": effective_target_cell,
		"ray_cells": ray_cells,
		"clear_cells": clear_cells,
		"blocked_cells": blocked_cells,
		"blocker_type": blocker_type,
		"blocker_cell": blocker_cell,
		"blocker_entity": blocker_entity,
		"target_entity": target_entity,
		"aoe_cells": aoe_cells,
		"affected_entities": affected_entities,
		"distance": dist,
		"max_range": max_range,
		"area_radius": area_radius,
		"is_beam": is_beam,
		"is_teleport": is_teleport,
		"is_valid": is_valid,
		"status_text": status_text
	}

## Enters Manual Targeting Mode with the supplied context dictionary:
## {
##   "mode": ActionMode,
##   "label": String,
##   "max_range": int,
##   "area_radius": int,
##   "is_beam": bool,
##   "is_teleport": bool,
##   "allow_self": bool,
##   "slot_index": int (optional),
##   "spell": SpellData (optional),
##   "weapon": ItemData (optional),
##   "item": ItemData (optional),
##   "color": Color (optional)
## }
func start_targeting(context: Dictionary) -> bool:
	if not player or not grid:
		return false
	if turn_manager and not turn_manager.is_targeting():
		if not turn_manager.begin_targeting():
			return false

	is_active = true
	active_context = context.duplicate()
	_cycle_index = -1

	# Default initial cursor: nearest visible hostile in range, or 1 tile ahead in facing direction
	var origin = player.get("grid_pos") as Vector2i
	var initial_cell = _find_default_initial_cell(origin, int(context.get("max_range", 6)))
	update_cursor(initial_cell)

	emit_signal("targeting_started", active_context)
	var bus = _get_event_bus()
	if bus and bus.has_signal("targeting_started"):
		bus.emit_signal("targeting_started", active_context)
	if bus and bus.has_signal("targeting_cursor_updated"):
		bus.emit_signal("targeting_cursor_updated", cursor_cell, current_lof)
	return true

func _find_default_initial_cell(origin: Vector2i, max_range: int) -> Vector2i:
	var visible_enemies = _get_visible_hostiles_in_range(origin, max_range)
	if not visible_enemies.is_empty():
		_cycle_index = 0
		return visible_enemies[0].get("grid_pos") as Vector2i

	var facing = player.get("facing_direction") as Vector2i if (player and "facing_direction" in player) else Vector2i.RIGHT
	if facing == Vector2i.ZERO:
		facing = Vector2i.RIGHT
	var step_cell = origin + facing
	if grid and not grid.wall_cells.has(step_cell):
		return step_cell
	return origin

func _get_visible_hostiles_in_range(origin: Vector2i, max_range: int) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not turn_manager:
		return result
	for e in turn_manager.registered_enemies:
		if is_instance_valid(e) and "grid_pos" in e:
			var e_pos = e.grid_pos as Vector2i
			if fow and not fow.is_visible(e_pos):
				continue
			var d = maxi(abs(e_pos.x - origin.x), abs(e_pos.y - origin.y))
			if d <= max_range:
				result.append(e)
	result.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var da = maxi(abs(a.grid_pos.x - origin.x), abs(a.grid_pos.y - origin.y))
		var db = maxi(abs(b.grid_pos.x - origin.x), abs(b.grid_pos.y - origin.y))
		return da < db
	)
	return result

func update_cursor(new_cell: Vector2i) -> void:
	if not is_active or not player or not grid:
		return
	var clamped_x = clampi(new_cell.x, 0, grid.grid_width - 1)
	var clamped_y = clampi(new_cell.y, 0, grid.grid_height - 1)
	cursor_cell = Vector2i(clamped_x, clamped_y)

	var origin = player.get("grid_pos") as Vector2i
	var max_range = int(active_context.get("max_range", 6))
	var area_radius = int(active_context.get("area_radius", 0))
	var is_beam = bool(active_context.get("is_beam", false))
	var is_teleport = bool(active_context.get("is_teleport", false))
	var allow_self = bool(active_context.get("allow_self", false))

	current_lof = calculate_line_of_fire(
		origin,
		cursor_cell,
		grid,
		max_range,
		area_radius,
		is_beam,
		is_teleport,
		player,
		fow
	)

	if cursor_cell == origin and not allow_self and area_radius == 0:
		current_lof["is_valid"] = false
		current_lof["status_text"] = "Select a target tile (Cannot target self)"

	var mode = int(active_context.get("mode", ActionMode.NONE))
	if mode == ActionMode.TAME_BEAST:
		var target_ent = current_lof.get("target_entity")
		if not target_ent and grid and grid.is_occupied(cursor_cell):
			target_ent = grid.get_occupant(cursor_cell)
		if target_ent and is_instance_valid(target_ent) and current_lof.get("is_valid", false):
			if CombatComponent.is_beast_eligible(target_ent):
				var floor_num = int(active_context.get("floor_num", 1))
				var chance = CombatComponent.calculate_tame_chance(player, target_ent, floor_num)
				var e_name = target_ent.get("enemy_name") if "enemy_name" in target_ent else target_ent.name
				current_lof["status_text"] = "Target: %s  •  [Tame Chance: %d%%]" % [e_name, int(round(chance * 100.0))]
				current_lof["is_valid"] = true
			else:
				current_lof["status_text"] = "Target is not a wild beast!"
				current_lof["is_valid"] = false
		elif current_lof.get("is_valid", false):
			current_lof["status_text"] = "Aiming at (%d, %d) [Select a Wild Beast]" % [cursor_cell.x, cursor_cell.y]
	elif mode == ActionMode.COMPANION_ATTACK_TARGET:
		var target_ent = current_lof.get("target_entity")
		if not target_ent and grid and grid.is_occupied(cursor_cell):
			target_ent = grid.get_occupant(cursor_cell)
		if target_ent and is_instance_valid(target_ent) and target_ent != player and not (target_ent is Companion and target_ent.is_hired):
			var t_name = target_ent.get("enemy_name") if "enemy_name" in target_ent else target_ent.name
			current_lof["status_text"] = "Command Squad Focus: %s" % t_name
			current_lof["is_valid"] = true
		elif current_lof.get("is_valid", false):
			current_lof["status_text"] = "Aiming at (%d, %d) [Select Enemy for Focus]" % [cursor_cell.x, cursor_cell.y]

	emit_signal("cursor_updated", cursor_cell, current_lof)
	var bus = _get_event_bus()
	if bus and bus.has_signal("targeting_cursor_updated"):
		bus.emit_signal("targeting_cursor_updated", cursor_cell, current_lof)

func step_cursor(delta: Vector2i) -> void:
	if not is_active:
		return
	update_cursor(cursor_cell + delta)

func cycle_target() -> void:
	if not is_active or not player:
		return
	var origin = player.get("grid_pos") as Vector2i
	var max_range = int(active_context.get("max_range", 6))
	var hostiles = _get_visible_hostiles_in_range(origin, max_range)
	if hostiles.is_empty():
		return
	_cycle_index = (_cycle_index + 1) % hostiles.size()
	update_cursor(hostiles[_cycle_index].get("grid_pos") as Vector2i)

func confirm_target() -> Dictionary:
	if not is_active:
		return {"confirmed": false, "reason": "Targeting not active"}

	if not current_lof.get("is_valid", false):
		return {
			"confirmed": false,
			"reason": current_lof.get("status_text", "Invalid target"),
			"lof": current_lof
		}

	var eff_cell: Vector2i = current_lof.get("effective_target_cell", cursor_cell)
	var lof_snapshot: Dictionary = current_lof.duplicate()
	var ctx_snapshot: Dictionary = active_context.duplicate()

	is_active = false
	active_context.clear()
	current_lof.clear()

	emit_signal("targeting_confirmed", eff_cell, lof_snapshot, ctx_snapshot)
	var bus = _get_event_bus()
	if bus and bus.has_signal("targeting_confirmed"):
		bus.emit_signal("targeting_confirmed", eff_cell, lof_snapshot)

	return {
		"confirmed": true,
		"cursor_cell": cursor_cell,
		"effective_target_cell": eff_cell,
		"lof": lof_snapshot,
		"context": ctx_snapshot
	}

func cancel_targeting() -> void:
	if not is_active:
		return
	is_active = false
	active_context.clear()
	current_lof.clear()
	if turn_manager:
		turn_manager.cancel_targeting()
	emit_signal("targeting_canceled")
	var bus = _get_event_bus()
	if bus and bus.has_signal("targeting_canceled"):
		bus.emit_signal("targeting_canceled")
