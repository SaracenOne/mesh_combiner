extends Resource
tool

class BlendShapeSurface extends Resource:
	export(String) var name = ""
	export(IntArray) var index_array = IntArray()
	export(Vector3Array) var position_array = Vector3Array()
	export(Vector3Array) var normal_array = Vector3Array()

export(String) var name = ""
export(Array) var surfaces = []
	
func clear_surfaces():
	name = ""
	surfaces = []