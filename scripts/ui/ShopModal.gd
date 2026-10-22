@tool
class_name ShopModal
extends BaseModal

## ShopModal: Two-pane trading interface for dungeon merchants and bazaar stalls.
## Displays merchant stock with category filtering, player backpack with sell valuations,
## 100-turn buyback badges, Charisma + Bartering discount readout, and attack confirmation.

signal shop_action_completed(action: String, details: Dictionary)

@onready var label_merchant_name: Label = $VBox/HeaderBar/MerchantInfo/LabelName
@onready var label_merchant_title: Label = $VBox/HeaderBar/MerchantInfo/LabelTitle
@onready var label_dialogue: Label = $VBox/SpeechBanner/LabelDialogue
@onready var btn_close: Button = $VBox/HeaderBar/HeaderButtons/BtnClose
@onready var btn_attack: Button = $VBox/HeaderBar/HeaderButtons/BtnAttack

@onready var list_merchant: VBoxContainer = $VBox/MainPanes/LeftPane/ScrollMerchant/ListMerchant
@onready var list_player: VBoxContainer = $VBox/MainPanes/RightPane/ScrollPlayer/ListPlayer

@onready var label_player_gold: Label = $VBox/BottomBar/LabelPlayerGold
@onready var label_player_weight: Label = $VBox/BottomBar/LabelPlayerWeight
@onready var label_discount_info: Label = $VBox/BottomBar/LabelDiscountInfo
@onready var btn_refill_ammo: Button = $VBox/BottomBar/BtnRefillAmmo

@onready var filter_tabs: HBoxContainer = $VBox/MainPanes/LeftPane/FilterTabs
@onready var confirmation_panel: PanelContainer = $ConfirmationPanel
@onready var label_confirm_prompt: Label = $ConfirmationPanel/VBox/LabelConfirmPrompt
@onready var btn_confirm_attack: Button = $ConfirmationPanel/VBox/Buttons/BtnConfirmAttack
@onready var btn_cancel_attack: Button = $ConfirmationPanel/VBox/Buttons/BtnCancelAttack

var merchant: Merchant = null
var player: Node2D = null
var current_turn: int = 0
var active_filter: String = "ALL"
var tooltip: ItemTooltip = null

func _ready() -> void:
	close_on_escape = true
	super._ready()
	_ensure_tooltip()
	
	if btn_close:
		btn_close.pressed.connect(close_modal)
	if btn_attack:
		btn_attack.pressed.connect(_on_attack_button_pressed)
	if btn_confirm_attack:
		btn_confirm_attack.pressed.connect(_on_confirm_attack_pressed)
	if btn_cancel_attack:
		btn_cancel_attack.pressed.connect(_on_cancel_attack_pressed)
	if btn_refill_ammo:
		btn_refill_ammo.pressed.connect(_on_refill_ammo_pressed)
		
	if confirmation_panel:
		confirmation_panel.visible = false
		
	_setup_filter_buttons()

func _ensure_tooltip() -> void:
	if not tooltip:
		var scene = load("res://scenes/ui/components/ItemTooltip.tscn")
		if scene:
			tooltip = scene.instantiate() as ItemTooltip
			add_child(tooltip)

func close_modal() -> void:
	if tooltip:
		tooltip.cancel_hover()
	super.close_modal()

func _setup_filter_buttons() -> void:
	if not filter_tabs:
		return
	for child in filter_tabs.get_children():
		if child is Button:
			child.pressed.connect(func():
				active_filter = child.text.to_upper().strip_edges()
				_refresh_merchant_stock()
			)

func open_shop(p_merchant: Merchant, p_player: Node2D, p_turn: int = 0) -> void:
	merchant = p_merchant
	player = p_player
	current_turn = p_turn
	active_filter = "ALL"
	
	if confirmation_panel:
		confirmation_panel.visible = false
		
	open_modal()
	refresh_shop()

func refresh_shop() -> void:
	if not is_instance_valid(merchant) or not is_instance_valid(player):
		close_modal()
		return
		
	_refresh_top_banner()
	_refresh_merchant_stock()
	_refresh_player_backpack()
	_refresh_bottom_bar()

func _refresh_top_banner() -> void:
	if not merchant or not merchant.shop_data:
		return
		
	var m_name = merchant.get_merchant_name()
	var m_title = merchant.shop_data.merchant_title if merchant.shop_data.merchant_title != "" else "Travelling Broker"
	if label_merchant_name:
		label_merchant_name.text = m_name
	if label_merchant_title:
		label_merchant_title.text = m_title
		
	if label_dialogue:
		if merchant.shop_data.greeting_dialogue != "":
			label_dialogue.text = "\"%s\"" % merchant.shop_data.greeting_dialogue
		else:
			label_dialogue.text = "\"Wares for trade, traveller. Make your selection.\""

func _refresh_merchant_stock() -> void:
	if not list_merchant or not merchant or not merchant.shop_data:
		return
		
	for c in list_merchant.get_children():
		c.queue_free()
		
	var s_data = merchant.shop_data
	var p_cha = merchant._get_player_cha(player)
	var p_barter = merchant._get_player_bartering(player)
	var p_gold = merchant.get_player_gold(player)
	
	# 1. Physical Items
	for item in s_data.stock_items:
		if not _item_matches_filter(item):
			continue
			
		var buy_price = s_data.get_buy_price(item, p_cha, p_barter, current_turn)
		var is_buyback = false
		var turns_left = 0
		if item.has_meta("buyback_turn") and item.has_meta("buyback_price"):
			var sold_turn = int(item.get_meta("buyback_turn"))
			if current_turn - sold_turn <= 100:
				is_buyback = true
				turns_left = maxi(0, 100 - (current_turn - sold_turn))
				
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 32)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.mouse_entered.connect(func():
			if tooltip:
				var inv = merchant._get_player_inventory(player) if merchant and player else null
				var compare_gear = inv.equipped_slots.get(item.equip_slot) as ItemData if (inv and item.equip_slot != ItemData.EquipSlot.NONE) else null
				var skills = player.get_node_or_null("SkillComponent") as SkillComponent if player else null
				tooltip.request_hover_item(item, get_global_mouse_position(), compare_gear, skills)
		)
		row.mouse_exited.connect(func():
			if tooltip:
				tooltip.cancel_hover()
		)
		
		var label_item = Label.new()
		label_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var qty_tag = " (x%d)" % item.quantity if item.quantity > 1 else ""
		var buyback_tag = " [BUYBACK: %dt LEFT]" % turns_left if is_buyback else ""
		label_item.text = "%s%s%s (%.1fst)" % [item.item_name, qty_tag, buyback_tag, item.weight_stones]
		if is_buyback:
			label_item.modulate = Color(0.3, 0.9, 1.0)
		row.add_child(label_item)
		
		var label_price = Label.new()
		label_price.custom_minimum_size = Vector2(70, 0)
		label_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label_price.text = "%d GP" % buy_price
		label_price.modulate = Color(1.0, 0.85, 0.2)
		row.add_child(label_price)
		
		var btn_buy = Button.new()
		btn_buy.custom_minimum_size = Vector2(60, 26)
		btn_buy.text = "Buy"
		btn_buy.disabled = (p_gold < buy_price)
		btn_buy.pressed.connect(func(): _buy_item(item))
		row.add_child(btn_buy)
		
		list_merchant.add_child(row)
		
	# 2. Spells (if filter is ALL or SPELLS)
	if active_filter == "ALL" or active_filter == "SPELLS":
		for sp in s_data.stock_spells:
			var sp_price = s_data.get_spell_buy_price(sp, p_cha, p_barter)
			var row = HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.custom_minimum_size = Vector2(0, 32)
			
			var label_sp = Label.new()
			label_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label_sp.text = "[Spell Grimoire] %s" % sp.spell_name
			label_sp.modulate = Color(0.8, 0.6, 1.0)
			row.add_child(label_sp)
			
			var label_price = Label.new()
			label_price.custom_minimum_size = Vector2(70, 0)
			label_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label_price.text = "%d GP" % sp_price
			label_price.modulate = Color(1.0, 0.85, 0.2)
			row.add_child(label_price)
			
			var btn_learn = Button.new()
			btn_learn.custom_minimum_size = Vector2(60, 26)
			btn_learn.text = "Learn"
			btn_learn.disabled = (p_gold < sp_price)
			btn_learn.pressed.connect(func(): _buy_spell(sp))
			row.add_child(btn_learn)
			
			list_merchant.add_child(row)

func _item_matches_filter(item: ItemData) -> bool:
	if active_filter == "ALL":
		return true
	match active_filter:
		"WEAPONS":
			return item.item_type == ItemData.ItemType.WEAPON
		"ARMOR":
			return item.item_type == ItemData.ItemType.ARMOR or item.item_type == ItemData.ItemType.SHIELD
		"CONSUMABLES":
			return item.item_type == ItemData.ItemType.CONSUMABLE
		"AMMO":
			return item.item_type == ItemData.ItemType.AMMO
		"OTHER":
			return item.item_type == ItemData.ItemType.RELIC or item.item_type == ItemData.ItemType.VALUABLE
		_:
			return true

func _refresh_player_backpack() -> void:
	if not list_player or not merchant or not player:
		return
		
	for c in list_player.get_children():
		c.queue_free()
		
	var inv = merchant._get_player_inventory(player)
	if not inv:
		return
		
	var p_cha = merchant._get_player_cha(player)
	var p_barter = merchant._get_player_bartering(player)
	var m_gold = merchant.shop_data.merchant_gold if merchant.shop_data else 0
	
	for item in inv.items:
		var sell_price = merchant.shop_data.get_sell_price(item, p_cha, p_barter)
		
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 32)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.mouse_entered.connect(func():
			if tooltip:
				var compare_gear = inv.equipped_slots.get(item.equip_slot) as ItemData if (inv and item.equip_slot != ItemData.EquipSlot.NONE) else null
				var skills = player.get_node_or_null("SkillComponent") as SkillComponent if player else null
				tooltip.request_hover_item(item, get_global_mouse_position(), compare_gear, skills)
		)
		row.mouse_exited.connect(func():
			if tooltip:
				tooltip.cancel_hover()
		)
		
		var label_item = Label.new()
		label_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var qty_tag = " (x%d)" % item.quantity if item.quantity > 1 else ""
		label_item.text = "%s%s (%.1fst)" % [item.item_name, qty_tag, item.weight_stones]
		row.add_child(label_item)
		
		var label_price = Label.new()
		label_price.custom_minimum_size = Vector2(70, 0)
		label_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label_price.text = "%d GP" % sell_price
		label_price.modulate = Color(0.4, 1.0, 0.4)
		row.add_child(label_price)
		
		var btn_sell = Button.new()
		btn_sell.custom_minimum_size = Vector2(60, 26)
		btn_sell.text = "Sell"
		btn_sell.disabled = (m_gold < sell_price)
		btn_sell.pressed.connect(func(): _sell_item(item))
		row.add_child(btn_sell)
		
		list_player.add_child(row)

func _refresh_bottom_bar() -> void:
	if not merchant or not player:
		return
		
	var p_gold = merchant.get_player_gold(player)
	var inv = merchant._get_player_inventory(player)
	var p_cha = merchant._get_player_cha(player)
	var p_barter = merchant._get_player_bartering(player)
	var merc_mod = ShopData.calculate_mercantile_modifier(p_cha, p_barter)
	var discount_pct = (merc_mod - 1.0) * 100.0
	
	if label_player_gold:
		label_player_gold.text = "Player Gold: %d GP  |  Merchant Coffers: %d GP" % [p_gold, merchant.shop_data.merchant_gold if merchant.shop_data else 0]
		
	if label_player_weight and inv:
		var p_stats = player.get_node_or_null("StatsComponent") as StatsComponent
		var max_wt = p_stats.attributes.get_max_carry_weight_stones() if p_stats and p_stats.attributes else 100.0
		label_player_weight.text = "Carried Weight: %.1f / %.0f Stones" % [inv.get_carried_weight_stones(), max_wt]
		
	if label_discount_info:
		var sign_str = "+" if discount_pct >= 0 else ""
		label_discount_info.text = "Mercantile Modifier: %s%.1f%%  [CHA: %d • Bartering: %.1f]" % [sign_str, discount_pct, p_cha, p_barter]

func _buy_item(item: ItemData) -> void:
	if not merchant:
		return
	if tooltip:
		tooltip.cancel_hover()
	var res = merchant.buy_item(player, item)
	if res.get("success", false):
		emit_signal("shop_action_completed", "buy_item", res)
		refresh_shop()

func _buy_spell(spell: SpellData) -> void:
	if not merchant:
		return
	if tooltip:
		tooltip.cancel_hover()
	var res = merchant.buy_spell(player, spell)
	if res.get("success", false):
		emit_signal("shop_action_completed", "buy_spell", res)
		refresh_shop()

func _sell_item(item: ItemData) -> void:
	if not merchant:
		return
	if tooltip:
		tooltip.cancel_hover()
	var res = merchant.sell_item(player, item)
	if res.get("success", false):
		emit_signal("shop_action_completed", "sell_item", res)
		refresh_shop()

func _on_refill_ammo_pressed() -> void:
	if not merchant or not player:
		return
	var res = merchant.refill_equipped_ammo(player)
	if res.get("success", false):
		emit_signal("shop_action_completed", "refill_ammo", res)
		refresh_shop()

func _on_attack_button_pressed() -> void:
	if not merchant:
		return
	if confirmation_panel:
		if label_confirm_prompt:
			label_confirm_prompt.text = merchant.get_attack_confirmation_prompt()
		confirmation_panel.visible = true

func _on_cancel_attack_pressed() -> void:
	if confirmation_panel:
		confirmation_panel.visible = false

func _on_confirm_attack_pressed() -> void:
	if confirmation_panel:
		confirmation_panel.visible = false
	if merchant:
		var m = merchant
		close_modal()
		m.become_hostile(player, m.current_floor_num)
		emit_signal("shop_action_completed", "attack_merchant", {"merchant": m})
