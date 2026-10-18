extends Node2D

# Reference to the Player node in the scene
@onready var player = $Player

# Packed scene reference for spawning eggs
@export var egg_scene: PackedScene

# Packed scene reference for spawning wooden bases
@export var wooden_base_scene: PackedScene

# Array to keep track of active wooden bases currently in the level
var current_bases: Array = []

# Variable to track the current level progression of the game
var current_level: int = 1

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	# Start spawning the first round of the game
	spawn_new_round()

# Function to clear old objects and set up a new game round / level
func spawn_new_round() -> void:
	# 1. Clean up and delete all active arrows remaining on the screen
	for node in get_tree().get_nodes_in_group("Arrows"):
		if is_instance_valid(node):
			node.queue_free()
			
	# Double check and free any arrow nodes starting with "Arrow" name
	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Arrow") and is_instance_valid(child):
			child.queue_free()
			
	# 2. Clean up and delete all old wooden bases from the previous level
	for base in current_bases:
		if is_instance_valid(base):
			base.queue_free()
	current_bases.clear()
		
	# Initialize player position vector
	var player_pos: Vector2
	
	# 3. Handle manual curated layout setups for smooth onboarding (Levels 1 to 4)
	if current_level == 1:
		player_pos = Vector2(150.0, 520.0)
		spawn_level_entities([Vector2(950.0, 520.0)], false)
		
	elif current_level == 2:
		player_pos = Vector2(1100.0, 520.0)
		spawn_level_entities([Vector2(150.0, 520.0)], false)
		
	elif current_level == 3:
		player_pos = Vector2(1100.0, 520.0)
		spawn_level_entities([Vector2(250.0, 350.0)], true)
		
	elif current_level == 4:
		player_pos = Vector2(575.0, 520.0)
		spawn_level_entities([Vector2(300.0, 380.0), Vector2(850.0, 380.0)], true)
		
	else:
		# --- 100% UNIQUE & NON-REPEATING INFINITE GENERATION (Level 5+) ---
		# Create a unique mathematical hash based on current level to seed randomness
		var unique_hash = (current_level * 8219) ^ (current_level * 13 + 7)
		seed(unique_hash)
		
		# Alternate player starting side (Even levels: Left side, Odd levels: Right side)
		if current_level % 2 == 0:
			player_pos = Vector2(150.0, 520.0)
		else:
			player_pos = Vector2(1100.0, 520.0)
			
		# Scale total target count based on level (Caps at max 4 to avoid screen clutter)
		var egg_count: int = clampi(2 + int((current_level - 5) / 5), 2, 4)
		
		# Define horizontal boundaries where targets can spawn based on player position
		var start_x: float = 300.0 if player_pos.x < 500.0 else 200.0
		var end_x: float = 950.0 if player_pos.x < 500.0 else 750.0
		
		# Array to hold calculated positions for targets
		var positions: Array[Vector2] = []
		
		# Set a strict minimum distance gap between bases to prevent overlapping or collapsing
		var min_safe_distance: float = 200.0 
		
		var max_attempts = 100
		var attempts = 0
		
		# Loop to find safe, non-overlapping random positions for targets
		while positions.size() < egg_count and attempts < max_attempts:
			attempts += 1
			var candidate_x = randf_range(start_x, end_x)
			var candidate_y = randf_range(220.0, 420.0)
			var candidate_pos = Vector2(candidate_x, candidate_y)
			
			# Check if the candidate position is too close to any already placed position
			var too_close = false
			for existing_pos in positions:
				if abs(existing_pos.x - candidate_pos.x) < min_safe_distance:
					too_close = true
					break
			
			# Add position if it passes the safe distance check
			if not too_close:
				positions.append(candidate_pos)
		
		# Fallback method if random placement fails to find enough safe slots
		if positions.size() < egg_count:
			positions.clear()
			var span = (end_x - start_x) / egg_count
			for i in range(egg_count):
				positions.append(Vector2(start_x + (i * span) + (span / 2.0), randf_range(240.0, 400.0)))
				
		# Spawn entities using the calculated safe positions
		spawn_level_entities(positions, true)

	# Update player global position if the player node exists
	if player:
		player.global_position = player_pos
	
	print("Loaded Unique Non-Repeating Level: ", current_level)

# Function to instantiate and place bases and eggs into the game world
func spawn_level_entities(positions: Array[Vector2], use_bases: bool) -> void:
	var moving_count = 0
	# Unlock moving bases starting from level 10 and increase count progressively
	if current_level >= 10:
		moving_count = clampi(int((current_level - 10) / 6) + 1, 1, 2)
		
	# Randomly select which base indexes will move
	var moving_indices: Array = []
	if use_bases and positions.size() > 0 and moving_count > 0:
		var available_indices = range(positions.size())
		available_indices.shuffle()
		for i in range(min(moving_count, available_indices.size())):
			moving_indices.append(available_indices[i])
	
	# Loop through each calculated position to spawn bases and eggs
	for i in range(positions.size()):
		var pos = positions[i]
		var base = null
		
		# Instantiate wooden base if enabled and scene is assigned
		if use_bases and wooden_base_scene:
			base = wooden_base_scene.instantiate()
			add_child(base)
			base.global_position = pos
			current_bases.append(base)
			
			# Apply smooth movement if this base index was selected to move
			if i in moving_indices:
				apply_butter_smooth_movement(base, current_level)
				
		# Instantiate egg target
		if egg_scene:
			var egg = egg_scene.instantiate()
			
			# Attach egg as a child of the base if base exists, else add directly to main scene
			if base != null:
				base.add_child(egg)
				egg.position = Vector2(0.0, -50.0)
			else:
				add_child(egg)
				egg.global_position = pos
			
			# Ensure egg belongs to the "eggs" group
			if not egg.is_in_group("eggs"):
				egg.add_to_group("eggs")
			
			# Scale egg health dynamically as levels increase
			var egg_health = 2 + int(current_level / 4)
			if egg.has_method("set_egg_health"):
				egg.set_egg_health(egg_health)

# --- 100% JERK-FREE BUTTER SMOOTH MOVEMENT ALGORITHM ---
# Function to create a fluid, jolt-free floating movement animation for bases
func apply_butter_smooth_movement(node: Node2D, level: int) -> void:
	var initial_y = node.position.y
	var move_dist = min(22.0 + ((level - 10) * 1.0), 40.0)
	var speed = max(2.0, 3.6 - ((level - 10) * 0.02))
	
	# Seamless Sine-Wave Tweening loop (Center -> Top -> Bottom -> Center)
	# This ensures zero snapping or jerking, keeping the motion completely fluid.
	var tween = node.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(node, "position:y", initial_y - move_dist, speed)
	tween.tween_property(node, "position:y", initial_y + move_dist, speed * 2.0)
	tween.tween_property(node, "position:y", initial_y, speed)

# Called every frame to check win conditions and round progression
func _process(_delta: float) -> void:
	var remaining_eggs = get_tree().get_nodes_in_group("eggs")
	var active_egg_count = 0
	
	# Count how many valid, undeleted eggs remain in the level
	for egg in remaining_eggs:
		if is_instance_valid(egg) and not egg.is_queued_for_deletion():
			active_egg_count += 1
			
	# If all eggs are destroyed, advance to the next level and spawn a new round
	if active_egg_count == 0:
		current_level += 1
		spawn_new_round()
