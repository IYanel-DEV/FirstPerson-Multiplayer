# UIController.gd
extends Control

func _ready():
	if !$MenuPanel/VBoxContainer/Host.is_connected("pressed", _on_host_pressed):
		$MenuPanel/VBoxContainer/Host.connect("pressed", _on_host_pressed)
	
	if !$MenuPanel/VBoxContainer/Join.is_connected("pressed", _on_join_pressed):
		$MenuPanel/VBoxContainer/Join.connect("pressed", _on_join_pressed)
	
	if !$MenuPanel/VBoxContainer/Settings.is_connected("pressed", _on_settings_pressed):
		$MenuPanel/VBoxContainer/Settings.connect("pressed", _on_settings_pressed)
	
	if !$MenuPanel/VBoxContainer/Quit.is_connected("pressed", _on_quit_pressed):
		$MenuPanel/VBoxContainer/Quit.connect("pressed", _on_quit_pressed)
	
	if !$SettingsMenu/VBoxContainer/SettingMenuBack.is_connected("pressed", _on_setting_menu_back_pressed):
		$SettingsMenu/VBoxContainer/SettingMenuBack.connect("pressed", _on_setting_menu_back_pressed)

func _on_host_pressed():
	$MenuPanel/VBoxContainer/Host.disabled = true
	if await NetworkManager.host_game() == false:
		$MenuPanel/VBoxContainer/Host.disabled = false

func _on_join_pressed():
	$MenuPanel/VBoxContainer/Join.disabled = true
	if !NetworkManager.join_game("localhost"):
		$MenuPanel/VBoxContainer/Join.disabled = false

func _on_settings_pressed():
	$SettingsMenu.show()

func _on_quit_pressed():
	get_tree().quit()

func _on_sensitivity_changed(value):
	if multiplayer.has_multiplayer_peer():
		for player in get_tree().get_nodes_in_group("player"):
			if player.is_multiplayer_authority():
				player.mouse_sensitivity = value

func _on_fullscreen_toggled(toggled_on):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(toggled_on):
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_aa_option_selected(index):
	var viewport = get_viewport()
	match index:
		0: viewport.msaa_3d = Viewport.MSAA_DISABLED
		1: viewport.msaa_3d = Viewport.MSAA_2X
		2: viewport.msaa_3d = Viewport.MSAA_4X
		3: viewport.msaa_3d = Viewport.MSAA_8X

func _on_setting_menu_back_pressed() -> void:
	$SettingsMenu.hide()

func show_error(message: String):
	print("Error: ", message)
	$MenuPanel/VBoxContainer/Host.disabled = false
	$MenuPanel/VBoxContainer/Join.disabled = false
