package main
/*
CHAPTER: 4-7-1 Geometry Shader Houses
TUTORIAL: https://learnopengl.com/Advanced-OpenGL/Geometry-Shader
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/4.advanced_opengl/9.1.geometry_shader_houses/geometry_shader_houses.cpp
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



main::proc(){
	// glfw: initialize and configure
    // ------------------------------
	if !renderer_init(){
		return
	}
	stbi.set_flip_vertically_on_load(1)
	// build and compile our shader programs
    // ------------------------------------
    shader, shaderOk := shader_init("./shaders/geometry_shaders.vs","./shaders/geometry_shaders.fs","./shaders/geometry_shaders.gs")
	if !shaderOk{
		return
	}


	// set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    points:[]f32 = {
        -0.5,  0.5, 1.0, 0.0, 0.0, // top-let
         0.5,  0.5, 0.0, 1.0, 0.0, // top-right
         0.5, -0.5, 0.0, 0.0, 1.0, // bottom-right
        -0.5, -0.5, 1.0, 1.0, 0.0  // bottom-let
    }


	// CUBE VAO
	VBO, VAO:u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	gl.BindVertexArray(VAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(points), raw_data(points), gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0,2,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1,3,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)(2*size_of(f32)))
	gl.BindVertexArray(0)

	// render loop
    // -----------
	for !glfw.WindowShouldClose(window){
	
		// render
        // ------
        gl.ClearColor(0.1, 0.1, 0.1, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		// draw points
		gl.UseProgram(shader)
		gl.BindVertexArray(VAO)
		gl.DrawArrays(gl.POINTS,0,4)

		
		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
	// optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------

	gl.DeleteVertexArrays(1, &VAO)
    gl.DeleteBuffers(1, &VBO)

	// glfw: terminate, clearing all previously allocated GLFW resources.
    // ------------------------------------------------------------------
	glfw.Terminate()

}

// glfw: whenever the window size changed (by OS or user resize) this callback function executes
// ---------------------------------------------------------------------------------------------
framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
}
