class_name InspectionData
extends Resource

## InspectionData: Data contract representing an inspected tile, creature, hazard, or object.

enum Category {
	UNKNOWN,
	TERRAIN,
	HOSTILE,
	ALLY_OR_NPC,
	HAZARD,
	ITEM_OR_OBJECT
}

@export var title: String = "Unexplored Darkness"
@export var category: Category = Category.UNKNOWN
@export var category_text: String = "Fog of War"
@export var health_status_text: String = ""
@export var health_status_color: Color = Color.WHITE
@export var description: String = "Move cursor over a visible or explored tile."
@export var icon: Texture2D = null
@export var icon_glyph: String = "?"
@export var accent_color: Color = Color(0.55, 0.60, 0.68, 1.0)
@export var grid_cell: Vector2i = Vector2i(-1, -1)
@export var is_remembered_only: bool = false

static func create(
	p_title: String,
	p_category: Category,
	p_category_text: String,
	p_description: String,
	p_glyph: String = "?",
	p_color: Color = Color(0.8, 0.85, 0.95, 1.0),
	p_icon: Texture2D = null
) -> InspectionData:
	var data = InspectionData.new()
	data.title = p_title
	data.category = p_category
	data.category_text = p_category_text
	data.description = p_description
	data.icon_glyph = p_glyph
	data.accent_color = p_color
	data.icon = p_icon
	return data
