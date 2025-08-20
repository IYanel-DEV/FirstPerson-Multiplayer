@tool
extends AcceptDialog

var instance_count_spin: SpinBox
var running_processes = []

func _init():
	title = "🎮 MultiPlay - Multiplayer Test Runner"
	set_flag(Window.FLAG_RESIZE_DISABLED, false)
	min_size = Vector2i(600, 450)
	size = Vector2i(600, 450)
	_setup_ui()

func _setup_ui():
	# Main container
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 16)
	
	# Header section with beautiful styling
	var header_panel = Panel.new()
	main_vbox.add_child(header_panel)
	header_panel.custom_minimum_size.y = 100
	
	# Gradient background for header
	var header_bg = StyleBoxFlat.new()
	header_bg.bg_color = Color(0.15, 0.2, 0.35, 0.95)
	header_bg.set_corner_radius_all(12)
	header_bg.border_width_top = 3
	header_bg.border_color = Color(0.3, 0.5, 0.9, 0.9)
	# Add subtle shadow effect
	header_bg.shadow_color = Color(0, 0, 0, 0.3)
	header_bg.shadow_size = 4
	header_bg.shadow_offset = Vector2(0, 2)
	header_panel.add_theme_stylebox_override("panel", header_bg)
	
	var header_vbox = VBoxContainer.new()
	header_panel.add_child(header_vbox)
	header_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_vbox.add_theme_constant_override("separation", 4)
	
	# Main title with glow effect
	var title_label = Label.new()
	header_vbox.add_child(title_label)
	title_label.text = "🚀 MultiPlayer Test Runner"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.4, 0.8, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# Subtitle
	var subtitle = Label.new()
	header_vbox.add_child(subtitle)
	subtitle.text = "Launch multiple game instances for multiplayer testing"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95, 0.8))
	
	# Configuration section
	var config_panel = Panel.new()
	main_vbox.add_child(config_panel)
	config_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Config panel styling
	var config_bg = StyleBoxFlat.new()
	config_bg.bg_color = Color(0.08, 0.1, 0.15, 0.7)
	config_bg.set_corner_radius_all(8)
	config_bg.border_width_left = 2
	config_bg.border_color = Color(0.2, 0.4, 0.7, 0.6)
	config_panel.add_theme_stylebox_override("panel", config_bg)
	
	var config_vbox = VBoxContainer.new()
	config_panel.add_child(config_vbox)
	config_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	config_vbox.add_theme_constant_override("separation", 12)
	
	# Instance count section
	var count_section = VBoxContainer.new()
	config_vbox.add_child(count_section)
	count_section.add_theme_constant_override("separation", 8)
	
	var count_label = Label.new()
	count_section.add_child(count_label)
	count_label.text = "⚙️ Number of Test Instances:"
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	
	# Instance count container with beautiful spinner
	var count_container = HBoxContainer.new()
	count_section.add_child(count_container)
	count_container.add_theme_constant_override("separation", 12)
	
	# Decorative icon
	var icon_label = Label.new()
	count_container.add_child(icon_label)
	icon_label.text = "🎮"
	icon_label.add_theme_font_size_override("font_size", 32)
	
	# Spin box with custom styling
	instance_count_spin = SpinBox.new()
	count_container.add_child(instance_count_spin)
	instance_count_spin.min_value = 2
	instance_count_spin.max_value = 8
	instance_count_spin.value = 2
	instance_count_spin.custom_minimum_size.x = 120
	instance_count_spin.custom_minimum_size.y = 40
	
	# Style the spin box
	var spin_bg = StyleBoxFlat.new()
	spin_bg.bg_color = Color(0.15, 0.2, 0.3, 0.8)
	spin_bg.set_corner_radius_all(6)
	spin_bg.border_width_bottom = 2
	spin_bg.border_color = Color(0.3, 0.5, 0.8, 0.7)
	instance_count_spin.get_line_edit().add_theme_stylebox_override("normal", spin_bg)
	instance_count_spin.get_line_edit().add_theme_color_override("font_color", Color.WHITE)
	
	# Players label
	var players_label = Label.new()
	count_container.add_child(players_label)
	players_label.text = "Players"
	players_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	players_label.add_theme_font_size_override("font_size", 16)
	
	# Status section
	var status_section = VBoxContainer.new()
	config_vbox.add_child(status_section)
	
	var status_label = Label.new()
	status_section.add_child(status_label)
	status_label.name = "StatusLabel"
	status_label.text = "Ready to launch multiplayer test! 🚀"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.4))
	status_label.add_theme_font_size_override("font_size", 14)
	
	# Action buttons section
	var button_section = VBoxContainer.new()
	main_vbox.add_child(button_section)
	button_section.add_theme_constant_override("separation", 10)
	
	# Launch button (big and prominent)
	var launch_btn = _create_action_button("🚀 Launch Test Instances", Color(0.2, 0.6, 0.3))
	button_section.add_child(launch_btn)
	launch_btn.pressed.connect(_launch_instances)
	launch_btn.custom_minimum_size.y = 50
	
	# Secondary buttons row
	var secondary_row = HBoxContainer.new()
	button_section.add_child(secondary_row)
	secondary_row.add_theme_constant_override("separation", 8)
	
	var close_all_btn = _create_action_button("🛑 Close All", Color(0.7, 0.3, 0.2))
	secondary_row.add_child(close_all_btn)
	close_all_btn.pressed.connect(_close_all_instances)
	
	var close_panel_btn = _create_action_button("✖ Close Panel", Color(0.4, 0.4, 0.4))
	secondary_row.add_child(close_panel_btn)
	close_panel_btn.pressed.connect(_close_panel)

func _create_action_button(text: String, base_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size.y = 45
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Normal state with gradient-like effect
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = base_color
	normal_style.set_corner_radius_all(8)
	normal_style.border_width_bottom = 3
	normal_style.border_color = base_color.darkened(0.3)
	# Add subtle glow
	normal_style.shadow_color = base_color.lightened(0.3)
	normal_style.shadow_color.a = 0.4
	normal_style.shadow_size = 3
	btn.add_theme_stylebox_override("normal", normal_style)
	
	# Hover state
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = base_color.lightened(0.2)
	hover_style.set_corner_radius_all(8)
	hover_style.border_width_bottom = 3
	hover_style.border_color = base_color
	hover_style.shadow_color = base_color.lightened(0.5)
	hover_style.shadow_color.a = 0.6
	hover_style.shadow_size = 5
	btn.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed state
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = base_color.darkened(0.2)
	pressed_style.set_corner_radius_all(8)
	pressed_style.border_width_top = 2
	pressed_style.border_color = base_color.darkened(0.4)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	btn.add_theme_constant_override("shadow_offset_x", 1)
	btn.add_theme_constant_override("shadow_offset_y", 1)
	
	return btn

func _launch_instances():
	var count = int(instance_count_spin.value)
	_update_status("Launching " + str(count) + " instances... 🚀")
	
	for i in range(count):
		var pid = OS.create_process(OS.get_executable_path(), [])
		if pid > 0:
			running_processes.append(pid)
			print("MultiPlay: Launched instance " + str(i + 1) + " with PID: " + str(pid))
		else:
			print("MultiPlay: Failed to launch instance " + str(i + 1))
		
		# Small delay between launches for stability
		await get_tree().create_timer(0.2).timeout
	
	_update_status("✅ Successfully launched " + str(count) + " test instances!")

func _close_all_instances():
	if running_processes.is_empty():
		_update_status("No instances to close 🤷")
		return
	
	_update_status("Closing all instances... 🛑")
	
	var closed_count = 0
	for pid in running_processes:
		if OS.kill(pid) == OK:
			closed_count += 1
	
	running_processes.clear()
	_update_status("✅ Closed " + str(closed_count) + " instances")

func _close_panel():
	hide()

func _update_status(message: String):
	var status_label = find_child("StatusLabel")
	if status_label:
		status_label.text = message
	print("MultiPlay: " + message)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_all_instances()
		queue_free()
