extends Resource
tool

# Todo: cannot serialize this as a subresource from another resource. Bug?
class BlendShapeSurface extends Resource:
	export(String) var name = ""
	export(PoolIntArray) var index_array = PoolIntArray()
	export(PoolVector3Array) var position_array = PoolVector3Array()
	export(PoolVector3Array) var normal_array = PoolVector3Array()

export(String) var name = ""
export(Array) var surfaces = []
	
func clear_surfaces():
	name = ""
	surfaces = []