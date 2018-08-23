tool
extends Reference

const SURFACE_FORMAT_BITS = ArrayMesh.ARRAY_FORMAT_VERTEX + ArrayMesh.ARRAY_FORMAT_NORMAL + ArrayMesh.ARRAY_FORMAT_TANGENT + ArrayMesh.ARRAY_FORMAT_COLOR + ArrayMesh.ARRAY_FORMAT_TEX_UV + ArrayMesh.ARRAY_FORMAT_TEX_UV2 + ArrayMesh.ARRAY_FORMAT_BONES + ArrayMesh.ARRAY_FORMAT_WEIGHTS + ArrayMesh.ARRAY_FORMAT_INDEX

var surfaces = []
var surface_formats = []

var blend_shape_names = []
var blend_shape_mode = -1

static func get_surface_arrays_format(p_surface_arrays):
	var format = 0
	for i in range(0, p_surface_arrays.size()):
		var array = p_surface_arrays[i]
		if(typeof(array) != TYPE_NIL):
			format |= (1<<i);
	return format
	
static func convert_vector2_to_vector3_pool_array(p_vec2_array):
	var out = PoolVector3Array()
	for i in range(0, p_vec2_array.size()):
		out.append(Vector3(p_vec2_array[i].x, p_vec2_array[i].y, 0.0))

static func strip_blend_shape_format(p_format):
	if p_format & ArrayMesh.ARRAY_FORMAT_BONES:
		p_format -= ArrayMesh.ARRAY_FORMAT_BONES
	if p_format & ArrayMesh.ARRAY_FORMAT_WEIGHTS:
		p_format -= ArrayMesh.ARRAY_FORMAT_WEIGHTS
	if p_format & ArrayMesh.ARRAY_FORMAT_INDEX:
		p_format -= ArrayMesh.ARRAY_FORMAT_INDEX
	return p_format

func find_surface_by_name(p_surface_name):
	for i in range(0, surfaces.size()):
		var surface = surfaces[i]
		if(surface.name == p_surface_name):
			return i

	return -1

func generate_mesh(p_compression_flags = 0):
	var mesh = ArrayMesh.new()

	for blend_shape_name in blend_shape_names:
		mesh.add_blend_shape(blend_shape_name)

	for surface in surfaces:
		mesh.add_surface_from_arrays(surface.primitive, surface.arrays, surface.morph_arrays, p_compression_flags)
		mesh.surface_set_name(mesh.get_surface_count() - 1, surface.name)
		mesh.surface_set_material(mesh.get_surface_count() - 1, surface.material)
	mesh.set_blend_shape_mode(blend_shape_mode)

	return mesh

static func combine_surface_arrays(p_original_arrays, p_new_arrays, p_original_format, p_uv_min = Vector2(0.0, 0.0), p_uv_max = Vector2(1.0, 1.0), p_uv2_min = Vector2(0.0, 0.0), p_uv2_max = Vector2(1.0, 1.0), p_transform = Transform(), p_weld_distance = -1.0):
	var combined_surface_array = []

	for array_index in range(0, ArrayMesh.ARRAY_MAX):
		var combined_array = null
		if p_original_format & (1 << array_index):
			var new_array = p_new_arrays[array_index]
			var original_array = null
			
			if(typeof(p_original_arrays) == TYPE_ARRAY):
				original_array = p_original_arrays[array_index]
				
			if array_index == ArrayMesh.ARRAY_INDEX:
				combined_array = PoolIntArray()
				var original_surface_index_count = 0
				
				if(typeof(p_original_arrays) == TYPE_ARRAY):
					original_surface_index_count = p_original_arrays[ArrayMesh.ARRAY_VERTEX].size()
					
				if(typeof(original_array) != TYPE_NIL):
					for i in range(0, original_array.size()):
						combined_array.append(original_array[i])
				
				if(typeof(new_array) != TYPE_NIL):
					for i in range(0, new_array.size()):
						combined_array.append(original_surface_index_count + new_array[i])
			else:
				if array_index == ArrayMesh.ARRAY_TANGENT or array_index == ArrayMesh.ARRAY_WEIGHTS or array_index == ArrayMesh.ARRAY_BONES:
					combined_array = PoolRealArray()
				elif array_index == ArrayMesh.ARRAY_COLOR:
					combined_array = PoolColorArray()
				elif array_index == ArrayMesh.ARRAY_TEX_UV or array_index == ArrayMesh.ARRAY_TEX_UV2:
					combined_array = PoolVector2Array()
				else:
					combined_array = PoolVector3Array()
					
				if(typeof(original_array) != TYPE_NIL):
					for i in range(0, original_array.size()):
						combined_array.append(original_array[i])
						
				# Do we need to resize the UV?
				# TODO check: these might be some issues with UV vector size (2/3)
				if(typeof(new_array) != TYPE_NIL):
					if array_index == ArrayMesh.ARRAY_TEX_UV and (p_uv_min != Vector2(0.0, 0.0) or p_uv_max != Vector2(1.0, 1.0)):
						var uv_min3 = Vector3(p_uv_min.x, p_uv_min.y, 0.0)
						var uv_max3 = Vector3(p_uv_max.x, p_uv_max.y, 0.0)
						for i in range(0, new_array.size()):
							combined_array.append(uv_min3 + (new_array[i] * uv_max3) * (Vector3(1.0, 1.0, 0.0) - uv_min3))
					elif array_index == ArrayMesh.ARRAY_TEX_UV2 and (p_uv2_min != Vector2(0.0, 0.0) or p_uv2_max != Vector2(1.0, 1.0)):
						var uv_min3 = Vector3(p_uv2_min.x, p_uv2_min.y, 0.0)
						var uv_max3 = Vector3(p_uv2_max.x, p_uv2_max.y, 0.0)
						for i in range(0, new_array.size()):
							combined_array.append(uv_min3 + (new_array[i] * uv_max3) * (Vector3(1.0, 1.0, 0.0) - uv_min3))
					elif ((array_index == ArrayMesh.ARRAY_VERTEX) and p_transform != Transform()):
						# If a p_weld_distance is specified, we will attempt to copy the closest existing vertex
						# already in the array in order to avoid cracks in the final mesh.
						if 0: #p_weld_distance >= 0.0:
							for i in range(0, new_array.size()):
								var new_vertex = p_transform.xform(new_array[i])
								if(typeof(original_array) == TYPE_VECTOR3_ARRAY):
									for j in range(0, original_array.size()):
										if original_array[j].distance_to(new_vertex) < p_weld_distance:
											new_vertex = original_array[j]
											break
								combined_array.append(new_vertex)
						else:
							for i in range(0, new_array.size()):
								combined_array.append(p_transform.xform(new_array[i]))
					elif ((array_index == ArrayMesh.ARRAY_NORMAL) and p_transform != Transform()):
						for i in range(0, new_array.size()):
							combined_array.append(p_transform.basis.xform(new_array[i]))
					else:
						for i in range(0, new_array.size()):
							combined_array.append(new_array[i])
		combined_surface_array.append(combined_array)
		
	return combined_surface_array
	
static func scaled_uv_array(p_tex_uv_array, p_uv_min, p_uv_max):
	var tex_uv_array = p_tex_uv_array
	
	var uv_min3 = Vector3(p_uv_min.x, p_uv_min.y, 0.0)
	var uv_max3 = Vector3(p_uv_max.x, p_uv_max.y, 0.0)
	for i in range(0, tex_uv_array.size()):
		tex_uv_array[i] = uv_min3 + (tex_uv_array[i] * uv_max3) * (Vector3(1.0, 1.0, 0.0) - uv_min3)
	
	return tex_uv_array
	
static func remapped_bone_array(p_bone_array, p_bone_remaps):
	var bone_array = p_bone_array
	
	for i in range(0, bone_array.size()):
		bone_array[i] = p_bone_remaps[bone_array[i]]
	
	return bone_array
	
func append_mesh(p_addition_mesh, p_uv_min = Vector2(0.0, 0.0), p_uv_max = Vector2(1.0, 1.0), p_uv2_min = Vector2(0.0, 0.0), p_uv2_max = Vector2(1.0, 1.0), p_transform = Transform(), p_bone_remaps = PoolIntArray(), p_weld_distance = -1.0):
	if p_addition_mesh is ArrayMesh or p_addition_mesh is PrimitiveMesh:
		var new_append_mesh_combiner = Reference.new()
		new_append_mesh_combiner.set_script(get_script())
	
		if p_addition_mesh is ArrayMesh:
			for i in range(p_addition_mesh.get_surface_count()):
				var new_surface = {}
				new_surface.name = p_addition_mesh.surface_get_name(i)
				new_surface.primitive = p_addition_mesh.surface_get_primitive_type(i)
				new_surface.material = p_addition_mesh.surface_get_material(i)
				new_surface.arrays = p_addition_mesh.surface_get_arrays(i)
				
				# Make sure all standard arrays are PoolVector3Arrays
				for j in range(0, new_surface.arrays.size()):
					if j == ArrayMesh.ARRAY_VERTEX or j == ArrayMesh.ARRAY_NORMAL or j == ArrayMesh.ARRAY_TANGENT:
						if typeof(new_surface.arrays[j]) == TYPE_VECTOR2_ARRAY:
							new_surface.arrays[j] = convert_vector2_to_vector3_pool_array(new_surface.arrays[j])
					if j == ArrayMesh.ARRAY_BONES:
						if p_bone_remaps.size() > 0:
							new_surface.arrays[j] = remapped_bone_array(new_surface.arrays[j], p_bone_remaps)
						
				new_surface.morph_arrays = p_addition_mesh.surface_get_blend_shape_arrays(i)
				
				# Does this actually work? Todo: test
				for morph_array in new_surface.morph_arrays:
					for j in range(0, morph_array.size()):
						if j == ArrayMesh.ARRAY_VERTEX or j == ArrayMesh.ARRAY_NORMAL or j == ArrayMesh.ARRAY_TANGENT:
							if typeof(morph_array[j]) == TYPE_VECTOR2_ARRAY:
								morph_array[j] = convert_vector2_to_vector3_pool_array(morph_array[j])
						if j == ArrayMesh.ARRAY_BONES:
							if p_bone_remaps.size() > 0:
								morph_array[j] = remapped_bone_array(new_surface.arrays[j], p_bone_remaps)
				
				new_append_mesh_combiner.surfaces.append(new_surface)
				
				var format = p_addition_mesh.surface_get_format(i) & SURFACE_FORMAT_BITS
				new_append_mesh_combiner.surface_formats.append(format)
		
			for i in range(p_addition_mesh.get_blend_shape_count()):
				new_append_mesh_combiner.blend_shape_names.append(p_addition_mesh.get_blend_shape_name(i))
		
			new_append_mesh_combiner.blend_shape_mode = p_addition_mesh.get_blend_shape_mode()
		elif p_addition_mesh is PrimitiveMesh:
			var new_surface = {}
			new_surface.name = "PrimitiveMeshSurface"
			new_surface.primitive = ArrayMesh.PRIMITIVE_TRIANGLES
			new_surface.material = p_addition_mesh.material
			new_surface.arrays = p_addition_mesh.get_mesh_arrays()
			new_surface.morph_arrays = []
			
			new_append_mesh_combiner.surfaces.append(new_surface)
			
			# TODO: While this is currently correct for builtin primitives, it might still be worth exposing the format to C++ code for the sake of custom primitives
			var format = ArrayMesh.ARRAY_FORMAT_VERTEX + ArrayMesh.ARRAY_FORMAT_NORMAL + ArrayMesh.ARRAY_FORMAT_TANGENT + ArrayMesh.ARRAY_FORMAT_TEX_UV + ArrayMesh.ARRAY_FORMAT_INDEX
			new_append_mesh_combiner.surface_formats.append(format)
		
	
		append_mesh_combiner(new_append_mesh_combiner, p_uv2_min, p_uv_max, p_uv_min, p_uv2_max, p_transform, p_weld_distance)
	
func append_mesh_combiner(p_addition, p_uv_min = Vector2(0.0, 0.0), p_uv_max = Vector2(1.0, 1.0), p_uv2_min = Vector2(0.0, 0.0), p_uv2_max = Vector2(1.0, 1.0), p_transform = Transform(), p_weld_distance = -1.0, p_bone_remaps = []):
	if(p_addition == null):
		return

	if(blend_shape_mode == -1):
		blend_shape_mode = p_addition.blend_shape_mode
	
	if(blend_shape_mode != p_addition.blend_shape_mode):
		printerr("blendshape mode mismatch")
		return

	# Create a list of incoming blend shape names
	var addition_blend_shape_names = []
	for i in range(p_addition.blend_shape_names.size()):
		addition_blend_shape_names.append(p_addition.blend_shape_names[i])

	# Now create a list of blendshape names unique to this incoming mesh
	var new_blend_shape_names = []
	for i in range(0, addition_blend_shape_names.size()):
		var index = blend_shape_names.find(addition_blend_shape_names[i])
		if index == -1:
			new_blend_shape_names.append(addition_blend_shape_names[i])

	# Iterate through the original surfaces
	for i in range(0, surfaces.size()):
		var original_surface_format = get_surface_arrays_format(surfaces[i].arrays)

		# Remove unneeded elements from morph format
		var morph_surface_format = strip_blend_shape_format(original_surface_format)

		# Get the name of this surface
		var surface_name = surfaces[i].name

		# Now iterate through the surfaces of the new mesh to find a match
		var new_surface = null
		var new_surface_format = 0
		var matching_new_surface_id = -1

		# Determine if there is a matching surface in the new addition mesh
		matching_new_surface_id = p_addition.find_surface_by_name(surfaces[i].name)
		# Break loop if a match is found
		if matching_new_surface_id != -1:
			new_surface = p_addition.surfaces[matching_new_surface_id]
			new_surface_format = p_addition.surface_formats[matching_new_surface_id]

		if matching_new_surface_id == -1:
			# This surface does not have match in the new set
			# Simply add in the new blend shapes /
			for j in range(0, new_blend_shape_names.size()):
				surfaces[i].morph_arrays.append(combine_surface_arrays(null, surfaces[i].arrays, morph_surface_format, p_uv_min, p_uv_max, p_uv2_min, p_uv2_max, p_transform, p_weld_distance)) # Copy blend data for additional blend tracks (?)
		else:
			# This surface has a matching surface name in the new set
			# Combine the verticies and blend shapes
			if new_surface_format != surface_formats[i]: # ???
				printerr("surface format mismatch!")
				continue
				
			# Add blend shapes from already in the current set
			for j in range(0, blend_shape_names.size()):
				var index = addition_blend_shape_names.find(blend_shape_names[j])
				if index != -1:
					# Append the additional morph data onto the original morph data
					surfaces[i].morph_arrays[j] = combine_surface_arrays(surfaces[i].morph_arrays[j], new_surface.morph_arrays[index], morph_surface_format, p_uv_min, p_uv_max, p_uv2_min, p_uv2_max, p_transform, p_weld_distance)
				else:
					# Append the copy of the new surface to use as dummy morph data extension
					surfaces[i].morph_arrays[j] = combine_surface_arrays(surfaces[i].morph_arrays[j], new_surface.arrays, morph_surface_format, p_uv_min, p_uv_max, p_uv2_min, p_uv2_max, p_transform, p_weld_distance)
					
			# Add blend shapes unique to this set
			for j in range(0, new_blend_shape_names.size()):
				var index = addition_blend_shape_names.find(new_blend_shape_names[j])
				if index != -1:
					# Append the additional morph data onto a copy of the untouched surface arrays
					surfaces[i].morph_arrays.append(combine_surface_arrays(surfaces[i].arrays, new_surface.morph_arrays[index], morph_surface_format, p_uv_min, p_uv_max, p_uv2_min, p_uv2_max, p_transform, p_weld_distance))
					
			# Append the extra surface data
			surfaces[i].arrays = combine_surface_arrays(surfaces[i].arrays, new_surface.arrays, original_surface_format, p_uv_min, p_uv_max, p_uv2_min, p_uv2_max, p_transform, p_weld_distance)
			
	for i in range(0, p_addition.surfaces.size()):
		var new_surface = p_addition.surfaces[i]
		if find_surface_by_name(new_surface.name) == -1:
			var new_surface_format = get_surface_arrays_format(new_surface.arrays)

			# Remove unneeded elements from morph format
			var morph_surface_format = strip_blend_shape_format(new_surface_format)

			# Save and dereference the original morph arrays
			var new_surface_morph_array = new_surface.morph_arrays
			new_surface.morph_arrays = []

			# Add blend shapes from already in the current set
			for j in range(0, blend_shape_names.size()):
				var index = addition_blend_shape_names.find(blend_shape_names[j])
				if index != -1:
					new_surface.morph_arrays.append(combine_surface_arrays(null, new_surface_morph_array[index], morph_surface_format, p_uv_min, p_uv_max, p_uv2_min, p_uv2_max, p_transform, p_weld_distance))
				else:
					new_surface.morph_arrays.append(combine_surface_arrays(null, new_surface.arrays, morph_surface_format, p_uv_min, p_uv_max, p_uv2_min, p_uv2_max, p_transform, p_weld_distance))

			# Add blend shapes unique to this set
			for j in range(0, new_blend_shape_names.size()):
				var index = addition_blend_shape_names.find(new_blend_shape_names[j])
				if not index == -1:
					new_surface.morph_arrays.append(combine_surface_arrays(null, new_surface_morph_array[index], morph_surface_format, p_uv_min, p_uv_max, p_uv2_min, p_uv2_max, p_transform, p_weld_distance))

			# Now add it to the list of new surface
			if p_uv_min != Vector2(0.0, 0.0) or p_uv_max != Vector2(1.0, 1.0):
				if new_surface.arrays.size() >= ArrayMesh.ARRAY_TEX_UV:
					new_surface.arrays[ArrayMesh.ARRAY_TEX_UV] = scaled_uv_array(new_surface.arrays[ArrayMesh.ARRAY_TEX_UV], p_uv_min, p_uv_max)
					
			if p_uv2_min != Vector2(0.0, 0.0) or p_uv2_max != Vector2(1.0, 1.0):
				if new_surface.arrays.size() >= ArrayMesh.ARRAY_TEX_UV2:					
					new_surface.arrays[ArrayMesh.ARRAY_TEX_UV2] = scaled_uv_array(new_surface.arrays[ArrayMesh.ARRAY_TEX_UV2], p_uv2_min, p_uv2_max)
			
			# Transform the verticies
			if p_transform != Transform():
				if new_surface.arrays.size() >= ArrayMesh.ARRAY_VERTEX:
					var vertex_array = new_surface.arrays[ArrayMesh.ARRAY_VERTEX]
					for j in range(0, vertex_array.size()):
						vertex_array[j] = p_transform.xform(vertex_array[j])
					new_surface.arrays[ArrayMesh.ARRAY_VERTEX] = vertex_array
				if new_surface.arrays.size() >= ArrayMesh.ARRAY_NORMAL:
					var normal_array = new_surface.arrays[ArrayMesh.ARRAY_NORMAL]
					for j in range(0, normal_array.size()):
						normal_array[j] = p_transform.basis.xform(normal_array[j])
					new_surface.arrays[ArrayMesh.ARRAY_NORMAL] = normal_array
					
			surfaces.append(new_surface)
			surface_formats.append(new_surface_format)

	# Append the new blend shapes
	for i in range(0, new_blend_shape_names.size()):
		blend_shape_names.append(new_blend_shape_names[i])

func remove_blend_shape(p_blend_shape_name):
	var index = blend_shape_names.find(p_blend_shape_name)
	if index != -1:
		blend_shape_names.remove(index)
		for surface in surfaces:
			surface.morph_arrays.remove(index)
			
static func combine_skeletons(p_target_skeleton, p_addition_skeleton):
	var bone_remap_table = PoolIntArray()
	
	for i in range(0, p_addition_skeleton.get_bone_count()):
		var addition_bone_name = p_addition_skeleton.get_bone_name(i)
		
		var bone_id = p_target_skeleton.find_bone(addition_bone_name)
		if bone_id != -1:
			# Bone has a match in the target skeleton, so just add this to the table
			bone_remap_table.push_back(bone_id)
		else:
			# New bone, so add it to the target skeleton
			p_target_skeleton.add_bone(addition_bone_name)
			# Check to see if this new bone has a parent
			var bone_parent = p_addition_skeleton.get_bone_parent(i)
			if bone_parent != -1:
				# Now get the name of this bone's parent
				var bone_parent_name = p_addition_skeleton.get_bone_name(bone_parent)
				#  Now find the bone ID for this parent in the target skeleton
				var target_id = p_target_skeleton.find_bone(bone_parent_name)
				if target_id != -1:
					# Set this new bone's parent
					p_target_skeleton.set_bone_parent(p_target_skeleton.get_bone_count()-1, target_id)
			
			# Copy over the pose and rest for this new bone
			p_target_skeleton.set_bone_pose(p_target_skeleton.get_bone_count()-1, p_addition_skeleton.get_bone_pose(i))
			p_target_skeleton.set_bone_rest(p_target_skeleton.get_bone_count()-1, p_addition_skeleton.get_bone_rest(i))
			
			# Add this new bone to the table
			bone_remap_table.push_back(p_target_skeleton.get_bone_count()-1)
			
	return bone_remap_table

func clear():
	surfaces = []
	surface_formats = []

	blend_shape_names = []
	blend_shape_mode = -1