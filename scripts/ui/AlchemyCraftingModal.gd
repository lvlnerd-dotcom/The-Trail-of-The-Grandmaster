@tool
class_name AlchemyCraftingModal
extends BaseModal

## AlchemyCraftingModal: Portable alchemy workshop interface accessed via Mortar and Pestle.
## Combines dungeon reagents into known potions anywhere in the dungeon, training Alchemy.

signal crafting_completed(recipe_id: String, result: Dictionary)

@onready var label_title: Label = $VBox/HeaderBar/LabelTitle
@onready var btn_close: Button = $VBox/HeaderBar/BtnClose
@onready var label_reagents: Label = $VBox/ReagentsBar/LabelReagents
@onready var recipes_container: VBoxContainer = $VBox/ScrollRecipes/RecipesList
@onready var label_status: Label = $VBox/FooterBar/LabelStatus

var player: Node2D = null

func _ready() -> void:
	close_on_escape = true
	super._ready()
	if btn_close:
		btn_close.pressed.connect(close_modal)

func open_modal_with_player(p_player: Node2D) -> void:
	player = p_player
	super.open_modal()
	refresh_view()

func refresh_view() -> void:
	if not is_instance_valid(player):
		close_modal()
		return

	var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if not inv:
		return

	# 1. Update Reagents Bar
	if label_reagents:
		var reg_counts: Array[String] = []
		for reg_id in AlchemyCatalog.REAGENTS.keys():
			var r_def = AlchemyCatalog.REAGENTS[reg_id]
			var c = inv.get_item_count(reg_id)
			reg_counts.append("%s: %d" % [r_def.get("name", reg_id), c])
		label_reagents.text = "Reagents: " + "  |  ".join(reg_counts)

	# 2. Populate Recipes List
	if recipes_container:
		for c in recipes_container.get_children():
			c.queue_free()

		for recipe in AlchemyCatalog.RECIPES:
			var row = _create_recipe_row(recipe, inv)
			recipes_container.add_child(row)

func _create_recipe_row(recipe: Dictionary, inv: InventoryComponent) -> PanelContainer:
	var panel = PanelContainer.new()
	var flat = StyleBoxFlat.new()
	flat.bg_color = Color(0.12, 0.14, 0.18, 0.9)
	flat.border_width_left = 1
	flat.border_width_top = 1
	flat.border_width_right = 1
	flat.border_width_bottom = 1
	flat.border_color = Color(0.25, 0.3, 0.4, 0.8)
	flat.corner_radius_top_left = 4
	flat.corner_radius_top_right = 4
	flat.corner_radius_bottom_right = 4
	flat.corner_radius_bottom_left = 4
	flat.content_margin_left = 8.0
	flat.content_margin_top = 6.0
	flat.content_margin_right = 8.0
	flat.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", flat)

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl = Label.new()
	name_lbl.text = recipe.get("name", "Unknown Potion")
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	vbox.add_child(name_lbl)

	var ing_strs: Array[String] = []
	var can_craft = true
	var ings: Dictionary = recipe.get("ingredients", {})
	for req_id in ings.keys():
		var req_qty = int(ings[req_id])
		var cur_qty = inv.get_item_count(req_id)
		var r_name = AlchemyCatalog.REAGENTS.get(req_id, {}).get("name", req_id)
		ing_strs.append("%s (%d/%d)" % [r_name, cur_qty, req_qty])
		if cur_qty < req_qty:
			can_craft = false

	var ing_lbl = Label.new()
	ing_lbl.text = "Requires: " + ", ".join(ing_strs)
	ing_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9) if can_craft else Color(0.8, 0.4, 0.4))
	vbox.add_child(ing_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = recipe.get("description", "")
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	vbox.add_child(desc_lbl)

	hbox.add_child(vbox)

	var btn_craft = Button.new()
	btn_craft.custom_minimum_size = Vector2(90, 36)
	btn_craft.text = "Brew"
	btn_craft.disabled = not can_craft
	btn_craft.pressed.connect(Callable(self, "_on_craft_pressed").bind(recipe.get("recipe_id", "")))
	hbox.add_child(btn_craft)

	panel.add_child(hbox)
	return panel

func _on_craft_pressed(recipe_id: String) -> void:
	if not player:
		return
	var res = AlchemyCatalog.craft_recipe(player, recipe_id)
	if label_status:
		label_status.text = res.get("message", "")
		if res.get("success", false):
			label_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			label_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	refresh_view()
	emit_signal("crafting_completed", recipe_id, res)
