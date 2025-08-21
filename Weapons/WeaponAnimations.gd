# WeaponAnimations.gd - Fixed version
extends Node
class_name WeaponAnimations

# Animation references
@onready var animation_player: AnimationPlayer

# Animation states
enum AnimationState { IDLE, AIM, AIM_HOLD, AIM_HOLD_SHOOT, SHOOT, MOVE, RELOAD }
var current_state: AnimationState = AnimationState.IDLE
var previous_state: AnimationState = AnimationState.IDLE

# Animation speed modifiers
var move_speed_modifier: float = 1.0

func _ready():
	# Get the AnimationPlayer node
	animation_player = get_parent().get_node("AnimationPlayer")
	
	# Connect animation finished signal
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)

# Play animation with optional speed modifier
func play_animation(anim_name: String, speed: float = 1.0, blend_time: float = 0.1):
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name, blend_time, speed)
		return true
	return false

# Transition to a new animation state
func transition_to_state(new_state: AnimationState, force: bool = false):
	if current_state == new_state and not force:
		return
	
	previous_state = current_state
	current_state = new_state
	
	match new_state:
		AnimationState.IDLE:
			play_animation("Idle")
		AnimationState.AIM:
			play_animation("Aim")
		AnimationState.AIM_HOLD:
			play_animation("Aim_Hold")
		AnimationState.AIM_HOLD_SHOOT:
			play_animation("Aim_Hold_Shoot")
		AnimationState.SHOOT:
			play_animation("Shoot")
		AnimationState.MOVE:
			play_animation("Move", move_speed_modifier)
		AnimationState.RELOAD:
			play_animation("Reload")

# Set movement speed modifier for move animation
func set_move_speed(speed: float):
	move_speed_modifier = clamp(speed, 0.5, 2.0)
	if current_state == AnimationState.MOVE:
		animation_player.playback_speed = move_speed_modifier

# Handle animation finished events
func _on_animation_finished(anim_name: String):
	match anim_name:
		"Shoot", "Aim_Hold_Shoot":
			if current_state == AnimationState.AIM_HOLD_SHOOT or current_state == AnimationState.SHOOT:
				if previous_state == AnimationState.AIM or previous_state == AnimationState.AIM_HOLD:
					transition_to_state(AnimationState.AIM_HOLD)
				else:
					transition_to_state(AnimationState.IDLE)
		"Reload":
			transition_to_state(AnimationState.IDLE)
		"Aim":
			transition_to_state(AnimationState.AIM_HOLD)

# Get current animation length
func get_current_animation_length() -> float:
	if animation_player and animation_player.current_animation:
		return animation_player.current_animation_length / animation_player.playback_speed
	return 0.0
