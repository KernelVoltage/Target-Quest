extends Area2D

# Set the default speed of the arrow when fired
@export var speed: float = 800.0

# Set the initial movement direction of the arrow to the right
var direction: Vector2 = Vector2.RIGHT

# Flag to check if the arrow has hit something and stopped
var is_stuck: bool = false

# Get the default 2D gravity value from project settings
var custom_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Initialize the velocity vector to zero
var velocity: Vector2 = Vector2.ZERO

# Reference the RayCast2D node inside the arrow scene for collision detection
@onready var ray_cast: RayCast2D = $RayCast2D

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	# Add this arrow instance into the "Arrows" group
	add_to_group("Arrows")
	
	# Find the player node in the scene tree
	var player = get_tree().get_first_node_in_group("Player")
	
	# If player and raycast exist, add player as an exception so the arrow won't stick to them
	if player and ray_cast:
		ray_cast.add_exception(player)
	
	# Enable raycast and allow it to detect collision areas
	if ray_cast:
		ray_cast.enabled = true
		ray_cast.collide_with_areas = true

# Called every frame during the processing step
func _process(delta: float) -> void:
	# Stop processing movement if the arrow is already stuck
	if is_stuck:
		return
		
	# If velocity is zero, calculate initial velocity based on direction and speed
	if velocity == Vector2.ZERO:
		velocity = direction.normalized() * speed

	# Apply gravity to the vertical velocity over time
	velocity.y += custom_gravity * delta
	
	# Move the arrow position based on velocity and delta time
	position += velocity * delta
	
	# Rotate the arrow to match its movement trajectory angle
	rotation = velocity.angle()
	
	# Check if the raycast collides with any object
	if ray_cast and ray_cast.is_colliding():
		# Get the object that the arrow collided with
		var collider = ray_cast.get_collider()
		
		# If the arrow hits another arrow, ignore it and let it pass through
		if collider and collider.is_in_group("Arrows"):
			ray_cast.add_exception(collider)
			return
			
		# Get the exact global coordinates where the collision happened
		var hit_point = ray_cast.get_collision_point()
		
		# If the hit object is an egg, deal damage to it
		if collider and collider.has_method("take_damage"):
			collider.take_damage(self)
			
		# Call the stick function and pass the hit point and collider object
		stick_arrow(hit_point, collider)

# Function to handle arrow sticking mechanics when it hits a target
func stick_arrow(hit_point: Vector2, collider: Node) -> void:
	# Exit if the arrow is already stuck
	if is_stuck:
		return
		
	# Mark the arrow as stuck and stop its movement
	is_stuck = true
	speed = 0.0
	velocity = Vector2.ZERO
	
	# Calculate offset to align the arrow tip perfectly with the hit point
	var tip_pos = ray_cast.global_position
	var offset = global_position - tip_pos
	global_position = hit_point + offset
	
	# Lower the z-index so the arrow renders behind the target for visual depth
	z_index = -1 
	
	# Check if the collider object is valid
	if collider and is_instance_valid(collider):
		# Play Base audio sound if the collider has a BaseAudio node
		if collider.has_node("BaseAudio"):
			collider.get_node("BaseAudio").play()
		# Play Grass audio sound if the collider has a GrassAudio node
		elif collider.has_node("GrassAudio"):
			collider.get_node("GrassAudio").play()
		# Play Hit audio sound if the collider has a HitAudio node
		elif collider.has_node("HitAudio"):
			collider.get_node("HitAudio").play()
			
		# Save current global transform before changing parents
		var global_trans = global_transform
		
		# Remove arrow from its current parent
		get_parent().remove_child(self)
		
		# Make the hit object the new parent so the arrow moves along with it
		collider.add_child(self)
		
		# Restore the global transform so the arrow doesn't jump or shift position
		global_transform = global_trans
	
	# Stop the process function since the arrow is now stationary
	set_process(false)
