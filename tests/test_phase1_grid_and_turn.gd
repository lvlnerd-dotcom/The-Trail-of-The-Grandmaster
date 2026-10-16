@tool
extends McpTestSuite

## Phase 1 Test Suite: Core Grid, Entity Model & Turn Loop

func suite_name() -> String:
    return "phase1_grid_and_turn"

func test_grid_coordinate_conversion() -> void:
    var grid: DungeonGrid = track(DungeonGrid.new()) as DungeonGrid
    grid.tile_size = Vector2i(32, 32)
    
    var test_cells = [Vector2i(0, 0), Vector2i(5, 10), Vector2i(19, 14), Vector2i(40, 25)]
    for cell in test_cells:
        var world_pos = grid.grid_to_world(cell)
        var converted_cell = grid.world_to_grid(world_pos)
        assert_eq(converted_cell, cell, "Coordinate round-trip must match")

func test_grid_occupancy_and_movement() -> void:
    var grid: DungeonGrid = track(DungeonGrid.new()) as DungeonGrid
    grid.grid_width = 10
    grid.grid_height = 10
    
    for y in range(10):
        for x in range(10):
            grid.set_cell_walkable(Vector2i(x, y), true)
            
    var dummy_entity: Node2D = track(Node2D.new()) as Node2D
    var start_cell = Vector2i(3, 3)
    var target_cell = Vector2i(3, 4)
    
    # Test registration
    var reg_ok = grid.register_entity(dummy_entity, start_cell)
    assert_true(reg_ok, "Registration should succeed on empty walkable cell")
    assert_true(grid.is_occupied(start_cell), "Cell (3, 3) must be occupied")
    assert_eq(grid.get_occupant(start_cell), dummy_entity, "Occupant must match dummy entity")
    assert_false(grid.can_enter(start_cell), "Cannot enter an occupied cell")
    
    # Test movement
    var move_ok = grid.move_entity(dummy_entity, start_cell, target_cell)
    assert_true(move_ok, "Movement should succeed to free neighbor cell")
    assert_false(grid.is_occupied(start_cell), "Previous cell must now be empty")
    assert_true(grid.is_occupied(target_cell), "Target cell must now be occupied")
    
    # Test unregistration
    grid.unregister_entity(dummy_entity, target_cell)
    assert_false(grid.is_occupied(target_cell), "Target cell must be empty after unregister")

func test_grid_walls_and_astar_pathfinding() -> void:
    var grid: DungeonGrid = track(DungeonGrid.new()) as DungeonGrid
    grid.grid_width = 10
    grid.grid_height = 10
    
    for y in range(10):
        for x in range(10):
            grid.set_cell_walkable(Vector2i(x, y), true)
            
    # Place wall obstacle blocking direct horizontal path at (2, 1)
    grid.set_cell_walkable(Vector2i(2, 1), false)
    assert_false(grid.is_walkable(Vector2i(2, 1)), "Cell (2, 1) must not be walkable")
    assert_false(grid.can_enter(Vector2i(2, 1)), "Cell (2, 1) cannot be entered")
    
    grid.rebuild_astar()
    
    var path = grid.find_path(Vector2i(1, 1), Vector2i(3, 1))
    assert_gt(path.size(), 2, "Path must route around wall at (2, 1)")
    assert_false(path.has(Vector2i(2, 1)), "Path must not contain the wall tile")
    assert_eq(path[0], Vector2i(1, 1), "Path start must match")
    assert_eq(path[path.size() - 1], Vector2i(3, 1), "Path destination must match")

func test_turn_manager_cycling_and_floor_budget() -> void:
    var turn_mgr: TurnManager = track(TurnManager.new()) as TurnManager
    
    # Floor 1: 800 - 15 = 785
    turn_mgr.init_floor_timer(1)
    assert_eq(turn_mgr.floor_total_turns, 785, "Floor 1 total turns must be 785")
    assert_eq(turn_mgr.floor_turns_remaining, 785, "Floor 1 turns remaining must start at 785")
    assert_eq(turn_mgr.turn_number, 1, "Initial turn must be 1")
    assert_true(turn_mgr.can_accept_player_input(), "Should accept input initially")
    
    # Simulate a wait turn with immediate resolve
    turn_mgr.submit_player_action("wait", {"immediate_resolve": true})
    
    assert_eq(turn_mgr.turn_number, 2, "Turn number must advance to 2")
    assert_eq(turn_mgr.floor_turns_remaining, 784, "Remaining turns must decrement to 784")
    assert_eq(turn_mgr.current_state, TurnManager.TurnState.WAITING_FOR_INPUT, "State must cycle back to WAITING_FOR_INPUT")
    
    # Floor 2: 800 - 30 = 770
    turn_mgr.init_floor_timer(2)
    assert_eq(turn_mgr.floor_total_turns, 770, "Floor 2 total turns must be 770")
