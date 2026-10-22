class_name DungeonGenerator
extends RefCounted

## DungeonGenerator: Procedural room-and-corridor generator with guaranteed connectivity.

const MerchantCatalog = preload("res://scripts/resources/MerchantCatalog.gd")

class Room:
    var id: int
    var rect: Rect2i
    var is_start: bool = false
    var is_exit: bool = false
    var is_bazaar: bool = false
    
    var center: Vector2i:
        get:
            return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
            
    func _init(p_id: int, p_rect: Rect2i) -> void:
        id = p_id
        rect = p_rect

# Generator Configuration
var width: int = 80
var height: int = 60
var min_room_size: int = 5
var max_room_size: int = 14
var max_rooms: int = 20
var room_margin: int = 2

# Output Data
var rooms: Array[Room] = []
var corridor_cells: Array[Vector2i] = []
var door_candidates: Array[Vector2i] = []
var start_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO

var secret_door_data: Array[Dictionary] = [] # {cell: Vector2i, hide_rating: float}
var trap_data: Array[Dictionary] = []        # {cell: Vector2i, hide_rating: float, trap_type: int}
var enemy_spawn_cells: Array[Vector2i] = []
var shrine_data: Array[Dictionary] = []
var chest_data: Array[Dictionary] = []
var floor_loot_data: Array[Dictionary] = []
var merchant_spawns: Array[Dictionary] = []
var mercenary_spawns: Array[Dictionary] = []

func _init(p_width: int = 80, p_height: int = 60) -> void:
    width = p_width
    height = p_height

## Generates a complete floor layout onto the provided DungeonGrid.
func generate_dungeon(grid: DungeonGrid, floor_number: int = 1, seed_val: int = -1, active_covenant_deity: String = "", betrayed_deities: Array[String] = []) -> Dictionary:
    if seed_val >= 0:
        seed(seed_val)
        
    grid.clear_grid()
    grid.grid_width = width
    grid.grid_height = height
    
    rooms.clear()
    corridor_cells.clear()
    door_candidates.clear()
    secret_door_data.clear()
    trap_data.clear()
    enemy_spawn_cells.clear()
    shrine_data.clear()
    chest_data.clear()
    floor_loot_data.clear()
    merchant_spawns.clear()
    mercenary_spawns.clear()
    
    # Floor 20: The Grandmaster Sanctum (Fixed Hand-Crafted 32x24 Boss Arena)
    if floor_number == 20:
        return _generate_floor_20_sanctum(grid)
    
    # 1. Fill entire grid with walls initially
    for y in range(height):
        for x in range(width):
            grid.set_cell_walkable(Vector2i(x, y), false)
            
    # 2. Generate non-overlapping rooms (guarantees Grand Bazaar Sanctuary Room on Floors 4, 8, 12, 16)
    _generate_rooms(grid, floor_number)
    
    # 3. Connect rooms with corridors
    _carve_corridors(grid)
    
    # 4. Rebuild AStar and guarantee 100% reachability
    grid.rebuild_astar()
    _ensure_all_rooms_connected(grid)
    grid.rebuild_astar()
    
    # 5. Designate Start Room and Furthest Exit Room
    _assign_start_and_exit(grid)
    
    # 6. Place Secret Doors at select room-corridor thresholds
    _place_secret_doors(grid, floor_number)
    
    # 7. Place Traps along corridors and rooms (no traps in Bazaar safe rooms)
    _place_traps(grid, floor_number)
    
    # 8. Place Enemy Spawns in rooms (no enemies in Bazaar safe rooms)
    _place_enemy_spawns(grid, floor_number)
    
    # 9. Place Deity Shrine (guaranteed 1 per floor on floors 1-19)
    _place_shrine(grid, floor_number, active_covenant_deity, betrayed_deities)
    
    # 10. Place Treasure Chests (1-3 coffer spawns per floor)
    _place_chests(grid, floor_number)
    
    # 11. Place Floor Loot Pickups (3-5 pickups per floor)
    _place_floor_loot(grid, floor_number)
    
    # 12. Place Travelling Merchants / Grand Bazaar Stalls
    _place_merchants(grid, floor_number)
    
    # 13. Place Hireable Mercenaries (Bazaars + 10% Wandering Spawns)
    _place_mercenaries(grid, floor_number)
    
    var mini_boss_spawn = Vector2i.ZERO
    if floor_number in [4, 8, 12, 16]:
        for r in rooms:
            if r.is_exit:
                var c = r.center
                if c == exit_cell:
                    c = exit_cell + Vector2i(1, 0)
                mini_boss_spawn = c
                break

    grid.rebuild_astar()
    
    return {
        "start_cell": start_cell,
        "exit_cell": exit_cell,
        "rooms": rooms,
        "corridors": corridor_cells,
        "secret_doors": secret_door_data,
        "traps": trap_data,
        "enemy_spawns": enemy_spawn_cells,
        "shrines": shrine_data,
        "chests": chest_data,
        "floor_loot": floor_loot_data,
        "merchant_spawns": merchant_spawns,
        "mercenary_spawns": mercenary_spawns,
        "mini_boss_spawn": mini_boss_spawn
    }

func _generate_rooms(grid: DungeonGrid, floor_number: int = 1) -> void:
    var attempts = 0
    var max_attempts = 350
    var is_bazaar_floor = (floor_number % 4 == 0 and floor_number < 20)
    var bazaar_placed = false
    
    while rooms.size() < max_rooms and attempts < max_attempts:
        attempts += 1
        var rw: int
        var rh: int
        
        # Room 1 on Bazaar floors is carved as the dedicated Grand Bazaar Sanctuary Room (larger room)
        if is_bazaar_floor and not bazaar_placed and rooms.size() >= 1:
            rw = randi_range(11, 14)
            rh = randi_range(10, 13)
        else:
            rw = randi_range(min_room_size, max_room_size)
            rh = randi_range(min_room_size, max_room_size)
            
        var rx = randi_range(room_margin + 1, width - rw - room_margin - 1)
        var ry = randi_range(room_margin + 1, height - rh - room_margin - 1)
        var new_rect = Rect2i(rx, ry, rw, rh)
        
        # Check collision with existing rooms (including 1-tile border)
        var overlaps = false
        var expanded_rect = Rect2i(new_rect.position - Vector2i(1, 1), new_rect.size + Vector2i(2, 2))
        for existing in rooms:
            if expanded_rect.intersects(existing.rect):
                overlaps = true
                break
                
        if not overlaps:
            var room = Room.new(rooms.size(), new_rect)
            if is_bazaar_floor and not bazaar_placed and rooms.size() >= 1:
                room.is_bazaar = true
                bazaar_placed = true
            rooms.append(room)
            
            # Carve room floors into grid
            for y in range(new_rect.position.y, new_rect.end.y):
                for x in range(new_rect.position.x, new_rect.end.x):
                    grid.set_cell_walkable(Vector2i(x, y), true)
                    
    # Fallback: if bazaar room was requested but couldn't place at larger size, flag largest room as bazaar
    if is_bazaar_floor and not bazaar_placed and rooms.size() >= 2:
        var best_idx = 1
        var best_area = 0
        for i in range(1, rooms.size()):
            var area = rooms[i].rect.size.x * rooms[i].rect.size.y
            if area > best_area:
                best_area = area
                best_idx = i
        rooms[best_idx].is_bazaar = true

func _carve_corridors(grid: DungeonGrid) -> void:
    if rooms.size() < 2:
        return
        
    for i in range(rooms.size() - 1):
        var c1 = rooms[i].center
        var c2 = rooms[i + 1].center
        _carve_l_corridor(grid, c1, c2)
        
    # Add 1 or 2 extra loop connections between random rooms for tactical branching
    if rooms.size() >= 4:
        var r_a = rooms[0].center
        var r_b = rooms[rooms.size() - 1].center
        _carve_l_corridor(grid, r_a, r_b)

func _carve_l_corridor(grid: DungeonGrid, from_pos: Vector2i, to_pos: Vector2i) -> void:
    # 50% horizontal then vertical, 50% vertical then horizontal
    var horizontal_first = randf() < 0.5
    if horizontal_first:
        _carve_h_line(grid, from_pos.x, to_pos.x, from_pos.y)
        _carve_v_line(grid, from_pos.y, to_pos.y, to_pos.x)
    else:
        _carve_v_line(grid, from_pos.y, to_pos.y, from_pos.x)
        _carve_h_line(grid, from_pos.x, to_pos.x, to_pos.y)

func _carve_h_line(grid: DungeonGrid, x1: int, x2: int, y: int) -> void:
    var start_x = mini(x1, x2)
    var end_x = maxi(x1, x2)
    for x in range(start_x, end_x + 1):
        var cell = Vector2i(x, y)
        if not _is_inside_any_room(cell):
            corridor_cells.append(cell)
        grid.set_cell_walkable(cell, true)

func _carve_v_line(grid: DungeonGrid, y1: int, y2: int, x: int) -> void:
    var start_y = mini(y1, y2)
    var end_y = maxi(y1, y2)
    for y in range(start_y, end_y + 1):
        var cell = Vector2i(x, y)
        if not _is_inside_any_room(cell):
            corridor_cells.append(cell)
        grid.set_cell_walkable(cell, true)

func _is_inside_any_room(cell: Vector2i) -> bool:
    for room in rooms:
        if room.rect.has_point(cell):
            return true
    return false

func _ensure_all_rooms_connected(grid: DungeonGrid) -> void:
    if rooms.size() < 2:
        return
    var base_center = rooms[0].center
    for i in range(1, rooms.size()):
        var target_center = rooms[i].center
        var path = grid.find_path(base_center, target_center)
        if path.is_empty():
            # Force carve direct corridor
            _carve_l_corridor(grid, base_center, target_center)

func _assign_start_and_exit(grid: DungeonGrid) -> void:
    if rooms.is_empty():
        start_cell = Vector2i(width / 2, height / 2)
        exit_cell = Vector2i(width / 2 + 2, height / 2)
        return
        
    rooms[0].is_start = true
    start_cell = rooms[0].center
    
    # Find room with highest path distance from start room (exclude bazaar rooms)
    var furthest_room = rooms[0]
    var max_dist: int = 0
    
    for i in range(1, rooms.size()):
        var r = rooms[i]
        if r.is_bazaar:
            continue
        var path = grid.find_path(start_cell, r.center)
        var p_len = path.size()
        if p_len > max_dist:
            max_dist = p_len
            furthest_room = r
            
    # Fallback if all rooms were flagged bazaar
    if furthest_room.is_bazaar and rooms.size() > 1:
        for i in range(1, rooms.size()):
            if rooms[i] != furthest_room:
                furthest_room = rooms[i]
                break
                
    furthest_room.is_exit = true
    exit_cell = furthest_room.center

func _place_secret_doors(grid: DungeonGrid, floor_number: int) -> void:
    # Identify doorway cells: walkable cells adjacent to both a room and a corridor
    for room in rooms:
        # Check room boundary perimeter
        var perimeter_cells: Array[Vector2i] = []
        var r = room.rect
        for x in range(r.position.x - 1, r.end.x + 1):
            perimeter_cells.append(Vector2i(x, r.position.y - 1))
            perimeter_cells.append(Vector2i(x, r.end.y))
        for y in range(r.position.y, r.end.y):
            perimeter_cells.append(Vector2i(r.position.x - 1, y))
            perimeter_cells.append(Vector2i(r.end.x, y))
            
        for cell in perimeter_cells:
            if grid.is_walkable(cell) and corridor_cells.has(cell):
                door_candidates.append(cell)
                
    # Place 1 to 3 secret doors on candidates
    door_candidates.shuffle()
    var count = mini(randi_range(1, 3), door_candidates.size())
    for i in range(count):
        var door_pos = door_candidates[i]
        # Hide rating scales with floor: 15.0 base + 2.0 per floor
        var hide_val = 15.0 + float(floor_number) * 2.0
        secret_door_data.append({
            "cell": door_pos,
            "hide_rating": hide_val
        })

func _place_traps(grid: DungeonGrid, floor_number: int) -> void:
    # Traps can be placed in corridors and non-start, non-bazaar rooms
    var valid_cells: Array[Vector2i] = []
    
    for c in corridor_cells:
        if c != start_cell and c != exit_cell and not _has_secret_door_at(c):
            valid_cells.append(c)
            
    for i in range(1, rooms.size()):
        var r = rooms[i]
        if r.is_bazaar:
            continue
        for y in range(r.rect.position.y + 1, r.rect.end.y - 1):
            for x in range(r.rect.position.x + 1, r.rect.end.x - 1):
                var cell = Vector2i(x, y)
                if cell != exit_cell:
                    valid_cells.append(cell)
                    
    valid_cells.shuffle()
    var trap_count = mini(randi_range(3, 6 + floor_number), valid_cells.size())
    for i in range(trap_count):
        var t_cell = valid_cells[i]
        var trap_type = randi() % 3 # 0: Spike, 1: Poison Dart, 2: Alarm
        var hide_val = 12.0 + float(floor_number) * 1.5
        trap_data.append({
            "cell": t_cell,
            "hide_rating": hide_val,
            "trap_type": trap_type
        })

func _place_enemy_spawns(_grid: DungeonGrid, floor_number: int) -> void:
    # Place 1-3 enemies in every room except start room and bazaar safe rooms
    for i in range(1, rooms.size()):
        var r = rooms[i]
        if r.is_bazaar:
            continue
        var enemy_count = randi_range(1, mini(3, 1 + floor_number / 2))
        var room_cells: Array[Vector2i] = []
        for y in range(r.rect.position.y + 1, r.rect.end.y - 1):
            for x in range(r.rect.position.x + 1, r.rect.end.x - 1):
                var cell = Vector2i(x, y)
                if cell != exit_cell and not _has_trap_at(cell):
                    room_cells.append(cell)
        room_cells.shuffle()
        for j in range(mini(enemy_count, room_cells.size())):
            enemy_spawn_cells.append(room_cells[j])

func _has_secret_door_at(cell: Vector2i) -> bool:
    for d in secret_door_data:
        if d["cell"] == cell:
            return true
    return false

func _has_trap_at(cell: Vector2i) -> bool:
    for t in trap_data:
        if t["cell"] == cell:
            return true
    return false

func _has_shrine_at(cell: Vector2i) -> bool:
    for s in shrine_data:
        if s["cell"] == cell:
            return true
    return false

func _has_chest_at(cell: Vector2i) -> bool:
    for c in chest_data:
        if c["cell"] == cell:
            return true
    return false

func _has_merchant_at(cell: Vector2i) -> bool:
    for m in merchant_spawns:
        if m["cell"] == cell:
            return true
    return false

func _has_mercenary_at(cell: Vector2i) -> bool:
    for m in mercenary_spawns:
        if m["cell"] == cell:
            return true
    return false

func _place_shrine(grid: DungeonGrid, floor_number: int, active_deity_id: String = "", betrayed_deities: Array[String] = []) -> void:
    if floor_number >= 20:
        return
        
    var shrine_cell = Vector2i.ZERO
    
    # Priority 1: Place in a secret room behind a secret door
    var hidden_room: Room = null
    for d in secret_door_data:
        var d_cell = d["cell"] as Vector2i
        for r in rooms:
            if r.is_start or r.is_exit:
                continue
            var rect = r.rect
            if (d_cell.x >= rect.position.x - 1 and d_cell.x <= rect.end.x and
                d_cell.y >= rect.position.y - 1 and d_cell.y <= rect.end.y):
                hidden_room = r
                break
        if hidden_room:
            break
            
    if hidden_room:
        shrine_cell = hidden_room.center
    else:
        # Priority 2: Room other than start or exit
        for i in range(rooms.size() - 1, 0, -1):
            var r = rooms[i]
            if not r.is_start and not r.is_exit:
                shrine_cell = r.center
                break
                
    if shrine_cell == Vector2i.ZERO or not grid.is_walkable(shrine_cell):
        for c in corridor_cells:
            if c != start_cell and c != exit_cell and not _has_trap_at(c):
                shrine_cell = c
                break
                
    if shrine_cell == Vector2i.ZERO:
        return

    # Choose deity: 65% bias to active deity, excluding betrayed
    var all_deities = ShrineData.get_pantheon_deities()
    var eligible_deities: Array[String] = []
    for d in all_deities:
        if not betrayed_deities.has(d):
            eligible_deities.append(d)
    if eligible_deities.is_empty():
        eligible_deities = all_deities.duplicate()
        
    var chosen_deity = ""
    if active_deity_id != "" and eligible_deities.has(active_deity_id):
        if randf() <= 0.65:
            chosen_deity = active_deity_id
        else:
            var other_eligible = eligible_deities.duplicate()
            other_eligible.erase(active_deity_id)
            if not other_eligible.is_empty():
                chosen_deity = other_eligible[randi() % other_eligible.size()]
            else:
                chosen_deity = active_deity_id
    else:
        chosen_deity = eligible_deities[randi() % eligible_deities.size()]
        
    shrine_data.append({
        "cell": shrine_cell,
        "deity_id": chosen_deity
    })

func _place_chests(grid: DungeonGrid, floor_number: int) -> void:
    if floor_number >= 20:
        return
    var chest_count = randi_range(1, 3)
    var candidate_cells: Array[Vector2i] = []
    
    for i in range(1, rooms.size()):
        var r = rooms[i]
        if r.is_start or r.is_exit:
            continue
        for y in range(r.rect.position.y + 1, r.rect.end.y - 1):
            for x in range(r.rect.position.x + 1, r.rect.end.x - 1):
                var cell = Vector2i(x, y)
                if not _has_shrine_at(cell) and not _has_trap_at(cell) and cell != start_cell and cell != exit_cell:
                    candidate_cells.append(cell)
                    
    candidate_cells.shuffle()
    var count = mini(chest_count, candidate_cells.size())
    for i in range(count):
        var c_cell = candidate_cells[i]
        var is_locked = randf() < 0.60
        var is_trapped = randf() < 0.45
        var hardness = 3.0 + float(floor_number) * 0.5
        var hp = 25.0 + float(floor_number) * 3.0
        var lock_diff = 15.0 + float(floor_number) * 2.0
        var trap_diff = 15.0 + float(floor_number) * 2.0
        
        # Build contents
        var contents: Array[ItemData] = []
        var gold_amt = 25 + floor_number * 10
        var pouch = ItemData.new("gold_pouch", "Pouch of %d Gold" % gold_amt, ItemData.ItemType.VALUABLE, ItemData.EquipSlot.NONE, 0.5)
        pouch.base_value_gold = gold_amt
        contents.append(pouch)
        
        # 60% chance of a healing/mana potion (fragile)
        if randf() < 0.60:
            var pot = ItemData.new("potion_heal", "Elixir of Vitality", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5)
            pot.is_fragile = true
            contents.append(pot)
            
        chest_data.append({
            "cell": c_cell,
            "is_locked": is_locked,
            "is_trapped": is_trapped,
            "hardness": hardness,
            "hp": hp,
            "lock_difficulty": lock_diff,
            "trap_difficulty": trap_diff,
            "contents": contents
        })

func _place_floor_loot(grid: DungeonGrid, floor_number: int) -> void:
    if floor_number >= 20:
        return
    var loot_count = randi_range(3, 5)
    var candidate_cells: Array[Vector2i] = []
    
    for i in range(1, rooms.size()):
        var r = rooms[i]
        for y in range(r.rect.position.y + 1, r.rect.end.y - 1):
            for x in range(r.rect.position.x + 1, r.rect.end.x - 1):
                var cell = Vector2i(x, y)
                if not _has_shrine_at(cell) and not _has_chest_at(cell) and not _has_trap_at(cell) and cell != start_cell and cell != exit_cell:
                    candidate_cells.append(cell)
                    
    candidate_cells.shuffle()
    var count = mini(loot_count, candidate_cells.size())
    for i in range(count):
        var l_cell = candidate_cells[i]
        var items: Array[ItemData] = []
        
        var roll = randf()
        if roll < 0.35:
            var gold_val = 15 + floor_number * 5
            var pouch = ItemData.new("gold_pouch", "%d Gold Coins" % gold_val, ItemData.ItemType.VALUABLE, ItemData.EquipSlot.NONE, 0.5)
            pouch.base_value_gold = gold_val
            items.append(pouch)
        elif roll < 0.65:
            var pot = ItemData.new("potion_heal", "Minor Health Draught", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5)
            pot.is_fragile = true
            items.append(pot)
        else:
            var arrows = ItemData.new("ammo_arrows", "Bundle of Arrows (15)", ItemData.ItemType.AMMO, ItemData.EquipSlot.AMMUNITION, 1.0, 15)
            items.append(arrows)
            
        floor_loot_data.append({
            "cell": l_cell,
            "items": items
        })

func _place_merchants(grid: DungeonGrid, floor_number: int) -> void:
    if floor_number >= 20:
        return
        
    var is_bazaar_floor = (floor_number % 4 == 0)
    var depth_tier = clampi((floor_number - 1) / 4 + 1, 1, 5)
    
    if is_bazaar_floor:
        # Find the dedicated Grand Bazaar Sanctuary Room
        var bazaar_room: Room = null
        for r in rooms:
            if r.is_bazaar:
                bazaar_room = r
                break
        if not bazaar_room:
            # Fallback: find largest room that isn't start or exit
            var best_area = 0
            for i in range(1, rooms.size()):
                var r = rooms[i]
                if not r.is_start and not r.is_exit:
                    var area = r.rect.size.x * r.rect.size.y
                    if area > best_area:
                        best_area = area
                        bazaar_room = r
            if bazaar_room:
                bazaar_room.is_bazaar = true
                
        if bazaar_room:
            # Select 3 to 4 distinct merchant stalls from the 5 specialist categories
            var all_specialties = [
                MerchantCatalog.Specialty.POTION_APOTHECARY,
                MerchantCatalog.Specialty.WEAPON_ARMORY,
                MerchantCatalog.Specialty.MAGIC_SCRIBES,
                MerchantCatalog.Specialty.UNIQUE_CURIOS,
                MerchantCatalog.Specialty.GENERAL_OUTFITTER
            ]
            all_specialties.shuffle()
            var stall_count = randi_range(3, 4)
            var selected_specialties = all_specialties.slice(0, stall_count)
            
            # Collect candidate walkable cells inside bazaar room (buffered from wall perimeter)
            var stall_cells: Array[Vector2i] = []
            var br = bazaar_room.rect
            for y in range(br.position.y + 1, br.end.y - 1):
                for x in range(br.position.x + 1, br.end.x - 1):
                    var cell = Vector2i(x, y)
                    if grid.is_walkable(cell) and cell != start_cell and cell != exit_cell:
                        stall_cells.append(cell)
            stall_cells.shuffle()
            
            # Distribute stalls with spacing
            var chosen_cells: Array[Vector2i] = []
            for cell in stall_cells:
                var too_close = false
                for chosen in chosen_cells:
                    if abs(cell.x - chosen.x) + abs(cell.y - chosen.y) < 2:
                        too_close = true
                        break
                if not too_close:
                    chosen_cells.append(cell)
                    if chosen_cells.size() >= selected_specialties.size():
                        break
                        
            # If spacing too strict, fallback to any valid cell in bazaar room
            if chosen_cells.size() < selected_specialties.size():
                for cell in stall_cells:
                    if not chosen_cells.has(cell):
                        chosen_cells.append(cell)
                        if chosen_cells.size() >= selected_specialties.size():
                            break
                            
            for idx in range(mini(selected_specialties.size(), chosen_cells.size())):
                var spec = selected_specialties[idx]
                var c_cell = chosen_cells[idx]
                var m_info = MerchantCatalog.get_random_merchant_for_specialty(spec)
                merchant_spawns.append({
                    "cell": c_cell,
                    "specialty": spec,
                    "stall_type": spec,
                    "merchant_id": m_info.get("merchant_id", ""),
                    "display_name": m_info.get("display_name", "Merchant"),
                    "merchant_info": m_info,
                    "depth_tier": depth_tier
                })
    else:
        # Non-bazaar floor: 10% chance to spawn 1 random specialist merchant in standard room
        if randf() <= 0.10:
            var all_specialties = [
                MerchantCatalog.Specialty.POTION_APOTHECARY,
                MerchantCatalog.Specialty.WEAPON_ARMORY,
                MerchantCatalog.Specialty.MAGIC_SCRIBES,
                MerchantCatalog.Specialty.UNIQUE_CURIOS,
                MerchantCatalog.Specialty.GENERAL_OUTFITTER
            ]
            var spec = all_specialties[randi() % all_specialties.size()]
            var candidate_cells: Array[Vector2i] = []
            for i in range(1, rooms.size()):
                var r = rooms[i]
                if r.is_start or r.is_exit:
                    continue
                for y in range(r.rect.position.y + 1, r.rect.end.y - 1):
                    for x in range(r.rect.position.x + 1, r.rect.end.x - 1):
                        var cell = Vector2i(x, y)
                        if not _has_trap_at(cell) and not _has_shrine_at(cell) and not _has_chest_at(cell) and cell != start_cell and cell != exit_cell:
                            candidate_cells.append(cell)
            if not candidate_cells.is_empty():
                candidate_cells.shuffle()
                var m_info = MerchantCatalog.get_random_merchant_for_specialty(spec)
                merchant_spawns.append({
                    "cell": candidate_cells[0],
                    "specialty": spec,
                    "stall_type": spec,
                    "merchant_id": m_info.get("merchant_id", ""),
                    "display_name": m_info.get("display_name", "Merchant"),
                    "merchant_info": m_info,
                    "depth_tier": depth_tier
                })

func _place_mercenaries(grid: DungeonGrid, floor_number: int) -> void:
    if floor_number >= 20:
        return
        
    var depth_tier = clampi((floor_number - 1) / 4 + 1, 1, 5)
    var is_bazaar_floor = (floor_number % 4 == 0)
    
    if is_bazaar_floor:
        var bazaar_room: Room = null
        for r in rooms:
            if r.is_bazaar:
                bazaar_room = r
                break
        if bazaar_room:
            var candidate_cells: Array[Vector2i] = []
            var br = bazaar_room.rect
            for y in range(br.position.y + 1, br.end.y - 1):
                for x in range(br.position.x + 1, br.end.x - 1):
                    var cell = Vector2i(x, y)
                    if grid.is_walkable(cell) and cell != start_cell and cell != exit_cell and not _has_merchant_at(cell) and not _has_mercenary_at(cell):
                        candidate_cells.append(cell)
            if not candidate_cells.is_empty():
                candidate_cells.shuffle()
                var merc_count = randi_range(1, 2)
                for i in range(mini(merc_count, candidate_cells.size())):
                    var cell = candidate_cells[i]
                    var comp_data = CompanionData.create_mercenary_for_tier(depth_tier)
                    mercenary_spawns.append({
                        "cell": cell,
                        "depth_tier": depth_tier,
                        "companion_data": comp_data
                    })
    else:
        if randf() <= 0.10:
            var candidate_cells: Array[Vector2i] = []
            for i in range(1, rooms.size()):
                var r = rooms[i]
                if r.is_start or r.is_exit or r.is_bazaar:
                    continue
                for y in range(r.rect.position.y + 1, r.rect.end.y - 1):
                    for x in range(r.rect.position.x + 1, r.rect.end.x - 1):
                        var cell = Vector2i(x, y)
                        if grid.is_walkable(cell) and not _has_trap_at(cell) and not _has_shrine_at(cell) and not _has_chest_at(cell) and not _has_merchant_at(cell) and not _has_mercenary_at(cell) and cell != start_cell and cell != exit_cell:
                            candidate_cells.append(cell)
            if not candidate_cells.is_empty():
                candidate_cells.shuffle()
                var cell = candidate_cells[0]
                var comp_data = CompanionData.create_mercenary_for_tier(depth_tier)
                mercenary_spawns.append({
                    "cell": cell,
                    "depth_tier": depth_tier,
                    "companion_data": comp_data
                })

## Floor 20: The Grandmaster Sanctum
## Fixed hand-crafted 32x24 arena with 4 indestructible cover pillars,
## central dais, south entrance, and suppressed stairs until boss demise.
func _generate_floor_20_sanctum(grid: DungeonGrid) -> Dictionary:
    var arena_w = 32
    var arena_h = 24
    grid.clear_grid()
    grid.grid_width = arena_w
    grid.grid_height = arena_h
    
    # 1. Fill entire 32x24 grid with walls
    for y in range(arena_h):
        for x in range(arena_w):
            grid.set_cell_walkable(Vector2i(x, y), false)
            
    # 2. Carve open hall from (2, 2) to (29, 21)
    for y in range(2, 22):
        for x in range(2, 30):
            grid.set_cell_walkable(Vector2i(x, y), true)
            
    # 3. Create 4 indestructible cover pillars (2x2 wall monoliths)
    var pillar_corners = [
        Vector2i(8, 6),   # NW
        Vector2i(22, 6),  # NE
        Vector2i(8, 15),  # SW
        Vector2i(22, 15)  # SE
    ]
    var pillar_cells: Array[Vector2i] = []
    for corner in pillar_corners:
        for py in range(2):
            for px in range(2):
                var p_cell = corner + Vector2i(px, py)
                grid.set_cell_walkable(p_cell, false)
                pillar_cells.append(p_cell)
                
    # 4. Central Dais (at 16, 11) and Player Start (at 16, 20)
    var boss_spawn = Vector2i(16, 11)
    var p_start = Vector2i(16, 20)
    
    start_cell = p_start
    exit_cell = Vector2i(-1, -1) # Suppressed until boss is defeated
    
    var sanctum_room = Room.new(0, Rect2i(2, 2, 28, 20))
    sanctum_room.is_start = true
    rooms.append(sanctum_room)
    
    grid.rebuild_astar()
    
    return {
        "start_cell": start_cell,
        "exit_cell": exit_cell,
        "boss_spawn": boss_spawn,
        "pillars": pillar_cells,
        "rooms": rooms,
        "corridors": [],
        "secret_doors": [],
        "traps": [],
        "enemy_spawns": [],
        "shrines": [],
        "chests": [],
        "floor_loot": [],
        "merchant_spawns": [],
        "mercenary_spawns": [],
        "stairs_suppressed": true
    }

