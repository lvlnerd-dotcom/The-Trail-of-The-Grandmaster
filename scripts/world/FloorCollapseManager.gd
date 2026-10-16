class_name FloorCollapseManager
extends Node

## FloorCollapseManager: Manages floor turn timer countdown, escalating tremors, and cave-in events.

enum CollapseStage {
    STABLE,       # > 200 turns
    TREMORS,      # 101 - 200 turns
    COLLAPSING,   # 26 - 100 turns
    IMMINENT,     # 1 - 25 turns
    COLLAPSED     # <= 0 turns
}

signal collapse_stage_changed(new_stage: CollapseStage)
signal tremor_occurred(intensity: float, message: String)
signal floor_collapsed()

@export var camera: DungeonCamera = null

var current_stage: CollapseStage = CollapseStage.STABLE
var turns_in_stage: int = 0

func _get_event_bus() -> Node:
    var loop = Engine.get_main_loop()
    if loop and loop is SceneTree:
        return (loop as SceneTree).root.get_node_or_null("EventBus")
    return null

func get_stage_for_turns(turns_left: int) -> CollapseStage:
    if turns_left > 200:
        return CollapseStage.STABLE
    elif turns_left > 100:
        return CollapseStage.TREMORS
    elif turns_left > 25:
        return CollapseStage.COLLAPSING
    elif turns_left > 0:
        return CollapseStage.IMMINENT
    else:
        return CollapseStage.COLLAPSED

func get_stage_name(stage: CollapseStage = current_stage) -> String:
    match stage:
        CollapseStage.STABLE: return "STABLE"
        CollapseStage.TREMORS: return "TREMORS"
        CollapseStage.COLLAPSING: return "COLLAPSING SOON"
        CollapseStage.IMMINENT: return "IMMINENT COLLAPSE"
        CollapseStage.COLLAPSED: return "COLLAPSED"
        _: return "UNKNOWN"

func process_turn_tick(turns_left: int, total_turns: int) -> Dictionary:
    var new_stage = get_stage_for_turns(turns_left)
    var stage_changed = (new_stage != current_stage)
    if stage_changed:
        current_stage = new_stage
        emit_signal("collapse_stage_changed", current_stage)
        var bus = _get_event_bus()
        if bus and bus.has_signal("collapse_stage_changed"):
            bus.emit_signal("collapse_stage_changed", current_stage)
            
    var tremor_intensity = 0.0
    var message = ""
    
    match current_stage:
        CollapseStage.STABLE:
            # Normal steady state
            pass
        CollapseStage.TREMORS:
            # Mild tremor every 15 turns or on stage change
            if stage_changed or turns_left % 15 == 0:
                tremor_intensity = 0.20
                message = "The ceiling groans... Distant stone tremors rumble through the floor."
        CollapseStage.COLLAPSING:
            # Moderate tremors every 5 turns
            if stage_changed or turns_left % 5 == 0:
                tremor_intensity = 0.45
                message = "WARNING: Deep fractures appear in the walls! Falling dust and pebbles shower the corridor!"
        CollapseStage.IMMINENT:
            # Severe tremors every single turn!
            tremor_intensity = 0.75
            message = "CRITICAL DANGER: THE CEILING IS COLLAPSING! (%d turns remaining!)" % turns_left
        CollapseStage.COLLAPSED:
            tremor_intensity = 1.0
            message = "THE DUNGEON HAS COLLAPSED! Tons of solid granite crash down, crushing everything!"
            emit_signal("floor_collapsed")
            var bus = _get_event_bus()
            if bus and bus.has_signal("floor_collapsed"):
                bus.emit_signal("floor_collapsed")
                
    if tremor_intensity > 0.0 and camera:
        camera.add_trauma(tremor_intensity)
        emit_signal("tremor_occurred", tremor_intensity, message)
        
    return {
        "stage": current_stage,
        "stage_name": get_stage_name(),
        "stage_changed": stage_changed,
        "tremor_intensity": tremor_intensity,
        "message": message,
        "turns_left": turns_left,
        "total_turns": total_turns
    }
