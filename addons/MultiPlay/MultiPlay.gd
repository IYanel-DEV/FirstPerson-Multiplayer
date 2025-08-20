@tool
extends EditorPlugin

const MultiPlayPanel = preload("res://addons/MultiPlay/Scripts/multiplay_panel.gd")
var toolbar_button
var popup_panel

func _enter_tree():
	# Create the toolbar button
	toolbar_button = Button.new()
	toolbar_button.text = "🕹MultiPlay"
	toolbar_button.icon = EditorInterface.get_editor_theme().get_icon("MultiNodeEdit", "EditorIcons")
	toolbar_button.tooltip_text = "Open MultiPlayer Test Runner"
	
	# Style the button to match Godot's toolbar
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.25, 0.35, 0.6, 0.9)
	button_style.set_corner_radius_all(4)
	button_style.border_width_bottom = 2
	button_style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	toolbar_button.add_theme_stylebox_override("normal", button_style)
	toolbar_button.add_theme_color_override("font_color", Color.WHITE)
	
	# Connect button press
	toolbar_button.pressed.connect(_on_toolbar_button_pressed)
	
	# Add button to toolbar (next to play button)
	add_control_to_container(CONTAINER_TOOLBAR, toolbar_button)
	
	print("MultiPlay Plugin: Activated! 🚀")

func _exit_tree():
	# Clean up
	if toolbar_button:
		remove_control_from_container(CONTAINER_TOOLBAR, toolbar_button)
		toolbar_button = null
	
	if popup_panel:
		popup_panel.queue_free()
		popup_panel = null
	
	print("MultiPlay Plugin: Deactivated")

func _on_toolbar_button_pressed():
	if not popup_panel:
		# Create popup panel
		popup_panel = MultiPlayPanel.new()
		EditorInterface.get_editor_main_screen().add_child(popup_panel)
		
		# Position popup near the toolbar button
		popup_panel.popup_centered(Vector2i(400, 300))
	else:
		# Toggle visibility
		if popup_panel.visible:
			popup_panel.hide()
		else:
			popup_panel.popup_centered(Vector2i(400, 300))
