# PauseMenu.gd
extends Control

@onready var settings_menu = $SettingsMenu
@onready var main_menu = $VBoxContainer

var is_paused := false

func _ready():
	# Set to full screen rect
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)  # Fixed method name
	
	# Initial visibility
	visible = false
	settings_menu.visible = false
	main_menu.visible = false
	
	# Make sure we process input even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect buttons safely
	$VBoxContainer/Continue.pressed.connect(_on_continue_pressed)
	$VBoxContainer/Settings.pressed.connect(_on_settings_pressed)
	$VBoxContainer/BackToMenu.pressed.connect(_on_back_to_menu_pressed)
	$VBoxContainer/Quit.pressed.connect(_on_quit_pressed)
	$SettingsMenu/VBoxContainer/SettingMenuBack.pressed.connect(_on_setting_menu_back_pressed)
	
	# Connect settings controls
	if has_node("SettingsMenu/VBoxContainer/MouseSensitivity/Text/Sensitivity"):
		$SettingsMenu/VBoxContainer/MouseSensitivity/Text/Sensitivity.value_changed.connect(_on_sensitivity_changed)
	if has_node("SettingsMenu/VBoxContainer/FullScreenCheckButton"):
		$SettingsMenu/VBoxContainer/FullScreenCheckButton.toggled.connect(_on_fullscreen_toggled)
	if has_node("SettingsMenu/VBoxContainer/VsyncCheckBox"):
		$SettingsMenu/VBoxContainer/VsyncCheckBox.toggled.connect(_on_vsync_toggled)
	if has_node("SettingsMenu/VBoxContainer/ResOptionButton"):
		$SettingsMenu/VBoxContainer/ResOptionButton.item_selected.connect(_on_resolution_selected)

func _input(event):
	# Only handle pause input when not in settings menu
	if event.is_action_pressed("pause") and !settings_menu.visible:
		toggle_pause_menu()
		# Consume the event
		get_viewport().set_input_as_handled()

func toggle_pause_menu():
	is_paused = !is_paused
	visible = is_paused
	get_tree().paused = is_paused
	
	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		main_menu.visible = true
		settings_menu.visible = false
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_continue_pressed():
	print("Continue pressed")
	toggle_pause_menu()

func _on_settings_pressed():
	print("Settings pressed")
	main_menu.visible = false
	settings_menu.visible = true

func _on_back_to_menu_pressed():
	print("Back to menu pressed")
	# Disconnect from network
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	
	# Unpause game
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Load main menu
	get_tree().change_scene_to_file("res://MainMenu/MainMenu.tscn")

func _on_quit_pressed():
	print("Quit pressed")
	get_tree().quit()

func _on_sensitivity_changed(value):
	print("Sensitivity changed: ", value)
	# Convert slider value to sensitivity
	var new_sensitivity = value / 1000.0
	Settings.set_setting("mouse_sensitivity", new_sensitivity)

func _on_fullscreen_toggled(toggled_on):
	print("Fullscreen toggled: ", toggled_on)
	Settings.set_setting("fullscreen", toggled_on)

func _on_vsync_toggled(toggled_on):
	print("VSync toggled: ", toggled_on)
	Settings.set_setting("vsync", toggled_on)

func _on_resolution_selected(index):
	print("Resolution selected: ", index)
	var res_text = $SettingsMenu/VBoxContainer/ResOptionButton.get_item_text(index)
	var res_parts = res_text.split("x")
	if res_parts.size() == 2:
		var new_res = Vector2i(res_parts[0].to_int(), res_parts[1].to_int())
		Settings.set_setting("resolution", new_res)

func _on_setting_menu_back_pressed():
	print("Settings back pressed")
	settings_menu.visible = false
	main_menu.visible = true
