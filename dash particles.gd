extends GPUParticles3D

@onready var camera = $"../Camera3D"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	global_transform.origin = camera.global_transform.origin
