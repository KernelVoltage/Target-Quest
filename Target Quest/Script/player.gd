extends CharacterBody2D

# Reference to the AnimationPlayer node for controlling character animations
@onready var animation_player = $AnimationPlayer

# Reference to the Marker2D node where the arrow is held on the player's hand
@onready var bow_hold_position: Marker2D = $Body/Torso/RightUperArm/RightLowerArm/RightHand/BowHoldPosition

# Packed scene reference for spawning arrows
@export var arrow_scene: PackedScene

# Variable to hold the reference of the currently active/drawn arrow
var current_arrow: Node2D = null

# Flag to check if the player is currently pulling back/charging the bow
var is_charging: bool = false

# Starting global position of the mouse when the drag action begins
var drag_start_pos: Vector2 = Vector2.ZERO

# Maximum drag distance allowed for full power charging
@export var max_drag_distance: float = 200.0

# Get the default 2D gravity value from project settings
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Offset variable used for animating trajectory prediction dots
var train_offset: float = 0.0

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	# Play the idle animation by default when the game starts
	animation_player.play("idle")

# Called every physics frame to handle movement and gravity
func _physics_process(delta: float) -> void:
	# Apply gravity if the player is not touching the floor
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Reset vertical velocity when on the floor
		velocity.y = 0.0

	# Get the current global position of the mouse cursor
	var mouse_pos = get_global_mouse_position()

	# Run this block while the player is charging/pulling the bow
	if is_charging:
		# Calculate the drag vector and distance from the start position
		var drag_vector = mouse_pos - drag_start_pos
		var drag_distance = drag_vector.length()
		
		# Animate trajectory dots continuously over time
		train_offset = fposmod(train_offset + delta * 3.5, 1.0)
		
		# Determine the aiming direction based on mouse drag
		var aim_dir = Vector2.RIGHT
		if drag_distance > 5.0:
			aim_dir = -drag_vector.normalized()
			
		# Flip the character body left or right depending on the aim direction
		var is_facing_left = aim_dir.x < 0
		if is_facing_left:
			$Body.scale.x = -1
		else:
			$Body.scale.x = 1

		# Calculate the angle of the aim direction
		var aim_angle = aim_dir.angle()
		
		# Rotate the torso properly to face the mouse aim angle
		if has_node("Body/Torso"):
			if is_facing_left:
				# Calculate correct angle to keep torso upright when facing left
				$Body/Torso.rotation = PI - aim_angle - global_rotation
			else:
				$Body/Torso.rotation = aim_angle - global_rotation
			
		# Calculate animation progress percentage based on drag distance
		var anim_progress = clamp(drag_distance / max_drag_distance, 0.0, 1.0)
		
		# Play shoot animation if it is not already playing
		if animation_player.current_animation != "shoot":
			animation_player.play("shoot")
			
		# Seek and pause animation frame according to the pull-back power progress
		animation_player.seek(anim_progress * animation_player.current_animation_length, true)
		animation_player.pause()

		# Keep the held arrow locked in position and rotation on the bow while charging
		if current_arrow and is_instance_valid(current_arrow):
			current_arrow.position = Vector2.ZERO
			current_arrow.rotation = PI / 2 
			current_arrow.scale = Vector2.ONE
			current_arrow.visible = true

		# Request a redraw to update trajectory dots visual line
		queue_redraw()
	else:
		# Reset trajectory offset when not charging
		train_offset = 0.0
		queue_redraw()

	# Move the player character and handle collisions
	move_and_slide()

# Function to handle mouse click input events for shooting mechanics
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Save click start position and begin charging the bow
				drag_start_pos = get_global_mouse_position()
				start_charge()
			else:
				# Release the arrow when mouse button is let go
				release_arrow()

# Function to initialize bow charging state and spawn an arrow in hand
func start_charge() -> void:
	is_charging = true
	train_offset = 0.0
	
	# Set animation to shoot frame 0 and pause it
	animation_player.play("shoot")
	animation_player.seek(0.0, true)
	animation_player.pause()
	
	# Instantiate and attach an arrow to the bow hand position
	if arrow_scene and bow_hold_position:
		if current_arrow and is_instance_valid(current_arrow):
			current_arrow.queue_free()
			
		current_arrow = arrow_scene.instantiate()
		bow_hold_position.add_child(current_arrow)
		
		if current_arrow and is_instance_valid(current_arrow):
			current_arrow.position = Vector2.ZERO
			current_arrow.rotation = PI / 2 
			current_arrow.scale = Vector2.ONE
			current_arrow.visible = true
			
			# Keep arrow stuck/frozen in hand while charging
			if "is_stuck" in current_arrow:
				current_arrow.is_stuck = true

# Placeholder function for trajectory updating if needed
func update_trajectory() -> void:
	pass

# Function to draw trajectory prediction dots on the screen while aiming
func _draw() -> void:
	# Exit if not charging or if bow hold position is missing
	if not is_charging or not bow_hold_position:
		return
		
	var mouse_pos = get_global_mouse_position()
	var drag_vector = mouse_pos - drag_start_pos
	var drag_distance = drag_vector.length()
	
	# Do not draw dots if drag distance is too small
	if drag_distance < 5.0:
		return
		
	var shoot_dir = -drag_vector.normalized()
	var power_factor = clamp(drag_distance / max_drag_distance, 0.1, 1.0)
	var sim_speed = 1200.0 * power_factor
	var sim_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	
	var dt = 0.08 
	var total_dots = 5
	
	# Loop to calculate and draw simulated trajectory prediction circles
	for i in range(total_dots):
		var current_t = (float(i) + train_offset) * dt
		
		# Calculate simulated future position using physics formula
		var sim_pos = bow_hold_position.global_position + (shoot_dir * sim_speed * current_t) + Vector2(0, 0.5 * sim_gravity * current_t * current_t)
		var local_pos = to_local(sim_pos)
		
		var progress = float(i) / float(total_dots - 1) if total_dots > 1 else 0.0
		var size_factor = sin(progress * PI)
		
		var current_radius = lerp(14.0, 26.0, size_factor)
		
		# Draw the trajectory dot circle on screen
		draw_circle(local_pos, current_radius, Color.WHITE)

# Function to handle releasing and firing the arrow into the world
func release_arrow() -> void:
	# Exit if the player was not charging
	if not is_charging:
		return
		
	is_charging = false
	train_offset = 0.0
	queue_redraw()
	
	# Play the shoot animation sequence
	animation_player.play("shoot")
	
	# 🎵 Play the Bow Shoot sound effect
	if has_node("ShootAudio"):
		$ShootAudio.play()
	
	# Reparent and launch the arrow into the main scene
	if current_arrow and is_instance_valid(current_arrow):
		var spawn_pos = bow_hold_position.global_position
		
		current_arrow.get_parent().remove_child(current_arrow)
		get_tree().current_scene.add_child(current_arrow)
		
		current_arrow.global_position = spawn_pos
		current_arrow.scale = Vector2(0.2, 0.2)
		current_arrow.visible = true
		
		var mouse_pos = get_global_mouse_position()
		var drag_vector = mouse_pos - drag_start_pos
		var drag_distance = drag_vector.length()
		
		# Calculate final speed based on drag power factor
		var power_factor = clamp(drag_distance / max_drag_distance, 0.1, 1.0)
		var final_speed = 1200.0 * power_factor
		
		var shoot_dir = Vector2.RIGHT
		if drag_distance > 5.0:
			shoot_dir = -drag_vector.normalized()
			
		# Assign flight direction, speed, and unfreeze state to the fired arrow
		if "direction" in current_arrow:
			current_arrow.direction = shoot_dir
		if "speed" in current_arrow:
			current_arrow.speed = final_speed
		if "is_stuck" in current_arrow:
			current_arrow.is_stuck = false
			
		current_arrow.rotation = shoot_dir.angle()
		current_arrow = null
		
	# Wait for the shoot animation to finish, then return to idle state
	await animation_player.animation_finished
	animation_player.play("idle")
