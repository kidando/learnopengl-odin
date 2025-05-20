package main
/*
CHAPTER: 4-4 Framebuffers
TUTORIAL: https://learnopengl.com/Advanced-OpenGL/Framebuffers
SOURCE CODE IN C++: https://github.com/Hengle/LearnOpenGL-1/blob/master/src/4.advanced_opengl/5.1.framebuffers/framebuffers.cpp
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

    shader, shaderOk := shader_init("./shaders/framebuffers.vs","./shaders/framebuffers.fs")
	if !shaderOk{
		return
	}
    screenShader, screenShaderOk := shader_init("./shaders/framebuffers_screen.vs","./shaders/framebuffers_screen.fs")
	if !screenShaderOk{
		return
	}
	camera_init(&mainCamera,{0.0,0.0,3.0})

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
        // positions       // texture Coords
         5.0, -0.5,  5.0,  2.0, 0.0,
        -5.0, -0.5,  5.0,  0.0, 0.0,
        -5.0, -0.5, -5.0,  0.0, 2.0,

         5.0, -0.5,  5.0,  2.0, 0.0,
        -5.0, -0.5, -5.0,  0.0, 2.0,
         5.0, -0.5, -5.0,  2.0, 2.0								
    }
	quadVertices:[]f32 = { // vertex attributes for a quad that fills the entire screen in Normalized Device Coordinates.
        // positions   // texCoords
        -1.0,  1.0,  0.0, 1.0,
        -1.0, -1.0,  0.0, 0.0,
         1.0, -1.0,  1.0, 0.0,

        -1.0,  1.0,  0.0, 1.0,
         1.0, -1.0,  1.0, 0.0,
         1.0,  1.0,  1.0, 1.0
    };

	// CUBE VAO
	cubeVBO, cubeVAO:u32
	gl.GenVertexArrays(1, &cubeVAO)
	gl.GenBuffers(1, &cubeVBO)
	gl.BindVertexArray(cubeVAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, cubeVBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(cubeVertices), raw_data(cubeVertices), gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1,2,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)(3*size_of(f32)))

	// PLANE VAO
	planeVBO, planeVAO:u32
	gl.GenVertexArrays(1, &planeVAO)
	gl.GenBuffers(1, &planeVBO)
	gl.BindVertexArray(planeVAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, planeVBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(planeVertices), raw_data(planeVertices), gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1,2,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)(3*size_of(f32)))

	// SCREEN QUAD VAO
	quadVBO, quadVAO:u32
	gl.GenVertexArrays(1, &quadVAO)
	gl.GenBuffers(1, &quadVBO)
	gl.BindVertexArray(quadVAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, quadVBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(quadVertices), raw_data(quadVertices), gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0,2,gl.FLOAT, gl.FALSE,4 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1,2,gl.FLOAT, gl.FALSE,4 * size_of(f32), cast(uintptr)(2*size_of(f32)))

	// load textures
    // -------------
    cubeTexture:u32  = loadTexture("./assets/textures/container.jpg")
    floorTexture:u32 = loadTexture("./assets/textures/metal.png")


	// shader configuration
    // --------------------
	gl.UseProgram(shader)
	shader_set_int(shader,"texture1",0)

	gl.UseProgram(screenShader)
	shader_set_int(screenShader,"screenTexture",0)

	// framebuffer configuration
    // -------------------------
	framebuffer:u32
    gl.GenFramebuffers(1, &framebuffer)
    gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer);
    // create a color attachment texture
    textureColorbuffer:u32
    gl.GenTextures(1, &textureColorbuffer)
    gl.BindTexture(gl.TEXTURE_2D, textureColorbuffer)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, SCR_WIDTH, SCR_HEIGHT, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, textureColorbuffer, 0)
    // create a renderbuffer object for depth and stencil attachment (we won't be sampling these)
    rbo:u32
    gl.GenRenderbuffers(1, &rbo)
    gl.BindRenderbuffer(gl.RENDERBUFFER, rbo)
    gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, SCR_WIDTH, SCR_HEIGHT) // use a single renderbuffer object for both a depth AND stencil buffer.
    gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rbo) // now actually attach it
    // now that we actually created the framebuffer and added all attachments we want to check if it is actually complete now
    if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE{
        fmt.printfln("ERROR::FRAMEBUFFER:: Framebuffer is not complete!")
	}
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

	// draw as wireframe
    //gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);


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
		// bind to framebuffer and draw scene as we normally would to color texture 
        gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer)
        gl.Enable(gl.DEPTH_TEST) // enable depth testing (is disabled for rendering screen-space quad)

		// make sure we clear the framebuffer's content
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

		// world transformation
		model:glm.mat4 = glm.mat4(1.0)
		shader_set_mat4(shader,"model",&model[0][0])

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

		// Floor
		gl.BindVertexArray(planeVAO)
		gl.BindTexture(gl.TEXTURE_2D, floorTexture)
		model = glm.mat4(1.0)
		shader_set_mat4(shader,"model",&model[0][0])
		gl.DrawArrays(gl.TRIANGLES,0,6)
		gl.BindVertexArray(0)


		 // now bind back to default framebuffer and draw a quad plane with the attached framebuffer color texture
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
        gl.Disable(gl.DEPTH_TEST) // disable depth test so screen-space quad isn't discarded due to depth test.
        // clear all relevant buffers
        gl.ClearColor(1.0, 1.0, 1.0, 1.0) // set clear color to white (not really necessery actually, since we won't be able to see behind the quad anyways)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        gl.UseProgram(screenShader)
        gl.BindVertexArray(quadVAO)
        gl.BindTexture(gl.TEXTURE_2D, textureColorbuffer)	// use the color attachment texture as the texture of the quad plane
        gl.DrawArrays(gl.TRIANGLES, 0, 6)

		


		
		
		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
	// optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------

	gl.DeleteVertexArrays(1, &cubeVAO)
    gl.DeleteVertexArrays(1, &planeVAO)
    gl.DeleteVertexArrays(1, &quadVAO)
    gl.DeleteBuffers(1, &cubeVBO)
    gl.DeleteBuffers(1, &planeVBO)
    gl.DeleteBuffers(1, &quadVBO)

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