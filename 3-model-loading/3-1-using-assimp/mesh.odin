/**
Generic OpenGL Mesh "definition"
**/
package main

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:strings"
import gl "vendor:OpenGL"

MAX_BONE_INFLUENCE :: 4

Vertex :: struct {
	position:       glm.vec3,
	normal:         glm.vec3,
	tex_coords:     glm.vec2,
	tangent:        glm.vec3,
	bitangent:      glm.vec3,
	m_bone_ids:     [MAX_BONE_INFLUENCE]i32,
	m_bone_weights: [MAX_BONE_INFLUENCE]f32,
}

Texture :: struct {
	id:   u32,
	type: string,
	path: string,
}

Mesh :: struct {
	vertices: [dynamic]Vertex,
	indices:  [dynamic]u32,
	textures: [dynamic]Texture,
	vao:      u32,
}

mesh_construct :: proc(
	_mesh: ^Mesh,
	_vertices: [dynamic]Vertex,
	_indices: [dynamic]u32,
	_textures: [dynamic]Texture,
) {
	_mesh.vertices = _vertices
	_mesh.indices = _indices
	_mesh.textures = _textures
	//fmt.printfln("mesh_construct()")
	mesh_setup(_mesh)
}

// Defer call this immediately after calling mesh create
mesh_destroy :: proc(_mesh: ^Mesh) {
	delete(_mesh.vertices)
	delete(_mesh.indices)
	delete(_mesh.textures)
	//fmt.printfln("mesh_destroy()")
}

mesh_setup :: proc(_mesh: ^Mesh) {
	VBO, EBO: u32
	gl.GenVertexArrays(1, &_mesh.vao)
	gl.GenBuffers(1, &VBO)
	gl.GenBuffers(1, &EBO)

	gl.BindVertexArray(_mesh.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(_mesh.vertices) * size_of(Vertex),
		raw_data(_mesh.vertices),
		gl.STATIC_DRAW,
	)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(_mesh.indices) * size_of(u32),
		raw_data(_mesh.indices),
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
		cast(uintptr)offset_of(Vertex, tex_coords),
	)

	// Vertex Tangent
	gl.EnableVertexAttribArray(3)
	gl.VertexAttribPointer(
		3,
		3,
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		cast(uintptr)offset_of(Vertex, tangent),
	)

	// Vertex Bitangent
	gl.EnableVertexAttribArray(4)
	gl.VertexAttribPointer(
		4,
		3,
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		cast(uintptr)offset_of(Vertex, bitangent),
	)

	// Bone IDs
	gl.EnableVertexAttribArray(5)
	gl.VertexAttribPointer(
		5,
		MAX_BONE_INFLUENCE,
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		cast(uintptr)offset_of(Vertex, m_bone_ids),
	)

	// Bone Weights
	gl.EnableVertexAttribArray(6)
	gl.VertexAttribPointer(
		6,
		MAX_BONE_INFLUENCE,
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		cast(uintptr)offset_of(Vertex, m_bone_weights),
	)

	gl.BindVertexArray(0)
	//fmt.printfln("mesh_setup()")
}

mesh_draw :: proc(_mesh: ^Mesh, _shader: u32) {


	diffuse_unit: u32 = 0
	specular_unit: u32 = 1 // Start after diffuse
	normal_unit: u32 = 2
	height_unit: u32 = 3

	buf: [256]byte // Reusable buffer
	for i: int; i < len(_mesh.textures); i += 1 {
		texture_unit: u32
		name: string = _mesh.textures[i].type

		if name == "texture_diffuse" {
			texture_unit = diffuse_unit
			diffuse_unit += 1
			name = "texture_diffuse"
		} else if name == "texture_specular" {
			texture_unit = specular_unit
			specular_unit += 1
			name = "texture_specular"
		} else if name == "texture_normal" {
			texture_unit = normal_unit
			normal_unit += 1
			name = "texture_normal"
		} else if name == "texture_height" {
			texture_unit = height_unit
			height_unit += 1
			name = "texture_height"
		}

		gl.ActiveTexture(gl.TEXTURE0 + texture_unit)
		gl.BindTexture(gl.TEXTURE_2D, _mesh.textures[i].id)
		shader_set_int(_shader, cstring(raw_data(name)), i32(texture_unit))
	}

	// draw mesh
	gl.BindVertexArray(_mesh.vao)
	gl.DrawElements(gl.TRIANGLES, i32(len(_mesh.indices)), gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)

	gl.ActiveTexture(gl.TEXTURE0)


	//fmt.printfln("mesh_draw()")
}
