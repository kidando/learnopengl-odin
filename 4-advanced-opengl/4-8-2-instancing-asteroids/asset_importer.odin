/**
NOTES:
- This implementation of importing 3d assets using gltf largely draws from learnopengl's implementation using assimp.
- This is not a complete utilization or showcase of all gltf features. The main goal is load a single model with a texture material attached (for both .glb and .gltf scenarios). Base color or albedo/diffuse was the only focus.
- In gltf, a primitive or mesh primitive represents a single drawable entity
- GLTF UVs are loaded with Y flipped to match OpenGL's bottom-left origin.
- Blender/glTF uses top-left origin, so we correct it here.
- It is highly recommended that you familiarize yourself with the gltf format before proceeding. https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html

Something to keep in mind about unpacking attributes e.g. the procedure ai_unpack_attribute_f32_vec3()
- GLTF data is stored in a way that is similar to how the OpenGL graphics pipeline constructs buffers that get sent to the GPU
- In fact, unpacking data from gltf data buffers is kinda like the deconstructing the Vertex Array Object or VAO
- You need to know what type of data was packed, the length and the offset between other data types (among other things)
- Hopefully this saves you time in figuring out what is happening 😎

**/
package main

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:mem"
import "core:path/filepath"
import "core:strings"
import gl "vendor:OpenGL"
import cg "vendor:cgltf"
import stbi "vendor:stb/image"

Vertex :: struct {
	position:  glm.vec3,
	normal:    glm.vec3,
	texcoords: glm.vec2,
}

TextureType :: enum {
	DIFFUSE,
	NORMAL,
}

Texture :: struct {
	id:   u32,
	type: TextureType,
}

Primitive :: struct {
	vertices: [dynamic]Vertex,
	indices:  [dynamic]u32,
	textures: [dynamic]Texture,
	vao, vbo, ebo:      u32,
}

Mesh :: struct {
	primitives: [dynamic]Primitive,
}

Model :: struct {
	meshes:    [dynamic]Mesh,
	directory: string,
}

ai_load_gltf_model :: proc(_model: ^Model, _filepath: cstring) {
	// 1. Load and parse GLTF/GLB from file
	options: cg.options
	gltf_data, parse_result := cg.parse_file(options, _filepath)

	if parse_result != .success {
		fmt.eprintln("ERROR::ai_load_gltf_model()::Failed to parse .gltf/.glb file,\n%v ", _filepath)
		fmt.eprintln("%v", parse_result)
		return
	}

	defer cg.free(gltf_data)

	// 2. Load buffers (scene data that's packed/embedded)
	load_buffers_result := cg.load_buffers(options, gltf_data, _filepath)
	if load_buffers_result != .success {
		fmt.eprintln("ERROR::ai_load_gltf_model()::Failed to load buffers")
		fmt.eprintln("%v", load_buffers_result)
		return
	}

	_model.directory = file_get_directory_from_path(strings.clone_from_cstring(_filepath))

	for &_mesh in gltf_data.meshes {
		append(&_model.meshes, ai_process_mesh(_model, &_mesh, gltf_data))
	}

}

ai_process_mesh :: proc(_model: ^Model, _mesh: ^cg.mesh, _gltf_data: ^cg.data) -> Mesh {
	new_mesh: Mesh

	for i in 0 ..< len(_mesh.primitives) {
		append(
			&new_mesh.primitives,
			ai_process_primitives(_model, &_mesh.primitives[i], _gltf_data),
		)

	}
	return new_mesh
}

ai_process_primitives :: proc(
	_model: ^Model,
	_primitive: ^cg.primitive,
	_gltf_data: ^cg.data,
) -> Primitive {

	new_primitive: Primitive

	// PART A - VERTICES
	vertices: [dynamic]Vertex
	indices: [dynamic]u32
	textures: [dynamic]Texture

	// 1. Unpack attribute data based on attribute type
	positions_array, positions_exists := ai_unpack_attribute_f32_vec3(_primitive, .position)
	normals_array, normals_exists := ai_unpack_attribute_f32_vec3(_primitive, .normal)
	texcoords_array, texcoords_exists := ai_unpack_attribute_f32_vec2(_primitive, .texcoord)

	// Using the total number of vertex positions, construct a vertex with positions, normals and texture coordinates
	for i in 0 ..< len(positions_array) {
		vertex: Vertex
		vertex.position = positions_array[i] // position{xi, yi, zi}

		if normals_exists {
			vertex.normal = normals_array[i] // nromal{xi, yi, zi}
		} else {
			vertex.normal = {0, 1, 0} // Assuming Y is up
		}

		if texcoords_exists {
			vertex.texcoords = texcoords_array[i] // texcoord{xi, yi}
		} else {
			vertex.texcoords = {0, 0}
		}

		append(&vertices, vertex)
	}

	new_primitive.vertices = vertices

	// PART B - INDICES
	if _primitive.indices != nil {
		_indices := ai_unpack_attribute_u32(_primitive)

		for i in 0 ..< len(_indices) {
			append(&indices, _indices[i])
		}
		new_primitive.indices = indices
	}

	// PART C - TEXTURES
	if _primitive.material != nil {
		material := _primitive.material

		// Diffuse map
		if material.has_pbr_metallic_roughness {
			base_color := material.pbr_metallic_roughness.base_color_texture

			// Diffuse Map
			if base_color.texture != nil {
				texture := ai_load_texture(_model, .DIFFUSE, base_color.texture)
				append(&textures, texture)

			}
		}

		new_primitive.textures = textures
	}

	return new_primitive
}

ai_load_texture :: proc(
	_model: ^Model,
	_texture_type: TextureType,
	_gltf_texture: ^cg.texture,
) -> Texture {
	image := _gltf_texture.image_
	buffer_view := image.buffer_view
	texture: Texture
	texture.type = _texture_type

	if buffer_view != nil && buffer_view.buffer != nil && buffer_view.buffer.data != nil {
		buffer_data := ([^]u8)(buffer_view.buffer.data)
		// This handles embedded texture information of .glb files
		data_slice := buffer_data[buffer_view.offset:buffer_view.offset + buffer_view.size]

		gl.GenTextures(1, &texture.id)

		width, height, channels: i32
		desired_channels: i32 = 4 // forces (by default) RGBA

		data: [^]u8 = stbi.load_from_memory(
			raw_data(data_slice),
			i32(buffer_view.size),
			&width,
			&height,
			&channels,
			desired_channels,
		)

		if data != nil {
			format: u32
			if channels == 1 {
				format = gl.RED
			} else if channels == 3 {
				format = gl.RGB
			} else if channels == 4 {
				format = gl.RGBA
			}
			gl.BindTexture(gl.TEXTURE_2D, texture.id)
			gl.TexImage2D(
				gl.TEXTURE_2D,
				0,
				i32(format),
				width,
				height,
				0,
				format,
				gl.UNSIGNED_BYTE,
				data,
			)
			gl.GenerateMipmap(gl.TEXTURE_2D)

			gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
			gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
			gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
			gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
		} else {
			fmt.printfln("ERROR::ai_load_texture()::Failed to load texture from memory")
			fmt.println("Loading file error: %v", stbi.failure_reason())
			return {}
		}
		stbi.image_free(data)
		return texture
	} else if image.uri != nil && len(image.uri) > 0 {
		// Load from file
		uri := string(image.uri)
		// Skip data URIs for this example
		if len(uri) > 5 && uri[:5] == "data:" {
			return {}
		}

		gl.GenTextures(1, &texture.id)

		width, height, channels: i32
		desired_channels: i32 = 4
		full_path := filepath.join({_model.directory, uri}) // Handles OS-specific separators
		data: [^]u8 = stbi.load(strings.clone_to_cstring(full_path), &width, &height, &channels, 0)

		if data != nil {
			format: u32
			if channels == 1 {
				format = gl.RED
			} else if channels == 3 {
				format = gl.RGB
			} else if channels == 4 {
				format = gl.RGBA
			}
			gl.BindTexture(gl.TEXTURE_2D, texture.id)
			gl.TexImage2D(
				gl.TEXTURE_2D,
				0,
				i32(format),
				width,
				height,
				0,
				format,
				gl.UNSIGNED_BYTE,
				data,
			)
			gl.GenerateMipmap(gl.TEXTURE_2D)

			gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
			gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
			gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
			gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
		} else {
			fmt.printfln("ERROR::ai_load_texture::Failed to load texture from image.uri \n%v", image.uri)
			fmt.println("Loading file error: %v", stbi.failure_reason())
			return {}
		}
		stbi.image_free(data)
		return texture
	}
	return {}
}

ai_unpack_attribute_u32 :: proc(_primitive: ^cg.primitive) -> []u32 {
	accessor := _primitive.indices
	buffer_data := cast([^]u8)accessor.buffer_view.buffer.data
	byte_offset := accessor.offset + accessor.buffer_view.offset

	#partial switch accessor.component_type {
	case .r_16u:
		src := mem.slice_ptr(cast([^]u16)&buffer_data[byte_offset], int(accessor.count))
		indices := make([]u32, accessor.count)

		for v, i in src {
			indices[i] = u32(v)
		}
		return indices
	case .r_32u:
		return mem.slice_ptr(cast([^]u32)&buffer_data[byte_offset], int(accessor.count))
	case:
		fmt.eprintfln("ERROR::ai_unpack_attribute_u32()::Unsupported index type")
		return nil
	}
}

ai_unpack_attribute_f32_vec3 :: proc(
	_primitive: ^cg.primitive,
	_attribute_type: cg.attribute_type,
) -> (
	[][3]f32,
	bool,
) {

	// Check that the attribute exists
	attribute, exists := ai_check_attribute_exists(_primitive, _attribute_type)
	if !exists || attribute.data == nil || attribute.data.buffer_view == nil {
		return nil, false
	}

	// Access unpacked (or unprocessed) attribute data from buffer_view
	accessor := attribute.data
	buffer_view := accessor.buffer_view
	if buffer_view.buffer == nil || buffer_view.buffer.data == nil {
		return nil, false
	}

	// Cast raw_data into odin-processable data-type
	buffer_data := cast([^]u8)accessor.buffer_view.buffer.data
	byte_offset := accessor.offset + accessor.buffer_view.offset

	// Convert stream of data array into "readable" slice
	#partial switch _attribute_type {
	case .position, .normal:
		// [][3]f32 i.e. [[x1,y1,z1],[x2,y2,z2]..]
		return mem.slice_ptr(cast([^][3]f32)&buffer_data[byte_offset], int(accessor.count)), true
	}

	return nil, false
}
ai_unpack_attribute_f32_vec2 :: proc(
	_primitive: ^cg.primitive,
	_attribute_type: cg.attribute_type,
) -> (
	[][2]f32,
	bool,
) {

	// Check that the attribute exists
	attribute, exists := ai_check_attribute_exists(_primitive, _attribute_type)
	if !exists || attribute.data == nil || attribute.data.buffer_view == nil {
		return nil, false
	}

	// Access unpacked (or unprocessed) attribute data from buffer_view
	accessor := attribute.data
	buffer_view := accessor.buffer_view
	if buffer_view.buffer == nil || buffer_view.buffer.data == nil {
		return nil, false
	}

	// Cast raw_data into odin-processable data-type
	buffer_data := cast([^]u8)accessor.buffer_view.buffer.data
	byte_offset := accessor.offset + accessor.buffer_view.offset

	// Convert stream of data array into "readable" slice
	#partial switch _attribute_type {

	case .texcoord:
		// [][2]f32 i.e. [[x1,y1],[x2,y2]..]
		uvs := mem.slice_ptr(cast([^][2]f32)&buffer_data[byte_offset], int(accessor.count))

		// Flip Y to match OpenGL's bottom-left origin
		for i in 0 ..< len(uvs) {
			uvs[i].y = 1.0 - uvs[i].y
		}
		return uvs, true
	}

	return nil, false
}

ai_check_attribute_exists :: proc(
	_primitive: ^cg.primitive,
	_attribute_type: cg.attribute_type,
) -> (
	^cg.attribute,
	bool,
) {
	for i in 0 ..< len(_primitive.attributes) {
		attribute := &_primitive.attributes[i]
		if attribute.type == _attribute_type {
			return attribute, true
		}
	}
	return nil, false
}
ai_destroy_model :: proc(_model: ^Model) {
	for mesh in _model.meshes {
        for &primitive in mesh.primitives {
            // Delete GPU buffers
            gl.DeleteVertexArrays(1, &primitive.vao)
            // Note: You need to store VBO/EB0 IDs in the Primitive struct!
            gl.DeleteBuffers(1, &primitive.vbo)
            gl.DeleteBuffers(1, &primitive.ebo)
            
            // Delete textures
            for &texture in primitive.textures {
                gl.DeleteTextures(1, &texture.id)
            }
            delete(primitive.textures)
            delete(primitive.vertices)
            delete(primitive.indices)
        }
        delete(mesh.primitives)
    }
    delete(_model.meshes)
}

ai_setup_model_for_gpu :: proc(_model: ^Model) {
	for i in 0 ..< len(_model.meshes) {
		_mesh := &_model.meshes[i]

		for j in 0 ..< len(_mesh.primitives) {
			_primitive := &_mesh.primitives[j]
			ai_setup_primitive_for_gpu(_primitive)
		}
	}
}

ai_setup_primitive_for_gpu :: proc(_primitive: ^Primitive) {
	gl.GenVertexArrays(1, &_primitive.vao)
	gl.GenBuffers(1, &_primitive.vbo)
	gl.GenBuffers(1, &_primitive.ebo)

	gl.BindVertexArray(_primitive.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, _primitive.vbo)

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(_primitive.vertices) * size_of(Vertex),
		raw_data(_primitive.vertices),
		gl.STATIC_DRAW,
	)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, _primitive.ebo)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(_primitive.indices) * size_of(u32),
		raw_data(_primitive.indices),
		gl.STATIC_DRAW,
	)

	// Vertex Positions
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), cast(uintptr)0)

	// Vertex Normals
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(
		1,
		3,
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		cast(uintptr)offset_of(Vertex, normal),
	)

	// Vertex Texture Coordinates
	gl.EnableVertexAttribArray(2)
	gl.VertexAttribPointer(
		2,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		cast(uintptr)offset_of(Vertex, texcoords),
	)

	gl.BindVertexArray(0)
}


ai_draw_model :: proc(_model: ^Model, _shader: u32) {
	for &_mesh in _model.meshes {
		ai_draw_primitives(&_mesh, _shader)
	}
}

ai_draw_primitives :: proc(_mesh: ^Mesh, _shader: u32) {
	for _primitive in _mesh.primitives {
		// 1. Bind Textures
		diffuse_nr: u32 = 1 // The iterator for diffuse textures
		str_buf: [128]byte
		// Textures are "stored" per or in primitives

		for i in 0 ..< len(_primitive.textures) {
			gl.ActiveTexture(gl.TEXTURE0 + u32(i)) // Activate proper texture unit before binding

			number: u32
			texture_type := _primitive.textures[i].type
			texture_name: string
			if texture_type == .DIFFUSE {
				number = diffuse_nr
				diffuse_nr += 1
				texture_name = "diffuse"
			}

			uniform_name := strings.clone_to_cstring(
				fmt.bprint(str_buf[:], "%v%v", texture_name, number),
			)
			shader_set_int(_shader, uniform_name, i32(i))
			gl.BindTexture(gl.TEXTURE_2D, _primitive.textures[i].id)
		}
		gl.ActiveTexture(gl.TEXTURE0)


		// Draw Mesh Primitives
		gl.BindVertexArray(_primitive.vao)
		gl.DrawElements(gl.TRIANGLES, i32(len(_primitive.indices)), gl.UNSIGNED_INT, nil)
		gl.BindVertexArray(0)
	}

}

ai_delete_texture :: proc(texture: ^Texture) {
    gl.DeleteTextures(1, &texture.id)
}