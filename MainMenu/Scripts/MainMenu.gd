# UIController.gd
extends Control

func _ready():
	# Load settings
	Settings.load_settings()
	
	# Initial visibility
	$MenuPanel.show()
	$SettingsMenu.hide()
	
	# Connect main menu buttons with checks
	if not $MenuPanel/VBoxContainer/Host.pressed.is_connected(_on_host_pressed):
		$MenuPanel/VBoxContainer/Host.pressed.connect(_on_host_pressed)
	
	if not $MenuPanel/VBoxContainer/Join.pressed.is_connected(_on_join_pressed):
		$MenuPanel/VBoxContainer/Join.pressed.connect(_on_join_pressed)
	
	if not $MenuPanel/VBoxContainer/Settings.pressed.is_connected(_on_settings_pressed):
		$MenuPanel/VBoxContainer/Settings.pressed.connect(_on_settings_pressed)
	
	if not $MenuPanel/VBoxContainer/Quit.pressed.is_connected(_on_quit_pressed):
		$MenuPanel/VBoxContainer/Quit.pressed.connect(_on_quit_pressed)
	
	# Connect settings menu buttons with checks
	if not $SettingsMenu/VBoxContainer/SettingMenuBack.pressed.is_connected(_on_setting_menu_back_pressed):
		$SettingsMenu/VBoxContainer/SettingMenuBack.pressed.connect(_on_setting_menu_back_pressed)
	
	# Connect settings controls with checks
	if has_node("SettingsMenu/VBoxContainer/MouseSensitivity/Text/Sensitivity"):
		var sensitivity_slider = $SettingsMenu/VBoxContainer/MouseSensitivity/Text/Sensitivity
		if not sensitivity_slider.value_changed.is_connected(_on_sensitivity_changed):
			sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
		sensitivity_slider.value = Settings.settings.get("mouse_sensitivity", 0.002) * 1000
	
	if has_node("SettingsMenu/VBoxContainer/FullScreenCheckButton"):
		var fullscreen_check = $SettingsMenu/VBoxContainer/FullScreenCheckButton
		if not fullscreen_check.toggled.is_connected(_on_fullscreen_toggled):
			fullscreen_check.toggled.connect(_on_fullscreen_toggled)
		fullscreen_check.button_pressed = Settings.settings.get("fullscreen", false)
	
	if has_node("SettingsMenu/VBoxContainer/VsyncCheckBox"):
		var vsync_check = $SettingsMenu/VBoxContainer/VsyncCheckBox
		if not vsync_check.toggled.is_connected(_on_vsync_toggled):
			vsync_check.toggled.connect(_on_vsync_toggled)
		vsync_check.button_pressed = Settings.settings.get("vsync", true)
	
	if has_node("SettingsMenu/VBoxContainer/ResOptionButton"):
		var res_option = $SettingsMenu/VBoxContainer/ResOptionButton
		if not res_option.item_selected.is_connected(_on_resolution_selected):
			res_option.item_selected.connect(_on_resolution_selected)
		
		# Add common resolutions
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


func _on_host_pressed():
	$MenuPanel/VBoxContainer/Host.disabled = true
	if await NetworkManager.host_game() == false:
		$MenuPanel/VBoxContainer/Host.disabled = false

func _on_join_pressed():
	$MenuPanel/VBoxContainer/Join.disabled = true
	if !NetworkManager.join_game("localhost"):
		$MenuPanel/VBoxContainer/Join.disabled = false

func _on_settings_pressed():
	$MenuPanel.hide()
	$SettingsMenu.show()

func _on_quit_pressed():
	get_tree().quit()

func _on_sensitivity_changed(value):
	# Convert slider value to sensitivity
	var new_sensitivity = value / 1000.0
	Settings.set_setting("mouse_sensitivity", new_sensitivity)

func _on_fullscreen_toggled(toggled_on):
	Settings.set_setting("fullscreen", toggled_on)

func _on_vsync_toggled(toggled_on):
	Settings.set_setting("vsync", toggled_on)

func _on_resolution_selected(index):
	var res_text = $SettingsMenu/VBoxContainer/ResOptionButton.get_item_text(index)
	var res_parts = res_text.split("x")
	if res_parts.size() == 2:
		var new_res = Vector2i(res_parts[0].to_int(), res_parts[1].to_int())
		Settings.set_setting("resolution", new_res)

func _on_setting_menu_back_pressed():
	$SettingsMenu.hide()
	$MenuPanel.show()

func show_error(message: String):
	print("Error: ", message)
	$MenuPanel/VBoxContainer/Host.disabled = false
	$MenuPanel/VBoxContainer/Join.disabled = false
