# PauseMenu.gd
# This script handles the in-game pause menu functionality

# Extends Control for UI elements
extends Control

# Node references
@onready var settings_menu = $SettingsMenu  # Settings submenu
@onready var main_menu = $PauseContainer   # Main pause menu

# State variables
var is_paused := false         # Current pause state
var local_player: Node = null  # Reference to local player

# Called when node enters scene tree
func _ready():
	# Set to full screen size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Initial visibility - hidden by default
	visible = false
	settings_menu.visible = false
	main_menu.visible = false
	
	# Ensure menu processes input even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Find local player in scene
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
	
	# Initialize settings controls with saved values
	init_settings_controls()

# Initialize settings controls with current values
func init_settings_controls():
	# Mouse sensitivity slider
	if has_node("SettingsMenu/VBoxContainer/MouseSensitivity/Text/Sensitivity"):
		$SettingsMenu/VBoxContainer/MouseSensitivity/Text/Sensitivity.value = Settings.settings.get("mouse_sensitivity", 0.002) * 1000
	
	# Fullscreen toggle
	if has_node("SettingsMenu/VBoxContainer/FullScreenCheckButton"):
		$SettingsMenu/VBoxContainer/FullScreenCheckButton.button_pressed = Settings.settings.get("fullscreen", false)
	
	# VSync toggle
	if has_node("SettingsMenu/VBoxContainer/VsyncCheckBox"):
		$SettingsMenu/VBoxContainer/VsyncCheckBox.button_pressed = Settings.settings.get("vsync", true)
	
	# Resolution dropdown
	if has_node("SettingsMenu/VBoxContainer/ResOptionButton"):
		var res_option = $SettingsMenu/VBoxContainer/ResOptionButton
		res_option.clear()
		# Add common resolution options
		res_option.add_item("1152x648")
		res_option.add_item("1280x720")
		res_option.add_item("1366x768")
		res_option.add_item("1920x1080")
		
		# Set current resolution from settings
		var current_res = Settings.settings.get("resolution", Vector2i(1152, 648))
		var current_res_str = str(current_res.x) + "x" + str(current_res.y)
		for i in range(res_option.item_count):
			if res_option.get_item_text(i) == current_res_str:
				res_option.selected = i
				break

# Find the local player in the scene
func find_local_player():
	# Search all player nodes in the "player" group
	for player in get_tree().get_nodes_in_group("player"):
		if player.is_multiplayer_authority():  # Check if local player
			local_player = player
			print("Found local player: ", player.name)
			break

# Handle input events
func _input(event):
	# Only process pause input when not in settings menu
	if event.is_action_pressed("pause"):
		if settings_menu.visible:
			# If in settings, go back to main pause menu
			_on_setting_menu_back_pressed()
			get_viewport().set_input_as_handled()
		else:
			# Toggle pause menu state
			toggle_pause_menu()
			get_viewport().set_input_as_handled()

# Toggle pause menu visibility and game state
func toggle_pause_menu():
	is_paused = !is_paused
	visible = is_paused
	
	if is_paused:
		# Pause local player - disable input
		if local_player and local_player.has_method("set_input_enabled"):
			local_player.set_input_enabled(false)
		
		# Show pause menu
		main_menu.visible = true
		settings_menu.visible = false
		
		# Show mouse cursor
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# Resume local player - enable input
		if local_player and local_player.has_method("set_input_enabled"):
			local_player.set_input_enabled(true)
		
		# Hide settings menu if open
		settings_menu.visible = false
		
		# Hide mouse cursor (capture for FPS controls)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Continue button pressed
func _on_continue_pressed():
	print("Continue pressed")
	toggle_pause_menu()  # Unpause game

# Settings button pressed
func _on_settings_pressed():
	print("Settings pressed")
	main_menu.visible = false
	settings_menu.visible = true  # Show settings submenu

# Back to menu button pressed
func _on_back_to_menu_pressed():
	print("Back to menu pressed")
	# Disconnect from multiplayer if connected
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	
	# Re-enable player input
	if local_player and local_player.has_method("set_input_enabled"):
		local_player.set_input_enabled(true)
	
	# Show mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Load main menu scene
	get_tree().change_scene_to_file("res://MainMenu/MainMenu.tscn")

# Quit button pressed
func _on_quit_pressed():
	print("Quit pressed")
	get_tree().quit()  # Quit game

# Mouse sensitivity changed
func _on_sensitivity_changed(value):
	print("Sensitivity changed: ", value)
	# Convert slider value (e.g., 2) to sensitivity (0.002)
	var new_sensitivity = value / 1000.0
	Settings.set_setting("mouse_sensitivity", new_sensitivity)

# Fullscreen toggle changed
func _on_fullscreen_toggled(toggled_on):
	print("Fullscreen toggled: ", toggled_on)
	Settings.set_setting("fullscreen", toggled_on)

# VSync toggle changed
func _on_vsync_toggled(toggled_on):
	print("VSync toggled: ", toggled_on)
	Settings.set_setting("vsync", toggled_on)

# Resolution selection changed
func _on_resolution_selected(index):
	print("Resolution selected: ", index)
	if not has_node("SettingsMenu/VBoxContainer/ResOptionButton"):
		return
	
	# Get selected resolution text (e.g., "1920x1080")
	var res_option = $SettingsMenu/VBoxContainer/ResOptionButton
	var res_text = res_option.get_item_text(index)
	var res_parts = res_text.split("x")
	if res_parts.size() == 2:
		# Convert to Vector2i and save
		var new_res = Vector2i(res_parts[0].to_int(), res_parts[1].to_int())
		Settings.set_setting("resolution", new_res)

# Settings back button pressed
func _on_setting_menu_back_pressed():
	print("Settings back pressed")
	settings_menu.visible = false
	main_menu.visible = true  # Return to main pause menu
