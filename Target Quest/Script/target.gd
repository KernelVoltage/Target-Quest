extends Area2D

@export var max_health: int = 3
var current_health: int = 3

@onready var animated_sprite = $AnimatedSprite2D

func _ready() -> void:
	current_health = max_health
	# Automatically play fly animation if it exists
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("fly"):
		animated_sprite.play("fly")

func set_egg_health(h: int) -> void:
	max_health = h
	current_health = h

func destroy_egg() -> void:
	current_health -= 1
	
	if current_health <= 0:
		# Play dead animation if available, otherwise just free
		if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("dead"):
			animated_sprite.play("dead")
			
		# Level manager ko check karwane ke liye ya chota delay dene ke liye
		var level_manager = get_tree().get_first_node_in_group("level_manager")
		if is_instance_valid(level_manager) and level_manager.has_method("check_level_completion"):
			level_manager.check_level_completion()
			
		await get_tree().create_timer(0.3).timeout
		queue_free()
