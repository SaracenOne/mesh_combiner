tool
extends EditorPlugin

func get_name(): 
	return "MeshCombiner"

func _enter_tree():
	add_custom_type("BlendShapeData","Resource",preload("blend_shape_data.gd"),preload("icon_blend_shape_data.png"))

func _exit_tree():
	remove_custom_type("BlendShapeData")