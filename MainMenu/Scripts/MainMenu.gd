extends Control

func _ready():
	# Connect UI signals only if they're not already connected
	if !$MenuPanel/VBoxContainer/Host.is_connected("pressed", _on_host_pressed):
		$MenuPanel/VBoxContainer/Host.connect("pressed", _on_host_pressed)
	
	if !$MenuPanel/VBoxContainer/Join.is_connected("pressed", _on_join_pressed):
		$MenuPanel/VBoxContainer/Join.connect("pressed", _on_join_pressed)
	
	if !$MenuPanel/VBoxContainer/Settings.is_connected("pressed", _on_settings_pressed):
		$MenuPanel/VBoxContainer/Settings.connect("pressed", _on_settings_pressed)
	
	if !$MenuPanel/VBoxContainer/Quit.is_connected("pressed", _on_quit_pressed):
		$MenuPanel/VBoxContainer/Quit.connect("pressed", _on_quit_pressed)
	
	# Connect the back button
	if !$SettingsMenu/VBoxContainer/SettingMenuBack.is_connected("pressed", _on_setting_menu_back_pressed):
		$SettingsMenu/VBoxContainer/SettingMenuBack.connect("pressed", _on_setting_menu_back_pressed)

func _on_host_pressed():
	if NetworkManager.host_game():
		# Only hide UI if hosting succeeds
		hide()

func _on_join_pressed():
	# Always use localhost as the IP address
	if NetworkManager.join_game("localhost"):
		hide()

func _on_settings_pressed():
	# Show your settings menu
	$SettingsMenu.show()

func _on_quit_pressed():
	get_tree().quit()

# Settings menu functions
func _on_sensitivity_changed(value):
	# This should update your player's mouse sensitivity
	if multiplayer.has_multiplayer_peer():
		for player in get_tree().get_nodes_in_group("player"):
			if player.is_multiplayer_authority():
				player.mouse_sensitivity = value

func _on_fullscreen_toggled(toggled_on):
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if toggled_on 
		else DisplayServer.WINDOW_MODE_WINDOWED
	)

func _on_vsync_toggled(toggled_on):
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if toggled_on 
		else DisplayServer.VSYNC_DISABLED
	)

func _on_aa_option_selected(index):
	# Anti-aliasing setting
	var mode = {
		0: Viewport.MSAA_DISABLED,
		1: Viewport.MSAA_2X,
		2: Viewport.MSAA_4X,
		3: Viewport.MSAA_8X
	}
	get_viewport().msaa_3d = mode.get(index, Viewport.MSAA_DISABLED)

func _on_setting_menu_back_pressed() -> void:
	$SettingsMenu.hide()
