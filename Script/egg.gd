extends CharacterBody2D

# Reference the AnimatedSprite2D node inside the egg scene for animations and cracking sprites
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Maximum number of hits the egg can take before breaking
var max_hits: int = 3

# Current number of damage hits the egg has taken
var current_hits: int = 0

# Array to keep track of arrows that have already hit this egg
var hit_arrows = []

# Flag to check if the egg is destroyed
var is_destroyed: bool = false

# Get the default 2D gravity value from project settings
var custom_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	# Play the damage animation and pause it at the first frame to show an intact egg
	anim_sprite.play("damage")
	anim_sprite.pause()
	anim_sprite.frame = 0
	
	# Reset hits, hit arrows list, and destroyed status
	current_hits = 0
	hit_arrows.clear()
	is_destroyed = false

# Called every physics frame to handle movement and gravity
func _physics_process(delta: float) -> void:
	# Stop processing if the egg is already destroyed
	if is_destroyed:
		return
		
	# Apply custom gravity if the egg is not touching the floor
	if not is_on_floor():
		velocity.y += custom_gravity * delta
	else:
		# Reset vertical velocity when on the floor
		velocity.y = 0.0
		
	# Move the egg and handle collisions
	move_and_slide()
	
	# Loop through all collisions happening this frame
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# If the egg collides with an arrow, call the take_damage function
		if collider and collider.is_in_group("Arrows"):
			take_damage(collider)

# Function to configure egg health dynamically based on level progression
func set_egg_health(health: int) -> void:
	max_hits = health
	current_hits = 0
	hit_arrows.clear()
	velocity = Vector2.ZERO
	is_destroyed = false
	
	# Reset sprite frame to 0 if animated sprite exists
	if anim_sprite:
		anim_sprite.frame = 0

# Function to handle damage when an arrow hits the egg
func take_damage(damager: Node2D) -> void:
	# Ignore damage if already destroyed or if this specific arrow already hit the egg
	if is_destroyed or damager in hit_arrows:
		return
		
	# Add the arrow to hit list and increase hit count
	hit_arrows.append(damager)
	current_hits += 1
	
	# 🎵 Play the Hit / Crack sound effect when damaged
	if has_node("HitAudio"):
		$HitAudio.play()
	
	# Get total frames available in the damage animation sequence
	var total_frames = anim_sprite.sprite_frames.get_frame_count("damage")
	
	# Update sprite frame to show progressive cracking visual
	if current_hits < total_frames:
		anim_sprite.frame = current_hits
	
	# Check if the egg has reached its max damage limit and should break
	if current_hits >= 3 or current_hits >= total_frames - 1:
		is_destroyed = true
		
		# Immediately delete all arrows stuck inside the egg when it breaks
		for arrow in hit_arrows:
			if is_instance_valid(arrow):
				arrow.queue_free()
				
		# Notify the main scene that the egg has been destroyed (if method exists)
		var main_node = get_tree().current_scene
		if main_node and main_node.has_method("_on_egg_destroyed"):
			main_node._on_egg_destroyed()
			
		# Remove the egg node from the scene tree
		queue_free()
