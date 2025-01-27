package main
/*
CHAPTER: 1-9-d FILE RESTRUCTURE
TUTORIAL: https://learnopengl.com/Getting-started/Camera
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
	// build and compile our shader program
    // ------------------------------------
    shaderProgram, ok := shader_init("./shaders/camera.vs","./shaders/camera.fs")
	if !ok{
		return
	}

	camera_init(&mainCamera,{0.0,0.0,3.0})

	 // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
	vertices:[]f32 = {
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

	// world space positions of our cubes
    cubePositions:[]glm.vec3= {
        { 0.0,  0.0,  0.0},
        { 2.0,  5.0, -15.0},
        {-1.5, -2.2, -2.5},
        {-3.8, -2.0, -12.3},
        { 2.4, -0.4, -3.5},
        {-1.7,  3.0, -7.5},
        { 1.3, -2.0, -2.5},
        { 1.5,  2.0, -2.5},
        { 1.5,  0.2, -1.5},
        {-1.3,  1.0, -1.5}
    }
	
	VBO, VAO:u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)

	gl.BindVertexArray(VAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(vertices), raw_data(vertices), gl.STATIC_DRAW)

	// position attribute
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)
	// texture coord attribute
	gl.VertexAttribPointer(1,2,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)(3*size_of(f32)))
	gl.EnableVertexAttribArray(1)

	// load and create a texture 
    // -------------------------
	texture1, texture2:u32
	gl.GenTextures(1, &texture1)
	gl.BindTexture(gl.TEXTURE_2D, texture1) // all upcoming GL_TEXTURE_2D operations now have effect on this texture object
	// set the texture wrapping parameters
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT) // set texture wrapping to GL_REPEAT (default wrapping method)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	// set texture filtering parameters
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	// load image, create texture and generate mipmaps
	width, height, nrChannels:i32
	stbi.set_flip_vertically_on_load(1) // tell stb_image.h to flip loaded texture's on the y-axis.
	filepath:cstring = "./assets/images/container.jpg"
	data:[^]u8 = stbi.load(filepath, &width, &height, &nrChannels, 0)
	if data != nil{
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width,height,0,gl.RGB,gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
	}else{
		fmt.printfln("Failed to load texture: \n%v",filepath)
		fmt.println("Loading file error: %v", stbi.failure_reason())
		glfw.Terminate()
		return
	}
	stbi.image_free(data)

	// texture 2
    // ---------
    gl.GenTextures(1, &texture2)
    gl.BindTexture(gl.TEXTURE_2D, texture2)
    // set the texture wrapping parameters
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)	// set texture wrapping to GL_REPEAT (default wrapping method)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
    // set texture filtering parameters
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    // load image, create texture and generate mipmaps
	filepath = "./assets/images/awesomeface.png"
    data = stbi.load(filepath, &width, &height, &nrChannels, 0)
    if data != nil{
		// note that the awesomeface.png has transparency and thus an alpha channel, so make sure to tell OpenGL the data type is of GL_RGBA
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width,height,0,gl.RGBA,gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
	}else{
		fmt.printfln("Failed to load texture: \n%v",filepath)
		fmt.println("Loading file error: %v", stbi.failure_reason())
		glfw.Terminate()
		return
	}
	stbi.image_free(data)

	// tell opengl for each sampler to which texture unit it belongs to (only has to be done once)
    // -------------------------------------------------------------------------------------------
    gl.UseProgram(shaderProgram)
    gl.Uniform1i(gl.GetUniformLocation(shaderProgram, "texture1"), 0)
	gl.Uniform1i(gl.GetUniformLocation(shaderProgram, "texture2"), 1)


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
        gl.ClearColor(0.2, 0.3, 0.3, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		// bind textures on corresponding texture units
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, texture1)
        gl.ActiveTexture(gl.TEXTURE1)
        gl.BindTexture(gl.TEXTURE_2D, texture2)

		// activate shader
        gl.UseProgram(shaderProgram)

		// pass projection matrix to shader (note that in this case it could change every frame)
		projection:glm.mat4 = glm.mat4Perspective(
			glm.radians_f32(mainCamera.zoom),
			f32(SCR_WIDTH)/f32(SCR_HEIGHT),
			0.1,
			100
		)
		shader_set_mat4(shaderProgram, "projection", &projection[0][0])

        // camera/view transformation
        view:glm.mat4 = camera_get_view_matrix(&mainCamera)
		shader_set_mat4(shaderProgram, "view", &view[0][0])
		
        // render boxes
        gl.BindVertexArray(VAO)
		for i:u32; i < 10; i+=1{
			// calculate the model matrix for each object and pass it to shader before drawing
			model:glm.mat4 = glm.mat4(1.0)
			model = glm.mat4Translate(cubePositions[i])
			angle:f32 = 20 * f32(i)
			model = model * glm.mat4Rotate({1.0,0.3,0.5}, glm.radians_f32(angle))
			shader_set_mat4(shaderProgram,"model", &model[0][0])
			gl.DrawArrays(gl.TRIANGLES, 0, 36)
		}

		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
	// optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------
	gl.DeleteVertexArrays(1, &VAO)
	gl.DeleteBuffers(1, &VBO)
	gl.DeleteProgram(shaderProgram)

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

	camera_process_mouse_movement(&mainCamera,xoffset, yoffset)
	
}
// glfw: whenever the mouse scroll wheel scrolls, this callback is called
// ----------------------------------------------------------------------
scroll_callback::proc "c" (window:glfw.WindowHandle, xoffset:f64, yoffset:f64){
	camera_process_mouse_scroll(&mainCamera, f32(yoffset))
}