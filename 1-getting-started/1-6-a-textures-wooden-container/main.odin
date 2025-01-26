package main
/*
CHAPTER: 1-6-a TEXTURES (WOODEN CONTAINER)
TUTORIAL: https://learnopengl.com/Getting-started/Textures
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/1.getting_started/4.1.textures/textures.cpp
*/

import "core:fmt"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import "core:math"
import "core:os" 
import stbi "vendor:stb/image" 

// settings
SCR_WIDTH:i32:800
SCR_HEIGHT:i32:600

OPENGL_MAJOR_VERSION::3
OPENGL_MINOR_VERSION::3

VERTEX_SHADER_FILEPATH:string:"./textures.vs"
FRAGMENT_SHADER_FILEPATH:string:"./textures.fs"

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
		// positions      // colors        // texture coords
		0.5,  0.5, 0.0,   1.0, 0.0, 0.0,   1.0, 1.0, // top right
		0.5, -0.5, 0.0,   0.0, 1.0, 0.0,   1.0, 0.0, // bottom right
	   -0.5, -0.5, 0.0,   0.0, 0.0, 1.0,   0.0, 0.0, // bottom left
	   -0.5,  0.5, 0.0,   1.0, 1.0, 0.0,   0.0, 1.0  // top left 
	}
	indices:[]u32 = {
		0, 1, 3, // first triangle
        1, 2, 3  // second triangle
	}
	
	VBO, VAO, EBO:u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	gl.GenBuffers(1, &EBO)

	gl.BindVertexArray(VAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(vertices), raw_data(vertices), gl.STATIC_DRAW)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER,size_of(u32)*len(indices), raw_data(indices), gl.STATIC_DRAW)

	// position attribute
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,8 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)
	// color attribute
	gl.VertexAttribPointer(1,3,gl.FLOAT, gl.FALSE,8 * size_of(f32), cast(uintptr)(3*size_of(f32)))
	gl.EnableVertexAttribArray(1)
	// texture coord attribute
	gl.VertexAttribPointer(2,2,gl.FLOAT, gl.FALSE,8 * size_of(f32), cast(uintptr)(6*size_of(f32)))
	gl.EnableVertexAttribArray(2)

	// load and create a texture 
    // -------------------------
	texture:u32
	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture) // all upcoming GL_TEXTURE_2D operations now have effect on this texture object
	// set the texture wrapping parameters
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT) // set texture wrapping to GL_REPEAT (default wrapping method)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	// set texture filtering parameters
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	// load image, create texture and generate mipmaps
	width, height, nrChannels:i32
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

	// render loop
    // -----------
	for !glfw.WindowShouldClose(window){
		// input
        // -----
		processInput(window)

		// render
        // ------
        gl.ClearColor(0.2, 0.3, 0.3, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

		// bind Texture
        gl.BindTexture(gl.TEXTURE_2D, texture);

        // render container
        gl.UseProgram(shaderProgram)
        gl.BindVertexArray(VAO);
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil);

		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
	// optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------
	gl.DeleteVertexArrays(1, &VAO)
	gl.DeleteBuffers(1, &VBO)
	gl.DeleteBuffers(1, &EBO)
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