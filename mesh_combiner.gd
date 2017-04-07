tool
extends Reference

var surfaces = []
var surface_formats = []

var blend_shape_names = []
var blend_shape_mode = -1

func _init():
	pass

static func get_surface_arrays_format(p_surface_arrays):
	var format = 0
	for i in range(0, p_surface_arrays.size()):
		var array = p_surface_arrays[i]
		if(array != null):
			format |= (1<<i);
	return format

static func strip_blend_shape_format(p_format):
	if p_format & Mesh.ARRAY_FORMAT_BONES:
		p_format -= Mesh.ARRAY_FORMAT_BONES
	if p_format & Mesh.ARRAY_FORMAT_WEIGHTS:
		p_format -= Mesh.ARRAY_FORMAT_WEIGHTS
	if p_format & Mesh.ARRAY_FORMAT_INDEX:
		p_format -= Mesh.ARRAY_FORMAT_INDEX
	return p_format

func find_surface_by_name(p_surface_name):
	for i in range(0, surfaces.size()):
		var surface = surfaces[i]
		if(surface.name == p_surface_name):
			return i

	return -1

func generate_mesh():
	var mesh = Mesh.new()

	for blend_shape_name in blend_shape_names:
		mesh.add_morph_target(blend_shape_name)

	for surface in surfaces:
		mesh.add_surface(surface.primitive, surface.arrays, surface.morph_arrays, surface.alphasort)
		mesh.surface_set_name(mesh.get_surface_count() - 1, surface.name)
		mesh.surface_set_material(mesh.get_surface_count() - 1, surface.material)
	print(blend_shape_mode)
	mesh.set_morph_target_mode(blend_shape_mode)

	return mesh

static func combine_surface_arrays(p_original_arrays, p_new_arrays, p_original_format, p_uv_min = Vector2(0.0, 0.0), p_uv_max = Vector2(1.0, 1.0)):
	var combined_surface_array = Array()

	for i in range(0, VisualServer.ARRAY_MAX):
		var combined_array = null
		if p_original_format & (1<<i):
			var new_array = p_new_arrays[i]
			var original_array = null
			if(p_original_arrays != null):
				original_array = p_original_arrays[i]
			if i == Mesh.ARRAY_INDEX:
				combined_array = IntArray()
				var original_surface_index_count = 0
				
				if(p_original_arrays != null):
					original_surface_index_count = p_original_arrays[Mesh.ARRAY_VERTEX].size()
					
				if(original_array != null):
					for j in range(0, original_array.size()):
						combined_array.append(original_array[j])
				
				if(new_array != null):
					for j in range(0, new_array.size()):
						combined_array.append(original_surface_index_count + new_array[j])
			else:
				if i == Mesh.ARRAY_TANGENT or i == Mesh.ARRAY_WEIGHTS or i == Mesh.ARRAY_BONES:
					combined_array = FloatArray()
				elif i == Mesh.ARRAY_COLOR:
					combined_array = ColorArray()
				else:
					combined_array = Vector3Array()
					
				if(original_array != null):
					for j in range(0, original_array.size()):
						combined_array.append(original_array[j])
				# Do we need to resize the UV?
				if(new_array != null):
					if i == Mesh.ARRAY_TEX_UV and (p_uv_min == Vector2(0.0, 0.0) or p_uv_min == Vector2(1.0, 1.0)):
						for j in range(0, new_array.size()):
							combined_array.append(Vector3(p_uv_min.x, p_uv_min.y, 0.0) + (new_array[j] * Vector3(p_uv_max.x, p_uv_max.y, 0.0)) * (Vector3(1.0, 1.0, 1.0) - Vector3(p_uv_min.x, p_uv_min.y, 0.0)))
					else:
						for j in range(0, new_array.size()):
							combined_array.append(new_array[j])
		combined_surface_array.append(combined_array)

	return combined_surface_array
	
func append_mesh(p_addition_mesh, p_uv_min = Vector2(0.0, 0.0), p_uv_max = Vector2(1.0, 1.0)):
	var new_append_mesh_combiner = Reference.new()
	new_append_mesh_combiner.set_script(get_script())
	
	for i in range(p_addition_mesh.get_surface_count()):
		new_append_mesh_combiner.surfaces.append(p_addition_mesh.get("surfaces/" + str(i)))
		new_append_mesh_combiner.surface_formats.append(p_addition_mesh.surface_get_format(i))
		
	for i in range(p_addition_mesh.get_morph_target_count()):
		new_append_mesh_combiner.blend_shape_names.append(p_addition_mesh.get_morph_target_name(i))
		
	new_append_mesh_combiner.blend_shape_mode = p_addition_mesh.get_morph_target_mode()
	
	append_mesh_combiner(new_append_mesh_combiner, p_uv_min, p_uv_max)
	
func append_mesh_combiner(p_addition, p_uv_min = Vector2(0.0, 0.0), p_uv_max = Vector2(1.0, 1.0)):
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
		for j in range(p_addition.surfaces.size()):
			matching_new_surface_id = find_surface_by_name(p_addition.surfaces[j].name)
			# Break loop if a match is found
			if matching_new_surface_id != -1:
				new_surface = p_addition.surfaces[j]
				new_surface_format = p_addition.surface_formats[j]
				break # Found!

		if matching_new_surface_id == -1:
			# This surface does not have match in the new set
			# Simply add in the new blend shapes /
			for j in range(0, new_blend_shape_names.size()):
				surfaces[i].morph_arrays.append(combine_surface_arrays(null, surfaces[i].arrays, morph_surface_format, p_uv_min, p_uv_max)) # Copy blend data for additional blend tracks (?)
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
					surfaces[i].morph_arrays[j] = combine_surface_arrays(surfaces[i].morph_arrays[j], new_surface.morph_arrays[index], morph_surface_format, p_uv_min, p_uv_max)
				else:
					# Append the copy of the new surface to use as dummy morph data extension
					surfaces[i].morph_arrays[j] = combine_surface_arrays(surfaces[i].morph_arrays[j], new_surface.arrays, morph_surface_format, p_uv_min, p_uv_max)
					
			# Add blend shapes unique to this set
			for j in range(0, new_blend_shape_names.size()):
				var index = addition_blend_shape_names.find(new_blend_shape_names[j])
				if index != -1:
					# Append the additional morph data onto a copy of the untouched surface arrays
					surfaces[i].morph_arrays.append(combine_surface_arrays(surfaces[i].arrays, new_surface.morph_arrays[index], morph_surface_format, p_uv_min, p_uv_max))
					
			# Append the extra surface data
			surfaces[i].arrays = combine_surface_arrays(surfaces[i].arrays, new_surface.arrays, original_surface_format)

	# Add new surfaces
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
					new_surface.morph_arrays.append(combine_surface_arrays(null, new_surface_morph_array[index], morph_surface_format, p_uv_min, p_uv_max))
				else:
					new_surface.morph_arrays.append(combine_surface_arrays(null, new_surface.arrays, morph_surface_format, p_uv_min, p_uv_max))

			# Add blend shapes unique to this set
			for j in range(0, new_blend_shape_names.size()):
				var index = addition_blend_shape_names.find(new_blend_shape_names[j])
				if not index == -1:
					new_surface.morph_arrays.append(combine_surface_arrays(null, new_surface_morph_array[index], morph_surface_format, p_uv_min, p_uv_max))

			# Now add it to the list of new surface
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

func clear():
	surfaces = []
	surface_formats = []

	blend_shape_names = []
	blend_shape_mode = -1