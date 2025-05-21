package main
/*
CHAPTER: 5-2 Gamma Correction
TUTORIAL: https://learnopengl.com/Advanced-Lighting/Advanced-Lighting
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/5.advanced_lighting/2.gamma_correction/gamma_correction.cpp
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

gammaEnabled:i32 = 0
gammaKeyPressed:bool = false


main::proc(){
	// glfw: initialize and configure
    // ------------------------------
	if !renderer_init(){
		return
	}
	stbi.set_flip_vertically_on_load(1)
	// build and compile our shader programs
    // ------------------------------------
    shader, shaderOk := shader_init("./shaders/gamma_correction.vs","./shaders/gamma_correction.fs")
	if !shaderOk{
		return
	}
	camera_init(&mainCamera,{0.0,0.0,3.0})

	// set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    planeVertices:[]f32 = {
        // positions         // normals      // texcoords
         10.0, -0.5,  10.0,  0.0, 1.0, 0.0,  10.0,  0.0,
        -10.0, -0.5,  10.0,  0.0, 1.0, 0.0,   0.0,  0.0,
        -10.0, -0.5, -10.0,  0.0, 1.0, 0.0,   0.0, 10.0,

         10.0, -0.5,  10.0,  0.0, 1.0, 0.0,  10.0,  0.0,
        -10.0, -0.5, -10.0,  0.0, 1.0, 0.0,   0.0, 10.0,
         10.0, -0.5, -10.0,  0.0, 1.0, 0.0,  10.0, 10.0
    }

	// Plane VAO
	planeVBO, planeVAO:u32
	gl.GenVertexArrays(1, &planeVAO)
	gl.GenBuffers(1, &planeVBO)
	gl.BindVertexArray(planeVAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, planeVBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(planeVertices), raw_data(planeVertices), gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,8 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1,3,gl.FLOAT, gl.FALSE,8 * size_of(f32), cast(uintptr)(3*size_of(f32)))
	gl.EnableVertexAttribArray(2)
	gl.VertexAttribPointer(2,2,gl.FLOAT, gl.FALSE,8 * size_of(f32), cast(uintptr)(6*size_of(f32)))
	gl.BindVertexArray(0)

	// load textures
    // -------------
    floorTexture:u32 = loadTexture("./assets/textures/wood.png")
    floorTextureGammaCorrected:u32 = loadTexture("./assets/textures/wood.png")


	// shader configuration
    // --------------------
	gl.UseProgram(shader)
	shader_set_int(shader,"texture1",0)

	// lighting info
    // -------------
	lightPositions:[]glm.vec3 = {
		{-3.0,0.0,0.0},
		{-1.0,0.0,0.0},
		{1.0,0.0,0.0},
		{3.0,0.0,0.0},
	}

	lightColors:[]glm.vec3 = {
		glm.vec3(0.25),
		glm.vec3(0.50),
		glm.vec3(0.75),
		glm.vec3(1.00),
	}

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

		// draw objects
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

		// set light uniforms
		gl.Uniform3fv(gl.GetUniformLocation(shader,"lightPositions"),4,&lightPositions[0][0])
		gl.Uniform3fv(gl.GetUniformLocation(shader,"lightColors"),4,&lightColors[0][0])
		shader_set_vec3_vec(shader,"viewPos",&mainCamera.position[0])
		shader_set_int(shader, "gamma",gammaEnabled)
		
		// Floor
		gl.BindVertexArray(planeVAO)
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, gammaEnabled == 1? floorTextureGammaCorrected : floorTexture)
        gl.DrawArrays(gl.TRIANGLES, 0, 6)
		
		if gammaEnabled == 1{
			fmt.printfln("Gamma Enabled")
		}else{
			fmt.printfln("Gamma Disabled")
		}
		
		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
	// optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------

    gl.DeleteVertexArrays(1, &planeVAO)
    gl.DeleteBuffers(1, &planeVBO)

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
	if glfw.GetKey(window, glfw.KEY_SPACE) == glfw.PRESS && !gammaKeyPressed{
		if gammaEnabled == 0{
			gammaEnabled = 1
		}else{
			gammaEnabled = 0
		}
		gammaKeyPressed = true
	}

	if glfw.GetKey(window,glfw.KEY_SPACE) == glfw.RELEASE{
		gammaKeyPressed = false
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