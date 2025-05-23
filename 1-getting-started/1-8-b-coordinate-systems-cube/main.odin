package main
/*
CHAPTER: 1-8-b COORDINATE SYSTEMS (CUBE)
TUTORIAL: https://learnopengl.com/Getting-started/Coordinate-Systems
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/1.getting_started/6.2.coordinate_systems_depth/coordinate_systems_depth.cpp
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

VERTEX_SHADER_FILEPATH:string:"./coordinate_systems.vs"
FRAGMENT_SHADER_FILEPATH:string:"./coordinate_systems.fs"

window: glfw.WindowHandle
shaderProgram: u32

main::proc(){
	// glfw: initialize and configure
    // ------------------------------
	if !renderer_init(){
		return
	}
	// build and compile our shader program
    // ------------------------------------
    if !shader_init(VERTEX_SHADER_FILEPATH,FRAGMENT_SHADER_FILEPATH){
		return
	}

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
	filepath:cstring = "./container.jpg"
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
	filepath = "./awesomeface.png"
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

        // create transformations
        model:glm.mat4 = glm.mat4(1.0)
        view:glm.mat4 = glm.mat4(1.0) 
        projection:glm.mat4 = glm.mat4(1.0)
		model = model * glm.mat4Rotate({0.5,1.0,0.0},f32(glfw.GetTime()))
		view = view * glm.mat4Translate({0.0,0.0,-3.0})
		projection = glm.mat4Perspective(
			glm.radians_f32(45),
			f32(SCR_WIDTH)/f32(SCR_HEIGHT),
			0.1,
			100
		)
		// retrieve the matrix uniform locations
		modelLoc:i32 = gl.GetUniformLocation(shaderProgram, "model")
		viewLoc:i32 = gl.GetUniformLocation(shaderProgram, "view")
		projectionLoc:i32 = gl.GetUniformLocation(shaderProgram, "projection")
		// pass them to the shaders
		gl.UniformMatrix4fv(modelLoc, 1, gl.FALSE, &model[0][0])
		gl.UniformMatrix4fv(viewLoc, 1, gl.FALSE, &view[0][0])
		// note: currently we set the projection matrix each frame, but since the projection matrix rarely changes it's often best practice to set it outside the main loop only once.
		gl.UniformMatrix4fv(projectionLoc, 1, gl.FALSE, &projection[0][0])

        // render box
        gl.BindVertexArray(VAO)
        gl.DrawArrays(gl.TRIANGLES, 0, 36)

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
processInput::proc(window:glfw.WindowHandle){
	if glfw.GetKey(window, glfw.KEY_ESCAPE)==glfw.PRESS{
		glfw.SetWindowShouldClose(window, true)
	}
}