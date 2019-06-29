extends Resource
class_name BlendShapeData, "icon_blend_shape_data.svg"
tool

# Todo: cannot serialize this as a subresource from another resource. Bug?
class BlendShapeSurface extends Resource:
	export(String) var name : String = ""
	export(PoolIntArray) var index_array : PoolIntArray = PoolIntArray()
	export(PoolVector3Array) var position_array : PoolVector3Array = PoolVector3Array()
	export(PoolVector3Array) var normal_array : PoolVector3Array = PoolVector3Array()

export(String) var name : String = ""
export(Array) var surfaces : Array = []
	
func clear_surfaces() -> void:
	name = ""
	surfaces = []
