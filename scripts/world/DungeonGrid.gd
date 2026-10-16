class_name DungeonGrid
extends Node2D

## DungeonGrid: Manages 2D grid coordinates, tile occupancy, walls, and AStar2D pathfinding.

@export var tile_size: Vector2i = Vector2i(32, 32)
@export var grid_width: int = 40
@export var grid_height: int = 30

# State dictionaries: Vector2i -> Variant
var walkable_cells: Dictionary = {} # Vector2i -> bool
var wall_cells: Dictionary = {}     # Vector2i -> bool
var occupants: Dictionary = {}      # Vector2i -> Node2D

# AStar2D instance for pathfinding
var astar: AStar2D = AStar2D.new()

func _ready() -> void:
    pass

func clear_grid() -> void:
    walkable_cells.clear()
    wall_cells.clear()
    occupants.clear()
    astar.clear()

func set_cell_walkable(cell: Vector2i, walkable: bool) -> void:
    if walkable:
        walkable_cells[cell] = true
        wall_cells.erase(cell)
    else:
        walkable_cells.erase(cell)
        wall_cells[cell] = true

func is_walkable(cell: Vector2i) -> bool:
    if wall_cells.has(cell):
        return false
    if not walkable_cells.is_empty():
        return walkable_cells.has(cell)
    # If no specific floor map defined, check within default grid boundaries
    return cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height

func is_occupied(cell: Vector2i) -> bool:
    return occupants.has(cell) and is_instance_valid(occupants[cell])

func get_occupant(cell: Vector2i) -> Node2D:
    if is_occupied(cell):
        return occupants[cell]
    return null

func can_enter(cell: Vector2i) -> bool:
    return is_walkable(cell) and not is_occupied(cell)

func register_entity(entity: Node2D, cell: Vector2i) -> bool:
    if is_occupied(cell):
        var current = occupants[cell]
        if current != entity:
            push_warning("Cell %s is already occupied by %s" % [cell, current])
            return false
    occupants[cell] = entity
    return true

func unregister_entity(entity: Node2D, cell: Vector2i) -> void:
    if occupants.has(cell) and occupants[cell] == entity:
        occupants.erase(cell)

func move_entity(entity: Node2D, from_cell: Vector2i, to_cell: Vector2i) -> bool:
    if not can_enter(to_cell):
        return false
    unregister_entity(entity, from_cell)
    register_entity(entity, to_cell)
    return true

# Coordinate conversions
func grid_to_world(grid_pos: Vector2i) -> Vector2:
    return Vector2(
        grid_pos.x * tile_size.x + (tile_size.x * 0.5),
        grid_pos.y * tile_size.y + (tile_size.y * 0.5)
    )

func cell_to_world(cell: Vector2i) -> Vector2:
    return grid_to_world(cell)

func world_to_grid(world_pos: Vector2) -> Vector2i:
    return Vector2i(
        int(floor(world_pos.x / tile_size.x)),
        int(floor(world_pos.y / tile_size.y))
    )

# AStar2D integration
func cell_to_point_id(cell: Vector2i) -> int:
    return cell.y * 10000 + cell.x

func point_id_to_cell(id: int) -> Vector2i:
    var y = int(floor(float(id) / 10000.0))
    var x = id % 10000
    return Vector2i(x, y)

func rebuild_astar() -> void:
    astar.clear()
    for cell in walkable_cells.keys():
        var point_id = cell_to_point_id(cell)
        astar.add_point(point_id, Vector2(cell.x, cell.y))
    
    # Connect 4-way and 8-way neighbors
    var directions = [
        Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
        Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
    ]
    
    for cell in walkable_cells.keys():
        var from_id = cell_to_point_id(cell)
        for dir in directions:
            var neighbor = cell + dir
            if walkable_cells.has(neighbor):
                var to_id = cell_to_point_id(neighbor)
                if not astar.are_points_connected(from_id, to_id):
                    # For diagonals, check orthogonal corners to prevent corner cutting
                    if dir.x != 0 and dir.y != 0:
                        var corner_a = Vector2i(cell.x + dir.x, cell.y)
                        var corner_b = Vector2i(cell.x, cell.y + dir.y)
                        if not walkable_cells.has(corner_a) or not walkable_cells.has(corner_b):
                            continue
                    astar.connect_points(from_id, to_id, true)

func find_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
    var from_id = cell_to_point_id(from_cell)
    var to_id = cell_to_point_id(to_cell)
    if not astar.has_point(from_id) or not astar.has_point(to_id):
        return []
    
    var point_path = astar.get_point_path(from_id, to_id)
    var grid_path: Array[Vector2i] = []
    for pt in point_path:
        grid_path.append(Vector2i(int(pt.x), int(pt.y)))
    return grid_path
