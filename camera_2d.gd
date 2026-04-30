extends Camera2D

# Limit camera so it does not show anything below Y = 500
func _limit_camera_y() -> void:
	if global_position.y > 500:
		global_position.y = 500

func _ready() -> void:
	_limit_camera_y()

func _process(_delta: float) -> void:
	_limit_camera_y()
