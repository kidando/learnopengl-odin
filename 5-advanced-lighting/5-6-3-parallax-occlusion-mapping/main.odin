package main
/*
CHAPTER: 5-6-3 Parallax Occlusion Mapping
TUTORIAL: https://learnopengl.com/Advanced-Lighting/Parallax-Mapping
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/5.advanced_lighting/5.3.parallax_occlusion_mapping/parallax_occlusion_mapping.cpp
*/

import "core:fmt"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import "core:math"
import "core:os" 
import stbi "vendor:stb/image" 
import glm "core:math/linalg/glsl"

// settings
SCR_WIDTH:i32:800
SCR_HEIGHT:i32:600

OPENGL_MAJOR_VERSION::3
OPENGL_MINOR_VERSION::3

window: glfw.WindowHandle
mainCamera:Camera

firstMouse:bool = true
lastX:f32 = f32(SCR_WIDTH)/2.0
lastY:f32 = f32(SCR_HEIGHT)/2.0

deltaTime:f32 = 0.0 // time between current frame and last frame
lastFrame:f32 = 0.0

heightScale:f32 = 0.1


main::proc(){
	// glfw: initialize and configure
    // ------------------------------
	if !renderer_init(){
		return
	}
	stbi.set_flip_vertically_on_load(1)
	// build and compile our shader programs
    // ------------------------------------
    // shader, shaderOk := shader_init("./shaders/depth_testing.vs","./shaders/depth_testing_visual_dbuffer.fs") // To visualize depth buffer
    shader, shaderOk := shader_init("./shaders/parallax_mapping.vs","./shaders/parallax_mapping.fs")
	if !shaderOk{
		return
	}
	camera_init(&mainCamera,{0.0,0.0,3.0})


	

	// load textures
    // -------------
    diffuseMap:u32  = loadTexture("./assets/textures/wood.png")
    normalMap:u32 = loadTexture("./assets/textures/toy_box_normal.png")
    heightMap:u32 = loadTexture("./assets/textures/toy_box_disp.png")


	// shader configuration
    // --------------------
	gl.UseProgram(shader)
	shader_set_int(shader,"diffuseMap",0)
	shader_set_int(shader,"normalMap",1)
	shader_set_int(shader,"depthMap",2)

	// lighting info
    // --------------------
	lightPos:glm.vec3 = {0.5,1.0,0.3}

	// render loop
    // -----------
	for !glfw.WindowShouldClose(window){
		// per-frame time logic
        // --------------------
		currentFrame:f32 = f32(glfw.GetTime())
		deltaTime = currentFrame - lastFrame
		lastFrame = currentFrame

		// input
        // -----
		processInput(window)

		// render
        // ------
        gl.ClearColor(0.1, 0.1, 0.1, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		// be sure to activate shader when setting uniforms/drawing objects
		gl.UseProgram(shader)

		// view/projection transformations
		projection:glm.mat4 = glm.mat4Perspective(
			glm.radians_f32(mainCamera.zoom),
			f32(SCR_WIDTH)/f32(SCR_HEIGHT),
			0.1,
			100
		)
		view:glm.mat4 = camera_get_view_matrix(&mainCamera)
		shader_set_mat4(shader,"projection",&projection[0][0])
		shader_set_mat4(shader,"view",&view[0][0])

		// render parallax-mapped quad
		model:glm.mat4 = glm.mat4(1.0)
		model = glm.mat4Rotate(
			glm.normalize_vec3({1.0,0.0,1.0}),
			glm.radians_f32(f32(glfw.GetTime()*-10.0))
		)
		shader_set_mat4(shader,"model",&model[0][0])
		shader_set_vec3_vec(shader,"viewPos",&mainCamera.position[0])
		shader_set_vec3_vec(shader,"lightPos",&lightPos[0])
		shader_set_float(shader,"heightScale",heightScale) // adjust with Q and E keys
		fmt.printfln("heightScale: %v", heightScale)
		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, diffuseMap)
		gl.ActiveTexture(gl.TEXTURE1)
		gl.BindTexture(gl.TEXTURE_2D, normalMap)
		gl.ActiveTexture(gl.TEXTURE2)
		gl.BindTexture(gl.TEXTURE_2D, heightMap)
		renderQuad()

		 // render light source (simply re-renders a smaller plane at the light's position for debugging/visualization)
        model = glm.mat4(1.0)
		model = glm.mat4Translate(lightPos)
		model += glm.mat4Scale(glm.vec3(0.1))
		shader_set_mat4(shader,"model",&model[0][0])
		renderQuad()


	

		
		
		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
	// optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------



	// glfw: terminate, clearing all previously allocated GLFW resources.
    // ------------------------------------------------------------------
	glfw.Terminate()

}

// glfw: whenever the window size changed (by OS or user resize) this callback function executes
// ---------------------------------------------------------------------------------------------
framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
}

// process all input: query GLFW whether relevant keys are pressed/released this frame and react accordingly
// ---------------------------------------------------------------------------------------------------------
processInput::proc "c"(window:glfw.WindowHandle){
	if glfw.GetKey(window, glfw.KEY_ESCAPE)==glfw.PRESS{
		glfw.SetWindowShouldClose(window, true)
	}

	if glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS{
		camera_process_keyboard(&mainCamera, .FORWARD, deltaTime)
	}
	if glfw.GetKey(window, glfw.KEY_S) == glfw.PRESS{
		camera_process_keyboard(&mainCamera, .BACKWARD, deltaTime)
	}
	if glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS{
		camera_process_keyboard(&mainCamera, .LEFT, deltaTime)
	}
	if glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS{
		camera_process_keyboard(&mainCamera, .RIGHT, deltaTime)
	}

	if glfw.GetKey(window, glfw.KEY_Q) == glfw.PRESS{
		if heightScale > 0.0{
			heightScale -= 0.0005
		}else{
			heightScale = 0
		}
	}else if glfw.GetKey(window, glfw.KEY_E) == glfw.PRESS{
		if heightScale < 1.0{
			heightScale += 0.0005
		}else{
			heightScale = 1.0
		}
	}
}
// glfw: whenever the mouse moves, this callback is called
// -------------------------------------------------------
mouse_callback::proc "c" (window:glfw.WindowHandle, xposIn:f64, yposIn:f64){
	xpos:f32 = f32(xposIn)
	ypos:f32 = f32(yposIn)

	if firstMouse{
		lastX = xpos
		lastY = ypos
		firstMouse = false
	}

	xoffset:f32 = xpos - lastX
	yoffset:f32 = lastY - ypos // Reversed since y-cordinates go from bottom to top
	lastX = xpos
	lastY = ypos

	camera_process_mouse_movement(&mainCamera, xoffset, yoffset)
	
}
// glfw: whenever the mouse scroll wheel scrolls, this callback is called
// ----------------------------------------------------------------------
scroll_callback::proc "c" (window:glfw.WindowHandle, xoffset:f64, yoffset:f64){
	camera_process_mouse_scroll(&mainCamera, f32(yoffset))
}

loadTexture::proc(_filepath:cstring)->u32{
	_texture_id:u32
	gl.GenTextures(1, &_texture_id)

	width, height, nr_components: i32
	data: [^]u8 = stbi.load(_filepath, &width, &height, &nr_components, 0)

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
		fmt.printfln("Failed to load texture: \n%v", _filepath)
		fmt.println("Loading file error: %v", stbi.failure_reason())
	}
	stbi.image_free(data)
	return _texture_id
}

quadVAO, quadVBO:u32
renderQuad::proc(){
	if quadVAO == 0{
		// positions
		pos1:glm.vec3 = {-1.0, 1.0, 0.0}
		pos2:glm.vec3 = {-1.0, -1.0, 0.0}
		pos3:glm.vec3 = {1.0, -1.0, 0.0}
		pos4:glm.vec3 = {1.0, 1.0, 0.0}

		// texture coordinates
		uv1:glm.vec2 = {0.0, 1.0}
		uv2:glm.vec2 = {0.0, 0.0}
		uv3:glm.vec2 = {1.0, 0.0}
		uv4:glm.vec2 = {1.0, 1.0}

		// normal vector
		nm:glm.vec3 = {0.0,0.0,1.0}

		// calculate tangent/bitangent vectors of both triangles
		tangent1, tangent2, bitangent1, bitangent2 : glm.vec3

		// triangle 1
		//-------------
		edge1:glm.vec3 = pos2 - pos1
		edge2:glm.vec3 = pos3 - pos1
		deltaUV1:glm.vec2 = uv2 - uv1
		deltaUV2:glm.vec2 = uv3 - uv1

		f:f32 = 1.0/(deltaUV1.x * deltaUV2.y - deltaUV2.x * deltaUV1.y)

		tangent1.x = f * (deltaUV2.y * edge1.x - deltaUV1.y * edge2.x)
		tangent1.y = f * (deltaUV2.y * edge1.y - deltaUV1.y * edge2.y)
		tangent1.z = f * (deltaUV2.y * edge1.z - deltaUV1.y * edge2.z)

		bitangent1.x = f * (-deltaUV2.x * edge1.x + deltaUV1.x * edge2.x)
        bitangent1.y = f * (-deltaUV2.x * edge1.y + deltaUV1.x * edge2.y)
        bitangent1.z = f * (-deltaUV2.x * edge1.z + deltaUV1.x * edge2.z)


		// triangle 2
        // ----------
        edge1 = pos3 - pos1;
        edge2 = pos4 - pos1;
        deltaUV1 = uv3 - uv1;
        deltaUV2 = uv4 - uv1;

        f = 1.0 / (deltaUV1.x * deltaUV2.y - deltaUV2.x * deltaUV1.y)

        tangent2.x = f * (deltaUV2.y * edge1.x - deltaUV1.y * edge2.x)
        tangent2.y = f * (deltaUV2.y * edge1.y - deltaUV1.y * edge2.y)
        tangent2.z = f * (deltaUV2.y * edge1.z - deltaUV1.y * edge2.z)


        bitangent2.x = f * (-deltaUV2.x * edge1.x + deltaUV1.x * edge2.x)
        bitangent2.y = f * (-deltaUV2.x * edge1.y + deltaUV1.x * edge2.y)
        bitangent2.z = f * (-deltaUV2.x * edge1.z + deltaUV1.x * edge2.z)

		quadVertices:[]f32 = {
            // positions            // normal         // texcoords  // tangent                          // bitangent
            pos1.x, pos1.y, pos1.z, nm.x, nm.y, nm.z, uv1.x, uv1.y, tangent1.x, tangent1.y, tangent1.z, bitangent1.x, bitangent1.y, bitangent1.z,
            pos2.x, pos2.y, pos2.z, nm.x, nm.y, nm.z, uv2.x, uv2.y, tangent1.x, tangent1.y, tangent1.z, bitangent1.x, bitangent1.y, bitangent1.z,
            pos3.x, pos3.y, pos3.z, nm.x, nm.y, nm.z, uv3.x, uv3.y, tangent1.x, tangent1.y, tangent1.z, bitangent1.x, bitangent1.y, bitangent1.z,

            pos1.x, pos1.y, pos1.z, nm.x, nm.y, nm.z, uv1.x, uv1.y, tangent2.x, tangent2.y, tangent2.z, bitangent2.x, bitangent2.y, bitangent2.z,
            pos3.x, pos3.y, pos3.z, nm.x, nm.y, nm.z, uv3.x, uv3.y, tangent2.x, tangent2.y, tangent2.z, bitangent2.x, bitangent2.y, bitangent2.z,
            pos4.x, pos4.y, pos4.z, nm.x, nm.y, nm.z, uv4.x, uv4.y, tangent2.x, tangent2.y, tangent2.z, bitangent2.x, bitangent2.y, bitangent2.z
        }
        // configure plane VAO
        gl.GenVertexArrays(1, &quadVAO)
        gl.GenBuffers(1, &quadVBO)
        gl.BindVertexArray(quadVAO)
        gl.BindBuffer(gl.ARRAY_BUFFER, quadVBO)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(f32) * len(quadVertices), raw_data(quadVertices), gl.STATIC_DRAW)
        gl.EnableVertexAttribArray(0);
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 14 * size_of(f32), cast(uintptr)0)
        gl.EnableVertexAttribArray(1)
        gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 14 * size_of(f32), cast(uintptr)(3 * size_of(f32)))
        gl.EnableVertexAttribArray(2)
        gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 14 * size_of(f32), cast(uintptr)(6 * size_of(f32)))
        gl.EnableVertexAttribArray(3)
        gl.VertexAttribPointer(3, 3, gl.FLOAT, gl.FALSE, 14 * size_of(f32), cast(uintptr)(8 * size_of(f32)))
        gl.EnableVertexAttribArray(4)
        gl.VertexAttribPointer(4, 3, gl.FLOAT, gl.FALSE, 14 * size_of(f32), cast(uintptr)(11 * size_of(f32)))
	}
	 gl.BindVertexArray(quadVAO)
    gl.DrawArrays(gl.TRIANGLES, 0, 6)
    gl.BindVertexArray(0)
}