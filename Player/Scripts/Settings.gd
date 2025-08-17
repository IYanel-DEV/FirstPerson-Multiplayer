extends Node

var settings := {
	"mouse_sensitivity": 0.002,
	"resolution": Vector2i(1152, 648),
	"fullscreen": false,
	"vsync": true
}

func save_settings():
	var file = FileAccess.open("user://settings.dat", FileAccess.WRITE)
	if file:
		file.store_var(settings)
		file.close()

func load_settings():
	if FileAccess.file_exists("user://settings.dat"):
		var file = FileAccess.open("user://settings.dat", FileAccess.READ)
		if file:
			var loaded_settings = file.get_var()
			if loaded_settings:
				settings = loaded_settings
			file.close()
	apply_settings()

func apply_settings():
	# Apply sensitivity to existing players
	if get_tree():
		for player in get_tree().get_nodes_in_group("player"):
			if player.is_multiplayer_authority():
				player.mouse_sensitivity = settings.get("mouse_sensitivity", 0.002)
	
	# Apply display settings
	if settings.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		get_window().size = settings.get("resolution", Vector2i(1152, 648))
	
	if settings.get("vsync", true):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func set_setting(key: String, value):
	settings[key] = value
	save_settings()
	apply_settings()
