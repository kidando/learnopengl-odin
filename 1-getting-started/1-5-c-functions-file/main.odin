package main
/*
CHAPTER: 1-5-c FUNCTIONS FILES WITH UTIL PROCEDURES
TUTORIAL: https://learnopengl.com/Getting-started/Shaders
*/

import "core:fmt"
import gl "vendor:OpenGL" // GL loader similar to GLAD (if not GLAD itself but in ODIN)
import glfw "vendor:glfw"
import "core:math" // For math functions
import "core:os" // For file management

// settings
SCR_WIDTH:i32:800
SCR_HEIGHT:i32:600

<<<<<<< HEAD
OPENGL_MAJOR_VERSION::3
OPENGL_MINOR_VERSION::3

=======
>>>>>>> 32ce4f88c2819bdd027c871e95dcc80709b1a243
VERTEX_SHADER_FILEPATH:string:"./triangle.vs"
FRAGMENT_SHADER_FILEPATH:string:"./triangle.fs"

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
		// positions     // colors
		0.5, -0.5, 0.0,  1.0, 0.0, 0.0,  // bottom right
        -0.5, -0.5, 0.0,  0.0, 1.0, 0.0,  // bottom left
        0.0,  0.5, 0.0,  0.0, 0.0, 1.0   // top 
	}
	
	VBO, VAO:u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	// bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
	gl.BindVertexArray(VAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(vertices), raw_data(vertices), gl.STATIC_DRAW)

	// position attribute
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,6 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)

	// position attribute
	gl.VertexAttribPointer(1,3,gl.FLOAT, gl.FALSE,6 * size_of(f32), cast(uintptr)(3*size_of(f32)))
	gl.EnableVertexAttribArray(1)

	// You can unbind the VAO afterwards so other VAO calls won't accidentally modify this VAO, but this rarely happens. Modifying other
    // VAOs requires a call to glBindVertexArray anyways so we generally don't unbind VAOs (nor VBOs) when it's not directly necessary.
    // glBindVertexArray(0);

    // as we only have a single shader, we could also just activate our shader once beforehand if we want to 
    gl.UseProgram(shaderProgram)

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

		// render the triangle
        gl.BindVertexArray(VAO)
        gl.DrawArrays(gl.TRIANGLES, 0, 3)

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