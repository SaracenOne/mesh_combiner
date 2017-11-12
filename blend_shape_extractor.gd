extends Reference
tool

const blend_shape_data_const = preload("blend_shape_data.gd")

class BlendVertex extends Reference:
	var position = Vector3()
	var normal = Vector3()
	
static func insert_blend_vertex(p_blend_verticies, p_vertex_index, p_array_index, p_new_value, p_format):
	var current_blend_vertex = null
	if(p_blend_verticies.has(p_vertex_index)):
		current_blend_vertex = p_blend_verticies[p_vertex_index]
	else:
		current_blend_vertex = BlendVertex.new()
		p_blend_verticies[p_vertex_index] = current_blend_vertex
		
	if not p_format & (1 << p_array_index):
		p_format |= (1 << p_array_index)
		
	if p_array_index == Mesh.ARRAY_VERTEX:
		current_blend_vertex.position = p_new_value
	elif p_array_index == Mesh.ARRAY_NORMAL:
		current_blend_vertex.normal = p_new_value
		
	return {"blend_verticies":p_blend_verticies, "format":p_format}

static func extract_blend_shape_from_mesh_combiner(p_mesh_combiner, p_blend_shape_name):
	var blend_shape_data = blend_shape_data_const.new()
	blend_shape_data.name = p_blend_shape_name
	
	var index = p_mesh_combiner.blend_shape_names.find(p_blend_shape_name)
	if index != -1:
		for mesh_surface in p_mesh_combiner.surfaces:
			var blend_shape_surface = {}
			blend_shape_surface.name = mesh_surface.name
			blend_shape_surface.index_array = PoolIntArray()
			blend_shape_surface.position_array = PoolVector3Array()
			blend_shape_surface.normal_array = PoolVector3Array()
			
			var base_arrays = mesh_surface.arrays
			var blend_shape_arrays = mesh_surface.morph_arrays[index]
			
			var blend_verticies = {}
			var format = 0
			
			for vertex_index in range(0, base_arrays[Mesh.ARRAY_VERTEX].size()):
				for array_index in range(0, blend_shape_arrays.size()):
					var base_array = base_arrays[array_index]
					var blend_shape_array = blend_shape_arrays[array_index]
					
					var new_value = null
					if array_index == Mesh.ARRAY_VERTEX or array_index == Mesh.ARRAY_NORMAL:
						if (base_array[vertex_index].distance_to(blend_shape_array[vertex_index]) > 0.00001):
							new_value = blend_shape_array[vertex_index] - base_array[vertex_index]
							var insert_blend_vertex_ret = insert_blend_vertex(blend_verticies, vertex_index, array_index, new_value, format)
							blend_verticies = insert_blend_vertex_ret.blend_verticies
							format = insert_blend_vertex_ret.format
			
			var index_array = PoolIntArray()
			var position_array = PoolVector3Array()
			var normal_array = PoolVector3Array()
			
			for blend_index in blend_verticies.keys():
				var blend_vertex = blend_verticies[blend_index]
				index_array.append(blend_index)
				if format & (1 << Mesh.ARRAY_VERTEX):
					position_array.append(blend_vertex.position)
				if format & (1 << Mesh.ARRAY_NORMAL):
					normal_array.append(blend_vertex.normal)
					
			blend_shape_surface.index_array = index_array
			blend_shape_surface.position_array = position_array
			blend_shape_surface.normal_array = normal_array
			
			blend_shape_data.surfaces.append(blend_shape_surface)
					
	return blend_shape_data