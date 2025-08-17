# PauseMenu.gd
extends Control

@onready var settings_menu = $SettingsMenu
@onready var main_menu = $PauseContainer

var is_paused := false
var local_player: Node = null

func _ready():
	# Set to full screen rect
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Initial visibility
	visible = false
	settings_menu.visible = false
	main_menu.visible = false
	
	# Make sure we process input even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Find local player
	find_local_player()
	

	
	# Connect settings controls
	if has_node("SettingsMenu/VBoxContainer/MouseSensitivity/Text/Sensitivity"):
		$SettingsMenu/VBoxContainer/MouseSensitivity/Text/Sensitivity.value_changed.connect(_on_sensitivity_changed)
	if has_node("SettingsMenu/VBoxContainer/FullScreenCheckButton"):
		$SettingsMenu/VBoxContainer/FullScreenCheckButton.toggled.connect(_on_fullscreen_toggled)
	if has_node("SettingsMenu/VBoxContainer/VsyncCheckBox"):
		$SettingsMenu/VBoxContainer/VsyncCheckBox.toggled.connect(_on_vsync_toggled)
	if has_node("SettingsMenu/VBoxContainer/ResOptionButton"):
		$SettingsMenu/VBoxContainer/ResOptionButton.item_selected.connect(_on_resolution_selected)
	
	# Initialize settings controls
	init_settings_controls()

func init_settings_controls():
	# Only initialize if nodes exist
	if has_node("SettingsMenu/VBoxContainer/MouseSensitivity/Text/Sensitivity"):
		$SettingsMenu/VBoxContainer/MouseSensitivity/Text/Sensitivity.value = Settings.settings.get("mouse_sensitivity", 0.002) * 1000
	
	if has_node("SettingsMenu/VBoxContainer/FullScreenCheckButton"):
		$SettingsMenu/VBoxContainer/FullScreenCheckButton.button_pressed = Settings.settings.get("fullscreen", false)
	
	if has_node("SettingsMenu/VBoxContainer/VsyncCheckBox"):
		$SettingsMenu/VBoxContainer/VsyncCheckBox.button_pressed = Settings.settings.get("vsync", true)
	
	if has_node("SettingsMenu/VBoxContainer/ResOptionButton"):
		var res_option = $SettingsMenu/VBoxContainer/ResOptionButton
		res_option.clear()
		res_option.add_item("1152x648")
		res_option.add_item("1280x720")
		res_option.add_item("1366x768")
		res_option.add_item("1920x1080")
		
		# Set to current resolution
		var current_res = Settings.settings.get("resolution", Vector2i(1152, 648))
		var current_res_str = str(current_res.x) + "x" + str(current_res.y)
		for i in range(res_option.item_count):
			if res_option.get_item_text(i) == current_res_str:
				res_option.selected = i
				break

func find_local_player():
	# Find the local player in the scene
	for player in get_tree().get_nodes_in_group("player"):
		if player.is_multiplayer_authority():
			local_player = player
			print("Found local player: ", player.name)
			break

func _input(event):
	# Only handle pause input when not in settings menu
	if event.is_action_pressed("pause"):
		if settings_menu.visible:
			# If in settings, go back to main pause menu
			_on_setting_menu_back_pressed()
			get_viewport().set_input_as_handled()
		else:
			toggle_pause_menu()
			get_viewport().set_input_as_handled()

func toggle_pause_menu():
	is_paused = !is_paused
	visible = is_paused
	
	if is_paused:
		# Pause local player - freeze completely
		if local_player:
			if local_player.has_method("set_input_enabled"):
				local_player.set_input_enabled(false)
		
		main_menu.visible = true
		settings_menu.visible = false
		
		# Show mouse cursor
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# Resume local player
		if local_player:
			if local_player.has_method("set_input_enabled"):
				local_player.set_input_enabled(true)
		
		# Make sure settings menu is closed
		settings_menu.visible = false
		
		# Hide mouse cursor
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
	
	# Unfreeze player
	if local_player:
		if local_player.has_method("set_input_enabled"):
			local_player.set_input_enabled(true)
	
	# Show mouse cursor
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
	if not has_node("SettingsMenu/VBoxContainer/ResOptionButton"):
		return
	
	var res_option = $SettingsMenu/VBoxContainer/ResOptionButton
	var res_text = res_option.get_item_text(index)
	var res_parts = res_text.split("x")
	if res_parts.size() == 2:
		var new_res = Vector2i(res_parts[0].to_int(), res_parts[1].to_int())
		Settings.set_setting("resolution", new_res)

func _on_setting_menu_back_pressed():
	print("Settings back pressed")
	settings_menu.visible = false
	main_menu.visible = true
