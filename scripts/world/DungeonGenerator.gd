class_name DungeonGenerator
extends RefCounted

## DungeonGenerator: Procedural room-and-corridor generator with guaranteed connectivity.

class Room:
    var id: int
    var rect: Rect2i
    var is_start: bool = false
    var is_exit: bool = false
    
    var center: Vector2i:
        get:
            return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
            
    func _init(p_id: int, p_rect: Rect2i) -> void:
        id = p_id
        rect = p_rect

# Generator Configuration
var width: int = 48
var height: int = 36
var min_room_size: int = 5
var max_room_size: int = 10
var max_rooms: int = 10
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

func _init(p_width: int = 48, p_height: int = 36) -> void:
    width = p_width
    height = p_height

## Generates a complete floor layout onto the provided DungeonGrid.
func generate_dungeon(grid: DungeonGrid, floor_number: int = 1, seed_val: int = -1) -> Dictionary:
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
    
    # Floor 20: The Grandmaster Sanctum (Fixed Hand-Crafted 32x24 Boss Arena)
    if floor_number == 20:
        return _generate_floor_20_sanctum(grid)
    
    # 1. Fill entire grid with walls initially
    for y in range(height):
        for x in range(width):
            grid.set_cell_walkable(Vector2i(x, y), false)
            
    # 2. Generate non-overlapping rooms
    _generate_rooms(grid)
    
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
    
    # 7. Place Traps along corridors and rooms
    _place_traps(grid, floor_number)
    
    # 8. Place Enemy Spawns in rooms
    _place_enemy_spawns(grid, floor_number)
    
    grid.rebuild_astar()
    
    return {
        "start_cell": start_cell,
        "exit_cell": exit_cell,
        "rooms": rooms,
        "corridors": corridor_cells,
        "secret_doors": secret_door_data,
        "traps": trap_data,
        "enemy_spawns": enemy_spawn_cells
    }

func _generate_rooms(grid: DungeonGrid) -> void:
    var attempts = 0
    var max_attempts = 100
    
    while rooms.size() < max_rooms and attempts < max_attempts:
        attempts += 1
        var rw = randi_range(min_room_size, max_room_size)
        var rh = randi_range(min_room_size, max_room_size)
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
            rooms.append(room)
            
            # Carve room floors into grid
            for y in range(new_rect.position.y, new_rect.end.y):
                for x in range(new_rect.position.x, new_rect.end.x):
                    grid.set_cell_walkable(Vector2i(x, y), true)

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
    
    # Find room with highest path distance from start room
    var furthest_room = rooms[0]
    var max_dist: int = 0
    
    for i in range(1, rooms.size()):
        var r = rooms[i]
        var path = grid.find_path(start_cell, r.center)
        var p_len = path.size()
        if p_len > max_dist:
            max_dist = p_len
            furthest_room = r
            
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
    # Traps can be placed in corridors and non-start rooms
    var valid_cells: Array[Vector2i] = []
    
    for c in corridor_cells:
        if c != start_cell and c != exit_cell and not _has_secret_door_at(c):
            valid_cells.append(c)
            
    for i in range(1, rooms.size()):
        var r = rooms[i]
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
    # Place 1-3 enemies in every room except start room
    for i in range(1, rooms.size()):
        var r = rooms[i]
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
        "stairs_suppressed": true
    }

