package main
/*
CHAPTER: 4-9-1 Anti-Aliasing MSAA
TUTORIAL: https://learnopengl.com/Advanced-OpenGL/Depth-testing
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/4.advanced_opengl/11.1.anti_aliasing_msaa/anti_aliasing_msaa.cpp
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
 
    shader, shaderOk := shader_init("./shaders/anti_aliasing.vs","./shaders/anti_aliasing.fs")
	if !shaderOk{
		return
	}
    screenShader, screenShaderOk := shader_init("./shaders/aa_post.vs","./shaders/aa_post.fs")
	if !screenShaderOk{
		return
	}
	camera_init(&mainCamera,{0.0,0.0,3.0})


	// set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    cubeVertices:[]f32 = {
        // positions       
        -0.5, -0.5, -0.5,
         0.5, -0.5, -0.5,
         0.5,  0.5, -0.5,
         0.5,  0.5, -0.5,
        -0.5,  0.5, -0.5,
        -0.5, -0.5, -0.5,

        -0.5, -0.5,  0.5,
         0.5, -0.5,  0.5,
         0.5,  0.5,  0.5,
         0.5,  0.5,  0.5,
        -0.5,  0.5,  0.5,
        -0.5, -0.5,  0.5,

        -0.5,  0.5,  0.5,
        -0.5,  0.5, -0.5,
        -0.5, -0.5, -0.5,
        -0.5, -0.5, -0.5,
        -0.5, -0.5,  0.5,
        -0.5,  0.5,  0.5,

         0.5,  0.5,  0.5,
         0.5,  0.5, -0.5,
         0.5, -0.5, -0.5,
         0.5, -0.5, -0.5,
         0.5, -0.5,  0.5,
         0.5,  0.5,  0.5,

        -0.5, -0.5, -0.5,
         0.5, -0.5, -0.5,
         0.5, -0.5,  0.5,
         0.5, -0.5,  0.5,
        -0.5, -0.5,  0.5,
        -0.5, -0.5, -0.5,

        -0.5,  0.5, -0.5,
         0.5,  0.5, -0.5,
         0.5,  0.5,  0.5,
         0.5,  0.5,  0.5,
        -0.5,  0.5,  0.5,
        -0.5,  0.5, -0.5
    }

	quadVertices:[]f32 = {   // vertex attributes for a quad that fills the entire screen in Normalized Device Coordinates.
        // positions // texCoords
        -1.0,  1.0,  0.0, 1.0,
        -1.0, -1.0,  0.0, 0.0,
         1.0, -1.0,  1.0, 0.0,

        -1.0,  1.0,  0.0, 1.0,
         1.0, -1.0,  1.0, 0.0,
         1.0,  1.0,  1.0, 1.0
    };
    
	// cube VAO
	cubeVBO, cubeVAO:u32
	gl.GenVertexArrays(1, &cubeVAO)
	gl.GenBuffers(1, &cubeVBO)
	gl.BindVertexArray(cubeVAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, cubeVBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(cubeVertices), raw_data(cubeVertices), gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,3 * size_of(f32), cast(uintptr)0)

	// Screen VAO
	quadVBO, quadVAO:u32
	gl.GenVertexArrays(1, &quadVAO)
	gl.GenBuffers(1, &quadVBO)
	gl.BindVertexArray(quadVAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, quadVBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(quadVertices), raw_data(quadVertices), gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0,2,gl.FLOAT, gl.FALSE,4 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1,2,gl.FLOAT, gl.FALSE,4 * size_of(f32), cast(uintptr)(2 * size_of(f32)))


	// configure MSAA framebuffer
    // --------------------------
	framebuffer:u32
    gl.GenFramebuffers(1, &framebuffer)
    gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer)
    // create a multisampled color attachment texture
    textureColorBufferMultiSampled:u32
    gl.GenTextures(1, &textureColorBufferMultiSampled)
    gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, textureColorBufferMultiSampled)
    gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, 4, gl.RGB, SCR_WIDTH, SCR_HEIGHT, gl.TRUE)
    gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, 0)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D_MULTISAMPLE, textureColorBufferMultiSampled, 0)
    // create a (also multisampled) renderbuffer object for depth and stencil attachments
    rbo:u32
    gl.GenRenderbuffers(1, &rbo)
    gl.BindRenderbuffer(gl.RENDERBUFFER, rbo)
    gl.RenderbufferStorageMultisample(gl.RENDERBUFFER, 4, gl.DEPTH24_STENCIL8, SCR_WIDTH, SCR_HEIGHT)
    gl.BindRenderbuffer(gl.RENDERBUFFER, 0)
    gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rbo)

    if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE{
		fmt.printfln("ERROR::FRAMEBUFFER:: Framebuffer is not complete!")
	}
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

    // configure second post-processing framebuffer
    intermediateFBO:u32;
    gl.GenFramebuffers(1, &intermediateFBO)
    gl.BindFramebuffer(gl.FRAMEBUFFER, intermediateFBO)
    // create a color attachment texture
    screenTexture:u32
    gl.GenTextures(1, &screenTexture)
    gl.BindTexture(gl.TEXTURE_2D, screenTexture)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, SCR_WIDTH, SCR_HEIGHT, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, screenTexture, 0)	// we only need a color buffer

    if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE{
		fmt.printfln("ERROR::FRAMEBUFFER:: Intermediate framebuffer is not complete!")
	}
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

	// shader configuration
    // --------------------
	gl.UseProgram(screenShader)
	shader_set_int(screenShader,"screenTexture",0)

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

		// 1. draw scene as normal in multisampled buffers
		gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer)
        gl.ClearColor(0.1, 0.1, 0.1, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        gl.Enable(gl.DEPTH_TEST)

		// set transformation matrices
		gl.UseProgram(shader)
		projection:glm.mat4 = glm.mat4Perspective(
			glm.radians_f32(mainCamera.zoom),
			f32(SCR_WIDTH)/f32(SCR_HEIGHT),
			0.1,
			100
		)
		view:glm.mat4 = camera_get_view_matrix(&mainCamera)
		shader_set_mat4(shader,"projection",&projection[0][0])
		shader_set_mat4(shader,"view",&view[0][0])
		model:glm.mat4 = glm.mat4(1.0)
		shader_set_mat4(shader,"model",&model[0][0])

		gl.BindVertexArray(cubeVAO)
		gl.DrawArrays(gl.TRIANGLES,0,36)

		// 2. now blit multisampled buffer(s) to normal colorbuffer of intermediate FBO. Image is stored in screenTexture
		gl.BindFramebuffer(gl.READ_FRAMEBUFFER, framebuffer)
        gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, intermediateFBO)
        gl.BlitFramebuffer(0, 0, SCR_WIDTH, SCR_HEIGHT, 0, 0, SCR_WIDTH, SCR_HEIGHT, gl.COLOR_BUFFER_BIT, gl.NEAREST)

		// 3. now render quad with scene's visuals as its texture image
		gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
        gl.ClearColor(1.0, 1.0, 1.0, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)
        gl.Disable(gl.DEPTH_TEST)

		// draw Screen quad
		gl.UseProgram(screenShader)
        gl.BindVertexArray(quadVAO)
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, screenTexture) // use the now resolved color attachment as the quad's texture
        gl.DrawArrays(gl.TRIANGLES, 0, 6)

		
		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
	// optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------

	gl.DeleteVertexArrays(1, &cubeVAO)
    gl.DeleteBuffers(1, &cubeVBO)

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