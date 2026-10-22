class_name HoverInspectionController
extends Node2D

## HoverInspectionController: Translates mouse position to grid cells, resolves priorities
## under Fog of War constraints, and emits EventBus hover inspection signals.

var grid: DungeonGrid = null
var fow: FogOfWarSystem = null
var world: World = null

var hovered_cell: Vector2i = Vector2i(-1, -1)
var last_inspected_cell: Vector2i = Vector2i(-1, -1)
var is_dirty: bool = true

func _ready() -> void:
	z_index = 10
	_connect_event_bus()

func setup(p_world: World, p_grid: DungeonGrid, p_fow: FogOfWarSystem) -> void:
	world = p_world
	grid = p_grid
	fow = p_fow
	is_dirty = true

func _connect_event_bus() -> void:
	var bus = _get_event_bus()
	if not bus:
		return
	var dirty_signals = [
		"turn_started", "turn_ended", "entity_moved", "entity_damaged",
		"entity_died", "trap_triggered", "secret_discovered", "floor_descended"
	]
	for sig in dirty_signals:
		if bus.has_signal(sig):
			bus.connect(sig, Callable(self, "_on_state_dirtied"))

func _on_state_dirtied(_a = null, _b = null, _c = null, _d = null) -> void:
	is_dirty = true

func _get_event_bus() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null

func _process(_delta: float) -> void:
	if not grid:
		return
		
	var mouse_world = get_global_mouse_position()
	var mouse_cell = grid.world_to_grid(mouse_world)
	
	if mouse_cell != hovered_cell:
		hovered_cell = mouse_cell
		is_dirty = true
		
	if is_dirty:
		is_dirty = false
		last_inspected_cell = hovered_cell
		_perform_inspection(hovered_cell)

func _perform_inspection(cell: Vector2i) -> void:
	var bus = _get_event_bus()
	var data = inspect_cell(cell)
	if bus:
		if data:
			bus.emit_signal("tile_hovered", cell, data)
		else:
			bus.emit_signal("tile_hover_cleared")

## Inspects a target grid coordinate strictly following Fog of War rules:
## 1. Out-of-bounds or HIDDEN: Returns "Unexplored Darkness" (no spoilers).
## 2. EXPLORED (Memory): Returns static terrain, revealed shrines/doors. Never leaks unrevealed traps or mobile hostiles.
## 3. VISIBLE (LOS): Priority stack: Occupant Entity -> Dungeon Object -> Revealed Trap/Secret -> Surface Decals/Terrain.
func inspect_cell(cell: Vector2i) -> InspectionData:
	if not grid:
		return null
		
	# 1. Bounds check
	if cell.x < 0 or cell.x >= grid.grid_width or cell.y < 0 or cell.y >= grid.grid_height:
		var oob = InspectionData.new()
		oob.title = "Unexplored Darkness"
		oob.category = InspectionData.Category.UNKNOWN
		oob.category_text = "Beyond Dungeon"
		oob.grid_cell = cell
		oob.icon_glyph = " "
		oob.accent_color = Color(0.3, 0.35, 0.4)
		oob.description = "The endless abyss beyond the dungeon perimeters."
		return oob
		
	var vis = fow.get_visibility(cell) if fow else FogOfWarSystem.TileVisibility.VISIBLE
	
	# 2. Hidden in Fog of War (Pitch Black)
	if vis == FogOfWarSystem.TileVisibility.HIDDEN:
		var hidden_data = InspectionData.new()
		hidden_data.title = "Unexplored Darkness"
		hidden_data.category = InspectionData.Category.UNKNOWN
		hidden_data.category_text = "Fog of War"
		hidden_data.grid_cell = cell
		hidden_data.icon_glyph = "?"
		hidden_data.accent_color = Color(0.4, 0.45, 0.55)
		hidden_data.description = "Beyond your current line of sight and memory."
		return hidden_data
		
	# 3. Explored (Dimmed Memory - Out of active sight)
	if vis == FogOfWarSystem.TileVisibility.EXPLORED:
		# Check revealed static shrines
		var shrine = _get_shrine_at(cell)
		if shrine:
			var s_data = shrine.get_inspection_data()
			s_data.is_remembered_only = true
			s_data.category_text += " [Memory]"
			return s_data
			
		# Check revealed secret doors
		var door = _get_revealed_secret_door_at(cell)
		if door:
			var d_data = door.get_inspection_data()
			d_data.is_remembered_only = true
			d_data.category_text += " [Memory]"
			return d_data
			
		# Check world items on ground (remembered location)
		var item = _get_world_item_at(cell)
		if item:
			var it_data = item.get_inspection_data()
			it_data.is_remembered_only = true
			it_data.category_text += " [Memory]"
			return it_data
			
		# Fallback to static terrain
		return _inspect_terrain(cell, true)
		
	# 4. Direct Line of Sight (VISIBLE)
	# 4.1. Check Occupants (Player, Enemies, Boss, Companions, Merchants)
	if grid.is_occupied(cell):
		var occupant = grid.get_occupant(cell)
		if is_instance_valid(occupant) and occupant.visible:
			if occupant.has_method("get_inspection_data"):
				var viewer = world.player if world else null
				return occupant.get_inspection_data(viewer)
				
	# 4.2. Check Stairs Down
	if world and world.stairs_down and is_instance_valid(world.stairs_down) and world.stairs_down.grid_pos == cell and world.stairs_down.visible:
		return world.stairs_down.get_inspection_data()
		
	# 4.3. Check Dungeon Objects (Chest, Shrine, WorldItem)
	var chest_vis = _get_chest_at(cell)
	if chest_vis:
		return chest_vis.get_inspection_data()

	var shrine_vis = _get_shrine_at(cell)
	if shrine_vis:
		return shrine_vis.get_inspection_data()
		
	var w_item = _get_world_item_at(cell)
	if w_item:
		return w_item.get_inspection_data()
		
	# 4.4. Check Revealed Traps
	var trap = _get_revealed_trap_at(cell)
	if trap:
		return trap.get_inspection_data()
		
	# 4.5. Check Revealed Secret Doors
	var sec_door = _get_revealed_secret_door_at(cell)
	if sec_door:
		return sec_door.get_inspection_data()
		
	# 4.6. Base Terrain & Surface Conditions
	return _inspect_terrain(cell, false)

func _inspect_terrain(cell: Vector2i, is_remembered: bool) -> InspectionData:
	var data = InspectionData.new()
	data.category = InspectionData.Category.TERRAIN
	data.grid_cell = cell
	data.is_remembered_only = is_remembered
	
	var is_sanctum = (world != null and world.current_floor == 20)
	
	if grid.wall_cells.has(cell):
		data.title = "Sanctum Pillar" if is_sanctum else "Stone Wall"
		data.category_text = "Indestructible Pillar" if is_sanctum else "Reinforced Wall"
		data.icon_glyph = "#"
		data.accent_color = Color(0.45, 0.48, 0.55)
		data.description = "Solid dungeon masonry. Impassable, blocks movement and vision."
	elif grid.walkable_cells.has(cell):
		data.title = "Sanctum Arena Floor" if is_sanctum else "Dungeon Floor"
		data.category_text = "Ancient Flagstone"
		data.icon_glyph = "."
		data.accent_color = Color(0.65, 0.70, 0.78)
		
		var traits: Array[String] = ["Smooth flagstone floor", "Passable"]
		
		# Check surface decals
		if world and world.decals_layer:
			var decals = world.decals_layer.get_decal_types_at(cell)
			for d in decals:
				if d == "blood":
					traits.append("Bloodstained")
				elif d == "scorch":
					traits.append("Charred / Scorched")
				elif d.begins_with("holy") or d == "radiant":
					traits.append("Sanctified Glyph")
					
		# Check collapse tremors
		if world and world.collapse_manager:
			var stage = world.collapse_manager.current_stage
			if stage == FloorCollapseManager.CollapseStage.IMMINENT:
				traits.append("Violently Cracking")
			elif stage == FloorCollapseManager.CollapseStage.COLLAPSING:
				traits.append("Shuddering Tremors")
			elif stage == FloorCollapseManager.CollapseStage.TREMORS:
				traits.append("Subtle Tremors")
				
		data.description = " • ".join(traits)
	else:
		data.title = "Dungeon Void"
		data.category_text = "Chasm"
		data.icon_glyph = " "
		data.accent_color = Color(0.3, 0.3, 0.35)
		data.description = "Deep chasm pit."
		
	if is_remembered:
		data.category_text += " [Memory]"
		data.accent_color = Color(data.accent_color.r * 0.7, data.accent_color.g * 0.7, data.accent_color.b * 0.7)
		
	return data

func _get_chest_at(cell: Vector2i) -> TreasureChest:
	if not world or not world.dungeon_objects:
		return null
	for child in world.dungeon_objects.get_children():
		if child is TreasureChest and child.grid_pos == cell:
			return child
	return null

func _get_shrine_at(cell: Vector2i) -> Shrine:
	if not world or not world.dungeon_objects:
		return null
	for child in world.dungeon_objects.get_children():
		if child is Shrine and child.grid_pos == cell:
			return child
	return null

func _get_world_item_at(cell: Vector2i) -> WorldItem:
	if not world or not world.dungeon_objects:
		return null
	for child in world.dungeon_objects.get_children():
		if child is WorldItem and child.grid_pos == cell:
			return child
	return null

func _get_revealed_trap_at(cell: Vector2i) -> Trap:
	if not world or not world.traps.has(cell):
		return null
	var trap = world.traps[cell] as Trap
	if trap and trap.is_revealed:
		return trap
	return null

func _get_revealed_secret_door_at(cell: Vector2i) -> SecretDoor:
	if not world:
		return null
	for door in world.secret_doors:
		if door.grid_pos == cell and door.is_revealed:
			return door
	return null
