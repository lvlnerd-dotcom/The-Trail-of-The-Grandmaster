@tool
extends McpTestSuite

## Phase 4 Test Suite: Procedural Dungeon Generation, Guaranteed Reachability,
## Secret Doors, Traps, Perception Scanning, Stairs Descent, and Floor Collapse Clock.

func suite_name() -> String:
    return "phase4_dungeon_and_collapse"

func test_dungeon_procedural_generation_connectivity() -> void:
    var grid: DungeonGrid = track(DungeonGrid.new()) as DungeonGrid
    var generator = DungeonGenerator.new(40, 30)
    
    # Generate floor with deterministic seed
    var result = generator.generate_dungeon(grid, 1, 42)
    
    # 1. Rooms must be generated within grid bounds
    assert_true(result["rooms"].size() >= 3, "Generator must produce at least 3 rooms")
    for room in result["rooms"]:
        assert_true(room.rect.position.x >= 0, "Room X must be >= 0")
        assert_true(room.rect.position.y >= 0, "Room Y must be >= 0")
        assert_true(room.rect.end.x <= grid.grid_width, "Room right edge must be within grid width")
        assert_true(room.rect.end.y <= grid.grid_height, "Room bottom edge must be within grid height")
        
    # 2. Start cell and Exit cell must be distinct and walkable
    var start_cell = result["start_cell"] as Vector2i
    var exit_cell = result["exit_cell"] as Vector2i
    assert_ne(start_cell, exit_cell, "Start cell and Exit cell must not be identical")
    assert_true(grid.is_walkable(start_cell), "Start cell must be walkable")
    assert_true(grid.is_walkable(exit_cell), "Exit cell must be walkable")
    
    # 3. Guaranteed Reachability: AStar path must exist between start and exit
    var path = grid.find_path(start_cell, exit_cell)
    assert_true(path.size() >= 2, "AStar path must connect start room to exit room")
    
    # 4. Every room must have a valid path to start room
    for room in result["rooms"]:
        var room_path = grid.find_path(start_cell, room.center)
        assert_true(room_path.size() > 0, "Every room center must be connected to start cell")

func test_secret_door_concealment_and_reveal() -> void:
    var grid: DungeonGrid = track(DungeonGrid.new()) as DungeonGrid
    grid.grid_width = 10
    grid.grid_height = 10
    grid.clear_grid()
    
    # Set up a room and corridor separated by a door at (5, 5)
    for x in range(10):
        for y in range(10):
            grid.set_cell_walkable(Vector2i(x, y), true)
            
    var door_cell = Vector2i(5, 5)
    var door: SecretDoor = track(SecretDoor.new()) as SecretDoor
    door.setup(grid, door_cell, 20.0)
    
    # 1. Before reveal: door acts as solid wall, blocking movement
    assert_false(door.is_revealed, "Door must be concealed initially")
    assert_false(grid.is_walkable(door_cell), "Concealed secret door must block walking")
    
    # 2. Perception check detection formula
    var player: Node2D = track(Node2D.new()) as Node2D
    var stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
    stats.name = "StatsComponent"
    var skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
    skills.name = "SkillComponent"
    player.add_child(stats)
    player.add_child(skills)
    stats.attributes.wisdom = 10
    skills.get_skill(SkillData.SkillId.PERCEPTION).level = 10.0 # Effective = 10 + 5 = 15.0
    
    # Observer perception 15 vs Door hide 20: (15 + 50) / ((20 + 50) * 2) = 65 / 140 = 0.4643
    var det_chance = VisionComponent.calculate_detection_chance(player, door)
    assert_true(is_equal_approx(det_chance, 65.0 / 140.0), "Perception vs secret door hide rating must match formula")
    
    # 3. Reveal door: must unlock passage
    door.reveal()
    assert_true(door.is_revealed, "Door must be marked revealed")
    assert_true(grid.is_walkable(door_cell), "Revealed door must be walkable")

func test_trap_trigger_and_armor_mitigation() -> void:
    var grid: DungeonGrid = track(DungeonGrid.new()) as DungeonGrid
    grid.grid_width = 10
    grid.grid_height = 10
    for x in range(10):
        for y in range(10):
            grid.set_cell_walkable(Vector2i(x, y), true)
            
    var trap_cell = Vector2i(4, 4)
    var trap: Trap = track(Trap.new()) as Trap
    trap.setup(grid, trap_cell, Trap.TrapType.SPIKE, 18.0)
    
    assert_false(trap.is_revealed, "Trap must be hidden initially")
    assert_false(trap.is_triggered, "Trap must be untriggered initially")
    assert_true(grid.is_walkable(trap_cell), "Traps must not block walking on grid")
    
    # Setup player with 100 HP and 6 Armor from shield
    var player: Node2D = track(Node2D.new()) as Node2D
    var stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
    stats.name = "StatsComponent"
    var inv: InventoryComponent = track(InventoryComponent.new()) as InventoryComponent
    inv.name = "InventoryComponent"
    player.add_child(stats)
    player.add_child(inv)
    stats.current_hp = 100.0
    
    var armor_item = track(ItemData.new("iron_armor", "Iron Cuirass", ItemData.ItemType.ARMOR, ItemData.EquipSlot.BODY, 6.0)) as ItemData
    armor_item.armor_value = 6
    inv.equip_item(armor_item)
    
    # Step on trap
    var result = trap.trigger(player)
    assert_true(trap.is_triggered, "Trap must be triggered after step")
    assert_true(trap.is_revealed, "Trap must be revealed after triggering")
    assert_true(result["damage"] > 0, "Spike trap must deal damage")
    assert_true(stats.current_hp < 100.0, "Player must take damage from spike trap")

func test_floor_collapse_stages_and_countdown() -> void:
    var collapse_mgr: FloorCollapseManager = track(FloorCollapseManager.new()) as FloorCollapseManager
    
    # Stage verification per turn counts
    assert_eq(collapse_mgr.get_stage_for_turns(250), FloorCollapseManager.CollapseStage.STABLE, "> 200 turns must be STABLE")
    assert_eq(collapse_mgr.get_stage_for_turns(150), FloorCollapseManager.CollapseStage.TREMORS, "101-200 turns must be TREMORS")
    assert_eq(collapse_mgr.get_stage_for_turns(50), FloorCollapseManager.CollapseStage.COLLAPSING, "26-100 turns must be COLLAPSING")
    assert_eq(collapse_mgr.get_stage_for_turns(10), FloorCollapseManager.CollapseStage.IMMINENT, "1-25 turns must be IMMINENT")
    assert_eq(collapse_mgr.get_stage_for_turns(0), FloorCollapseManager.CollapseStage.COLLAPSED, "<= 0 turns must be COLLAPSED")
    
    # Process turn tick: at 15 turns left, must be IMMINENT with high tremor intensity
    var tick_imminent = collapse_mgr.process_turn_tick(15, 800)
    assert_eq(tick_imminent["stage"], FloorCollapseManager.CollapseStage.IMMINENT, "Stage must transition to IMMINENT")
    assert_true(tick_imminent["tremor_intensity"] >= 0.7, "Imminent collapse must cause intense tremors")
    
    # Expiration: at 0 turns, must report COLLAPSED
    var tick_collapsed = collapse_mgr.process_turn_tick(0, 800)
    assert_eq(tick_collapsed["stage"], FloorCollapseManager.CollapseStage.COLLAPSED, "Stage must be COLLAPSED at 0 turns")

func test_stairs_down_descent_interaction() -> void:
    var grid: DungeonGrid = track(DungeonGrid.new()) as DungeonGrid
    grid.grid_width = 10
    grid.grid_height = 10
    for x in range(10):
        for y in range(10):
            grid.set_cell_walkable(Vector2i(x, y), true)
            
    var exit_pos = Vector2i(7, 7)
    var stairs: StairsDown = track(StairsDown.new()) as StairsDown
    stairs.setup(grid, exit_pos, 1)
    
    var player: BaseEntity = track(BaseEntity.new()) as BaseEntity
    player.init_grid_position(grid, Vector2i(2, 2))
    
    # Player not on stairs: cannot descend
    assert_false(stairs.can_descend(player), "Player at (2, 2) cannot descend stairs at (7, 7)")
    
    # Move player to stairs cell: can descend
    player.grid_pos = exit_pos
    assert_true(stairs.can_descend(player), "Player on stairs cell must be able to descend")
