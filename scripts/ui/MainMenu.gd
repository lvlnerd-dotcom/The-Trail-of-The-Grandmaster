@tool
class_name MainMenu
extends Control

## MainMenu: Title screen, run continuation, bestiary codex viewer, and audio settings.

@onready var btn_continue: Button = $VBoxCenter/MenuButtons/BtnContinue
@onready var btn_new_game: Button = $VBoxCenter/MenuButtons/BtnNewGame
@onready var btn_bestiary: Button = $VBoxCenter/MenuButtons/BtnBestiary
@onready var btn_settings: Button = $VBoxCenter/MenuButtons/BtnSettings
@onready var btn_quit: Button = $VBoxCenter/MenuButtons/BtnQuit

@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var slider_master: HSlider = $SettingsPanel/VBox/Grid/SliderMaster
@onready var slider_music: HSlider = $SettingsPanel/VBox/Grid/SliderMusic
@onready var slider_sfx: HSlider = $SettingsPanel/VBox/Grid/SliderSFX
@onready var slider_ui: HSlider = $SettingsPanel/VBox/Grid/SliderUI
@onready var btn_close_settings: Button = $SettingsPanel/VBox/BtnCloseSettings

@onready var bestiary_modal: BestiaryModal = $BestiaryModal
@onready var character_creation_modal: CharacterCreationModal = $CharacterCreationModal


func _get_audio_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("AudioManager")
	return null

func _get_game_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameManager")
	return null

func _ready() -> void:
	_check_saved_run()
	_setup_settings_panel()
	_connect_buttons()
	
	var am = _get_audio_mgr()
	if am:
		am.play_ambient("ambient_dungeon")
		
	var gm = _get_game_mgr()
	if gm and gm.open_creation_on_main_menu:
		gm.open_creation_on_main_menu = false
		if character_creation_modal:
			character_creation_modal.call("open_modal")

func _check_saved_run() -> void:
	var gm = _get_game_mgr()
	var has_save = gm.has_active_save() if gm else false
	btn_continue.disabled = not has_save
	if not has_save:
		btn_continue.text = "Continue Expedition (No Save)"
	else:
		btn_continue.text = "Continue Expedition"

func _setup_settings_panel() -> void:
	settings_panel.visible = false
	var am = _get_audio_mgr()
	if am:
		slider_master.value = am.get_volume("Master") * 100.0
		slider_music.value = am.get_volume("Music") * 100.0
		slider_sfx.value = am.get_volume("SFX") * 100.0
		slider_ui.value = am.get_volume("UI") * 100.0

func _connect_buttons() -> void:
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_bestiary.pressed.connect(_on_bestiary_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_close_settings.pressed.connect(func(): settings_panel.visible = false)
	
	slider_master.value_changed.connect(_on_master_slider_changed)
	slider_music.value_changed.connect(_on_music_slider_changed)
	slider_sfx.value_changed.connect(_on_sfx_slider_changed)
	slider_ui.value_changed.connect(_on_ui_slider_changed)

func _on_continue_pressed() -> void:
	var am = _get_audio_mgr()
	if am:
		am.play_sound("ui_click")
	get_tree().change_scene_to_file("res://scenes/world/World.tscn")

func _on_new_game_pressed() -> void:
	var am = _get_audio_mgr()
	if am:
		am.play_sound("ui_click")
	if character_creation_modal:
		character_creation_modal.open_modal()
	else:
		var gm = _get_game_mgr()
		if gm:
			gm.start_new_run()
		get_tree().change_scene_to_file("res://scenes/world/World.tscn")

func _on_bestiary_pressed() -> void:
	var am = _get_audio_mgr()
	if am:
		am.play_sound("ui_click")
	if bestiary_modal:
		bestiary_modal.open_modal()

func _on_settings_pressed() -> void:
	var am = _get_audio_mgr()
	if am:
		am.play_sound("ui_click")
	settings_panel.visible = not settings_panel.visible

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_master_slider_changed(value: float) -> void:
	var am = _get_audio_mgr()
	if am:
		am.set_volume("Master", value / 100.0)
		am.save_settings()

func _on_music_slider_changed(value: float) -> void:
	var am = _get_audio_mgr()
	if am:
		am.set_volume("Music", value / 100.0)
		am.save_settings()

func _on_sfx_slider_changed(value: float) -> void:
	var am = _get_audio_mgr()
	if am:
		am.set_volume("SFX", value / 100.0)
		am.save_settings()

func _on_ui_slider_changed(value: float) -> void:
	var am = _get_audio_mgr()
	if am:
		am.set_volume("UI", value / 100.0)
		am.save_settings()
