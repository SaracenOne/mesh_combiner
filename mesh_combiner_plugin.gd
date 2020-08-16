tool
extends EditorPlugin


func _init() -> void:
	print("Initialising MeshCombiner plugin")


func _notification(p_notification: int):
	match p_notification:
		NOTIFICATION_PREDELETE:
			print("Destroying MeshCombiner plugin")


func get_name() -> String:
	return "MeshCombiner"
