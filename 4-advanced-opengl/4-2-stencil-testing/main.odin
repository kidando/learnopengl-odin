package main
/*
CHAPTER: 4-2 Stencil Testing
TUTORIAL: https://learnopengl.com/Advanced-OpenGL/Stencil-testing
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/4.advanced_opengl/2.stencil_testing/stencil_testing.cpp
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

main::proc(){
	// glfw: initialize and configure
    // ------------------------------
	if !renderer_init(){
		return
	}
	stbi.set_flip_vertically_on_load(1)
	// build and compile our shader programs
    // ------------------------------------
    // ourShader, ourShaderOk := shader_init("./shaders/depth_testing.vs","./shaders/depth_testing_visual_dbuffer.fs") // To visualize depth buffer
    shader, shaderOk := shader_init("./shaders/stencil_testing.vs","./shaders/stencil_testing.fs")
	if !shaderOk{
		return
	}
    shaderSingleColor, shaderSingleColorOk := shader_init("./shaders/stencil_testing.vs","./shaders/stencil_single_color.fs")
	if !shaderSingleColorOk{
		return
	}
	camera_init(&mainCamera,{0.0,0.0,3.0})

	// ⚠️⚠️ DEPTH  & STENCIL BUFFER SET IN renderer.odin ⚠️⚠️

	// set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    cubeVertices:[]f32 = {
        // positions       // texture Coords
        -0.5, -0.5, -0.5,  0.0, 0.0,
         0.5, -0.5, -0.5,  1.0, 0.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
        -0.5,  0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 0.0,

        -0.5, -0.5,  0.5,  0.0, 0.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 1.0,
         0.5,  0.5,  0.5,  1.0, 1.0,
        -0.5,  0.5,  0.5,  0.0, 1.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,

        -0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5,  0.5, -0.5,  1.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,
        -0.5,  0.5,  0.5,  1.0, 0.0,

         0.5,  0.5,  0.5,  1.0, 0.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5,  0.5,  0.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 0.0,

        -0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5, -0.5,  1.0, 1.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,

        -0.5,  0.5, -0.5,  0.0, 1.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5,  0.5,  0.5,  1.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5,  0.5,  0.5,  0.0, 0.0,
        -0.5,  0.5, -0.5,  0.0, 1.0
    }
    planeVertices:[]f32 = {
        // positions       // texture Coords (note we set these higher than 1 (together with GL_REPEAT as texture wrapping mode). this will cause the floor texture to repeat)
         5.0, -0.5,  5.0,  2.0, 0.0,
        -5.0, -0.5,  5.0,  0.0, 0.0,
        -5.0, -0.5, -5.0,  0.0, 2.0,

         5.0, -0.5,  5.0,  2.0, 0.0,
        -5.0, -0.5, -5.0,  0.0, 2.0,
         5.0, -0.5, -5.0,  2.0, 2.0								
    }

	// CUBE VAO
	cubeVBO, cubeVAO:u32
	gl.GenVertexArrays(1, &cubeVAO)
	gl.GenBuffers(1, &cubeVBO)
	gl.BindVertexArray(cubeVAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, cubeVBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(cubeVertices), raw_data(cubeVertices), gl.STATIC_DRAW)
	// cube position attribute
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)0)
	// cube texture coord attribute
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1,2,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)(3*size_of(f32)))
	gl.BindVertexArray(0)

	// PLANE VAO
	planeVBO, planeVAO:u32
	gl.GenVertexArrays(1, &planeVAO)
	gl.GenBuffers(1, &planeVBO)
	gl.BindVertexArray(planeVAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, planeVBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(planeVertices), raw_data(planeVertices), gl.STATIC_DRAW)
	// cube position attribute
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)0)
	// cube texture coord attribute
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1,2,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)(3*size_of(f32)))
	gl.BindVertexArray(0)

	// load textures
    // -------------
    cubeTexture:u32  = loadTexture("./assets/textures/marble.jpg")
    floorTexture:u32 = loadTexture("./assets/textures/metal.png")


	// shader configuration
    // --------------------
	gl.UseProgram(shader)
	shader_set_int(shader,"texture1",0)

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
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT) // don't forget to clear the stencil buffer!

		// set uniforms
		gl.UseProgram(shaderSingleColor)
		model:glm.mat4 = glm.mat4(1.0)
		projection:glm.mat4 = glm.mat4Perspective(
			glm.radians_f32(mainCamera.zoom),
			f32(SCR_WIDTH)/f32(SCR_HEIGHT),
			0.1,
			100
		)
		view:glm.mat4 = camera_get_view_matrix(&mainCamera)
		shader_set_mat4(shaderSingleColor,"view",&view[0][0])
		shader_set_mat4(shaderSingleColor,"projection",&projection[0][0])
	
		gl.UseProgram(shader)
		shader_set_mat4(shader,"view",&view[0][0])
		shader_set_mat4(shader,"projection",&projection[0][0])

		// draw floor as normal, but don't write the floor to the stencil buffer, we only care about the containers. We set its mask to 0x00 to not write to the stencil buffer.
		gl.StencilMask(0x00)
		// floor
		gl.BindVertexArray(planeVAO)
		gl.BindTexture(gl.TEXTURE_2D, floorTexture)
		model = glm.mat4(1.0)
		shader_set_mat4(shader,"model",&model[0][0])
		gl.DrawArrays(gl.TRIANGLES,0,6)
		gl.BindVertexArray(0)

		// 1st. render pass, draw objects as normal, writing to the stencil buffer
        // --------------------------------------------------------------------
		gl.StencilFunc(gl.ALWAYS, 1, 0xFF)
		gl.StencilMask(0xFF)
		// Cubes
		gl.BindVertexArray(cubeVAO)
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, cubeTexture)
		model = glm.mat4Translate({-1.0,0.0,-1.0})
		shader_set_mat4(shader,"model",&model[0][0])
		gl.DrawArrays(gl.TRIANGLES,0,36)
		model = glm.mat4(1.0)
		model = glm.mat4Translate({2.0,0.0,0.0})
		shader_set_mat4(shader,"model",&model[0][0])
		gl.DrawArrays(gl.TRIANGLES,0,36)

		// 2nd. render pass: now draw slightly scaled versions of the objects, this time disabling stencil writing.
        // Because the stencil buffer is now filled with several 1s. The parts of the buffer that are 1 are not drawn, thus only drawing 
        // the objects' size differences, making it look like borders.
        // -----------------------------------------------------------------------------------------------------------------------------
		gl.StencilFunc(gl.NOTEQUAL, 1, 0xFF)
		gl.StencilMask(0x00)
		gl.Disable(gl.DEPTH_TEST)
		gl.UseProgram(shaderSingleColor)
		shader_set_mat4(shaderSingleColor,"view",&view[0][0])
		shader_set_mat4(shaderSingleColor,"projection",&projection[0][0])
		scale:f32 = 1.1
		// Cubes
		gl.BindVertexArray(cubeVAO)
        gl.BindTexture(gl.TEXTURE_2D, cubeTexture)
		model = glm.mat4(1.0)
		model = glm.mat4Translate({-1.0,0.0,-1.0})
		model *= glm.mat4Scale({scale,scale,scale})
		shader_set_mat4(shaderSingleColor,"model",&model[0][0])
		gl.DrawArrays(gl.TRIANGLES,0,36)
		model = glm.mat4(1.0)
		model = glm.mat4Translate({2.0,0.0,0.0})
		model *= glm.mat4Scale({scale,scale,scale})
		shader_set_mat4(shaderSingleColor,"model",&model[0][0])
		gl.DrawArrays(gl.TRIANGLES,0,36)
		gl.BindVertexArray(0)
		gl.StencilMask(0xFF)
		gl.StencilFunc(gl.ALWAYS,0,0xFF)
		gl.Enable(gl.DEPTH_TEST)
		
		
		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
	// optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------

	gl.DeleteVertexArrays(1, &cubeVAO)
    gl.DeleteVertexArrays(1, &planeVAO)
    gl.DeleteBuffers(1, &cubeVBO)
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