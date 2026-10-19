# Extends Node2D for 2D game level management
extends Node2D

# Reference to the player node in the scene
@onready var player = $Player

# Preloaded scene for spawning egg targets
@export var egg_scene: PackedScene

# Preloaded scene for spawning wooden platforms
@export var wooden_base_scene: PackedScene

# Array to keep track of active wooden bases on screen
var current_bases: Array = []

# Variable to track the current level number
var current_level: int = 1

# Called when the node enters the scene tree
func _ready() -> void:
	# Call function to start the first round
	spawn_new_round()

# Function to clear old objects and start a new level round
func spawn_new_round() -> void:
	# Loop through all nodes in the Arrows group
	for node in get_tree().get_nodes_in_group("Arrows"):
		# Check if the arrow node is valid
		if is_instance_valid(node):
			# Delete the arrow node from memory
			node.queue_free()
			
	# Loop through all children in the current scene
	for child in get_tree().current_scene.get_children():
		# Check if child name starts with Arrow and is valid
		if child.name.begins_with("Arrow") and is_instance_valid(child):
			# Delete the extra arrow node
			child.queue_free()
			
	# Loop through all stored wooden bases from last level
	for base in current_bases:
		# Check if the base node is valid
		if is_instance_valid(base):
			# Delete the base node
			base.queue_free()
	# Clear the bases array
	current_bases.clear()
		
	# Declare a variable for player position vector
	var player_pos: Vector2
	
	# Check if current level is 1
	if current_level == 1:
		# Set fixed player position for level 1
		player_pos = Vector2(150.0, 520.0)
		# Spawn target entity for level 1 without bases or moving platforms
		spawn_level_entities([Vector2(950.0, 520.0)], false, false)
	# Check if current level is 2
	elif current_level == 2:
		# Set fixed player position for level 2
		player_pos = Vector2(1100.0, 520.0)
		# Spawn target entity for level 2
		spawn_level_entities([Vector2(150.0, 520.0)], false, false)
	# Check if current level is 3
	elif current_level == 3:
		# Set fixed player position for level 3
		player_pos = Vector2(1100.0, 520.0)
		# Spawn target entity with wooden base enabled
		spawn_level_entities([Vector2(250.0, 350.0)], true, false)
	# Check if current level is 4
	elif current_level == 4:
		# Set fixed player position for level 4
		player_pos = Vector2(575.0, 520.0)
		# Spawn two target entities with wooden bases
		spawn_level_entities([Vector2(300.0, 380.0), Vector2(850.0, 380.0)], true, false)
	# For levels 5 and above, generate unique procedural levels
	else:
		# Generate a unique mathematical seed based on level number
		var unique_seed = current_level * 4861 + current_level * 239 + 41
		# Apply the generated seed for randomness
		seed(unique_seed)
		
		# Define possible player side positions
		var p_sides = [120.0, 1150.0]
		# Select player x position based on level parity
		var p_x = p_sides[current_level % 2]
		# Set player position vector
		player_pos = Vector2(p_x, 520.0)
		
		# Calculate total targets for this level, clamped between 2 and 4
		var target_count = clampi(2 + int(current_level / 4), 2, 4)
		
		# Define available horizontal lanes to prevent overlapping
		var available_lanes = [320.0, 520.0, 720.0, 920.0]
		# Shuffle lanes randomly
		available_lanes.shuffle()
		
		# Define available vertical height tiers
		var available_heights = [200.0, 310.0, 420.0]
		# Shuffle heights randomly
		available_heights.shuffle()
		
		# Create an empty array for target positions
		var positions: Array[Vector2] = []
		# Loop to assign safe lane and height to each target
		for i in range(target_count):
			# Get x coordinate from lane array
			var cx = available_lanes[i]
			# Get y coordinate from height array
			var cy = available_heights[i % available_heights.size()]
			# Add position vector to array
			positions.append(Vector2(cx, cy))
				
		# Enable moving platforms if level is 8 or higher
		var use_mov = current_level >= 8
		# Spawn the generated procedural entities
		spawn_level_entities(positions, true, use_mov)

	# Check if player node exists in the scene
	if player:
		# Update player global position
		player.global_position = player_pos

# Function to spawn bases and eggs into the game world
func spawn_level_entities(positions: Array[Vector2], use_bases: bool, use_moving: bool) -> void:
	# Array to keep track of indices that will move
	var moving_indices: Array = []
	# Check if moving is allowed and positions exist
	if use_moving and positions.size() > 0:
		# Calculate how many bases should move
		var count = clampi(int(current_level / 5), 1, 2)
		# Get available position indices
		var available = range(positions.size())
		# Shuffle available indices
		available.shuffle()
		# Pick random indices up to the moving count
		for i in range(min(count, available.size())):
			moving_indices.append(available[i])
	
	# Loop through each position to instantiate objects
	for i in range(positions.size()):
		# Get current position vector
		var pos = positions[i]
		# Initialize base variable as null
		var base = null
		
		# Check if bases are enabled and scene is assigned
		if use_bases and wooden_base_scene:
			# Instantiate wooden base scene
			base = wooden_base_scene.instantiate()
			# Add base as child to current node
			add_child(base)
			# Set base global position
			base.global_position = pos
			# Add base to tracking array
			current_bases.append(base)
			
			# Check if this base index should move
			if i in moving_indices:
				# Apply smooth movement animation
				apply_butter_smooth_movement(base, current_level)
				
		# Check if egg scene is assigned
		if egg_scene:
			# Instantiate egg scene
			var egg = egg_scene.instantiate()
			
			# Check if wooden base exists
			if base != null:
				# Add egg as child of the base
				base.add_child(egg)
				# Position egg snugly above the base
				egg.position = Vector2(0.0, -50.0)
			else:
				# Add egg directly to main scene if no base
				add_child(egg)
				# Set egg global position
				egg.global_position = pos
			
			# Check if egg is not already in the eggs group
			if not egg.is_in_group("eggs"):
				# Add egg to eggs group
				egg.add_to_group("eggs")
			
			# Scale egg health dynamically based on level
			var egg_health = 2 + int(current_level / 3)
			# Check if egg has health setting method
			if egg.has_method("set_egg_health"):
				# Apply calculated health to egg
				egg.set_egg_health(egg_health)

# Function to apply smooth tween movement to wooden bases
func apply_butter_smooth_movement(node: Node2D, level: int) -> void:
	# Get initial y position of the node
	var initial_y = node.position.y
	# Calculate movement distance based on level
	var move_dist = min(18.0 + (level * 0.4), 35.0)
	# Calculate movement speed based on level
	var speed = max(1.6, 2.8 - (level * 0.01))
	
	# Create looping tween animation
	var tween = node.create_tween().set_loops()
	# Set transition type and ease mode for smoothness
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Tween position up
	tween.tween_property(node, "position:y", initial_y - move_dist, speed)
	# Tween position down
	tween.tween_property(node, "position:y", initial_y + move_dist, speed * 2.0)
	# Tween position back to center
	tween.tween_property(node, "position:y", initial_y, speed)

# Called every frame to check game state
func _process(_delta: float) -> void:
	# Get all nodes belonging to the eggs group
	var remaining_eggs = get_tree().get_nodes_in_group("eggs")
	# Initialize active egg count to zero
	var active_egg_count = 0
	
	# Loop through remaining eggs
	for egg in remaining_eggs:
		# Check if egg is valid and not deleted
		if is_instance_valid(egg) and not egg.is_queued_for_deletion():
			# Increment active egg count
			active_egg_count += 1
			
	# Check if all eggs are destroyed
	if active_egg_count == 0:
		# Increase level number by 1
		current_level += 1
		# Start the next round / level
		spawn_new_round()
