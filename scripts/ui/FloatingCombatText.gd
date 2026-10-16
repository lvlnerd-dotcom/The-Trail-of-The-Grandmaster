class_name FloatingCombatText
extends Node2D

## FloatingCombatText: Animates floating combat numbers, crits, dodges, and status popups.

@onready var label: Label = $Label

func setup(text_content: String, color: Color, start_world_pos: Vector2) -> void:
    global_position = start_world_pos + Vector2(randf_range(-6.0, 6.0), -12.0)
    label.text = text_content
    label.modulate = color
    
    var tween = create_tween().set_parallel(true)
    tween.tween_property(self, "global_position:y", global_position.y - 24.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_LINEAR)
    tween.chain().tween_callback(queue_free)
