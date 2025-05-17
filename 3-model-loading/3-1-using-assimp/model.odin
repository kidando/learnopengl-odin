package main

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:strings"
import ai "shared:odin-assimp"
import gl "vendor:OpenGL"
import stbi "vendor:stb/image"

// assimp post processing flags
aiCalcTangentSpace :: 0x1
aiJoinIdenticalVertices :: 0x2
aiMakeLeftHanded :: 0x4
aiTriangulate :: 0x8
aiRemoveComponent :: 0x10
aiGenNormals :: 0x20
aiGenSmoothNormals :: 0x40
aiSplitLargeMeshes :: 0x80
aiPreTransformVertices :: 0x100
aiLimitBoneWeights :: 0x200
aiValidateDataStructure :: 0x400
aiImproveCacheLocality :: 0x800
aiRemoveRedundantMaterials :: 0x1000
aiFixInfacingNormals :: 0x2000
aiSortByPType :: 0x8000
aiFindDegenerates :: 0x10000
aiFindInvalidData :: 0x20000
aiGenUVCoords :: 0x40000
aiTransformUVCoords :: 0x80000
aiFindInstances :: 0x100000
aiOptimizeMeshes :: 0x200000
aiOptimizeGraph :: 0x400000
aiFlipUVs :: 0x800000
aiFlipWindingOrder :: 0x1000000

// assimp Scene Flags
AI_SCENE_FLAGS_INCOMPLETE :: 0x1
AI_SCENE_FLAGS_VALIDATED :: 0x2
AI_SCENE_FLAGS_VALIDATION_WARNING :: 0x4
AI_SCENE_FLAGS_NON_VERBOSE_FORMAT :: 0x8
AI_SCENE_FLAGS_FLAGS_TERRAIN :: 0x10

Model :: struct {
	textures_loaded:  [dynamic]Texture, // stores all the textures loaded so far, optimization to make sure textures aren't loaded more than once.
	meshes:           [dynamic]Mesh,
	directory:        string,
	gamma_correction: bool,
}

// Free allocated memory. NOTE: Run defer mode_destroy(model) right after creating model
model_destroy :: proc(_model: ^Model) {
	delete(_model.meshes)
	delete(_model.textures_loaded)
	fmt.printfln("model_destroy()")
}

// draws the model, and thus all its meshes
model_draw :: proc(_model: ^Model, _shader: u32) {
	//fmt.printfln("begin model_draw()")
	for i: int; i < len(_model.meshes); i += 1 {
		
		mesh_draw(&_model.meshes[i], _shader)
	}
	//fmt.printfln("end model_draw()")
}

// loads a model with supported ASSIMP extensions from file and stores the resulting meshes in the meshes vector.
model_load :: proc(_model: ^Model, _path: string) {
	//fmt.printfln("begin model_load()")
	// Read file via ASSIMP
	scene: ^ai.Scene = ai.import_file_from_file(
		_path,
		aiTriangulate | aiFlipUVs | aiGenSmoothNormals | aiCalcTangentSpace,
	)

	// check for errors
	if scene == nil {
		fmt.printfln("ERROR::MODEL_LOAD::%v", ai.get_error_string())
		return
	}
	if (scene.mFlags & AI_SCENE_FLAGS_INCOMPLETE) != 0 {
		fmt.printfln("ERROR::MODEL_LOAD::Incomplete scene loaded")
		return
	}
	if scene.mRootNode == nil {
		fmt.printfln("ERROR::MODEL_LOAD::No root node found")
		return
	}

	// retrieve the directory path of the filepath
	_model.directory = file_get_directory_from_path(_path)

	// process ASSIMP's root node recursively
	model_process_node(_model, scene.mRootNode, scene)

	//fmt.printfln("end model_load()")
}

// processes a node in a recursive fashion. Processes each individual mesh located at the node and repeats this process on its children nodes (if any).
model_process_node :: proc(_model: ^Model, _node: ^ai.Node, _scene: ^ai.Scene) {
	//fmt.printfln("begin model_process_node()")

	// process each mesh located at the current node
	for i: u32; i < _node.mNumMeshes; i += 1 {
		// the node object only contains indices to index the actual objects in the scene. 
		// the scene contains all the data, node is just to keep stuff organized (like relations between nodes).
		mesh: ^ai.Mesh = _scene.mMeshes[_node.mMeshes[i]]
		append(&_model.meshes, model_process_mesh(_model, mesh, _scene))
	}

	// after we've processed all of the meshes (if any) we then recursively process each of the children nodes
	for i: u32; i < _node.mNumChildren; i += 1 {
		model_process_node(_model, _node.mChildren[i], _scene)
	}

	//fmt.printfln("end model_process_node()")
}

model_process_mesh :: proc(_model:^Model, _mesh: ^ai.Mesh, _scene: ^ai.Scene) -> Mesh {
	_final_mesh: Mesh
	vertices: [dynamic]Vertex
	indices: [dynamic]u32
	textures: [dynamic]Texture
	defer delete(vertices)
	defer delete(indices)
	defer delete(textures)

	// walk through each of the mesh's vertices
	for i: u32; i < _mesh.mNumVertices; i += 1 {
		vertex: Vertex
		vector: glm.vec3 // we declare a placeholder vector since assimp uses its own vector class that doesn't directly convert to glm's vec3 class so we transfer the data to this placeholder glm::vec3 first.

		// Positions
		vector.x = _mesh.mVertices[i].x
		vector.y = _mesh.mVertices[i].y
		vector.z = _mesh.mVertices[i].z
		vertex.position = vector

		// Normals
		if _mesh.mNormals != nil {
			vector.x = _mesh.mNormals[i].x
			vector.y = _mesh.mNormals[i].y
			vector.z = _mesh.mNormals[i].z
			vertex.normal = vector
		}

		// Texture Coordinates
		if _mesh.mTextureCoords[0] != nil {
			vec: glm.vec2
			// a vertex can contain up to 8 different texture coordinates. We thus make the assumption that we won't 
			// use models where a vertex can have multiple texture coordinates so we always take the first set (0).
			vec.x = _mesh.mTextureCoords[0][i].x
			vec.y = _mesh.mTextureCoords[0][i].y
			vertex.tex_coords = vec

			// Tangent
			vector.x = _mesh.mTangents[i].x
			vector.y = _mesh.mTangents[i].y
			vector.z = _mesh.mTangents[i].z
			vertex.tangent = vector

			// Bitangent
			vector.x = _mesh.mBitangents[i].x
			vector.y = _mesh.mBitangents[i].y
			vector.z = _mesh.mBitangents[i].z
			vertex.bitangent = vector
		} else {
			vertex.tex_coords = {0, 0}
		}
		append(&vertices, vertex)
	}

	// now wak through each of the mesh's faces (a face is a mesh its triangle) and retrieve the corresponding vertex indices.
	for i: u32; i < _mesh.mNumFaces; i += 1 {
		face: ai.Face = _mesh.mFaces[i]
		// retrieve all indices of the face and store them in the indices vector
		for j: u32; j < face.mNumIndices; j += 1 {
			append(&indices, face.mIndices[j])
		}
	}

	// process materials
	material: ^ai.Material = _scene.mMaterials[_mesh.mMaterialIndex]
	// we assume a convention for sampler names in the shaders. Each diffuse texture should be named
	// as 'texture_diffuseN' where N is a sequential number ranging from 1 to MAX_SAMPLER_NUMBER. 
	// Same applies to other texture as the following list summarizes:
	// diffuse: texture_diffuseN
	// specular: texture_specularN
	// normal: texture_normalN

	// 1. diffuse maps
	diffuse_maps: [dynamic]Texture = model_load_material_textures(
		_model,
		material,	
		.DIFFUSE,
		"texture_diffuse",
	)
	defer delete(diffuse_maps)
	append(&textures, ..diffuse_maps[:])

	// 2. specular maps
	specular_maps: [dynamic]Texture = model_load_material_textures(
		_model,
		material,	
		.SPECULAR,
		"texture_specular",
	)
	defer delete(specular_maps)
	append(&textures, ..specular_maps[:])

	// 3. normal maps
	normal_maps: [dynamic]Texture = model_load_material_textures(
		_model,
		material,	
		.HEIGHT,
		"texture_normal",
	)
	defer delete(normal_maps)
	append(&textures, ..normal_maps[:])

	// 4. height maps
	height_maps: [dynamic]Texture = model_load_material_textures(
		_model,
		material,	
		.AMBIENT,
		"texture_height",
	)
	defer delete(height_maps)
	append(&textures, ..height_maps[:])

	mesh_construct(&_final_mesh,vertices,indices,textures)

	return _final_mesh
}

model_load_material_textures :: proc(
	_model: ^Model,
	_material: ^ai.Material,
	_type: ai.TextureType,
	_type_name: string,
) -> [dynamic]Texture {
	_textures: [dynamic]Texture
	defer delete(_textures)

	for i: u32; i < ai.get_material_textureCount(_material, _type); i += 1 {
		str: ai.String
		mapping: ai.TextureMapping
		uv_index: u32
		blend: f64
		op: ai.TextureOp
		map_mode: ai.TextureMapMode

		ai.get_material_texture(
			_material,
			_type,
			i,
			&str,
			&mapping,
			&uv_index,
			&blend,
			&op,
			&map_mode,
		)
		// check if texture was loaded before and if so, continue to next iteration: skip loading a new texture

		skip: bool = false
		for j: int; j < len(_model.textures_loaded); j += 1 {
			if _model.textures_loaded[j].path == assimp_string_to_odin_string(&str) {
				append(&_textures, _model.textures_loaded[j])
				skip = true // a texture with the same filepath has already been loaded, continue to next one. (optimization)
				break
			}
		}

		if !skip {
			// if texture hasn't been loaded already, load it
			texture: Texture
			texture.id = model_texture_from_file(
				assimp_string_to_odin_string(&str),
				_model.directory,
			)
		}
	}
	return _textures
}

model_texture_from_file :: proc(_path: string, _directory: string) -> u32 {

	filename: string = strings.concatenate([]string{_directory, "/", _path})
	c_str := strings.clone_to_cstring(filename)
	defer delete(c_str) // Remember to free the memory when done

	_texture_id: u32
	gl.GenTextures(1, &_texture_id)

	width, height, nr_components: i32
	data: [^]u8 = stbi.load(cstring(raw_data(filename)), &width, &height, &nr_components, 0)

	if data != nil {
		format: u32
		if nr_components == 1 {
			format = gl.RED
		} else if nr_components == 3 {
			format = gl.RGB
		} else if nr_components == 4 {
			format = gl.RGBA
		}
		gl.BindTexture(gl.TEXTURE_2D, _texture_id)
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
		fmt.printfln("Failed to load texture: \n%v", filename)
		fmt.println("Loading file error: %v", stbi.failure_reason())
	}
	stbi.image_free(data)
	return _texture_id
}
