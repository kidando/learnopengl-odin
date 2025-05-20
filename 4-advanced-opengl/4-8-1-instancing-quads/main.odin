package main
/*
CHAPTER: 4-8-1 Instancing Quads
TUTORIAL: https://learnopengl.com/Advanced-OpenGL/Instancing
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/4.advanced_opengl/10.1.instancing_quads/instancing_quads.cpp
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
    // shader, shaderOk := shader_init("./shaders/depth_testing.vs","./shaders/depth_testing_visual_dbuffer.fs") // To visualize depth buffer
    shader, shaderOk := shader_init("./shaders/instancing.vs","./shaders/instancing.fs")
	if !shaderOk{
		return
	}


	// generate a list of 100 quad locations/translation-vectors
    // ---------------------------------------------------------
	translations:[100]glm.vec2
	index:int = 0
	offset:f32 = 0.1

	for y:int = -10; y < 10; y += 2{
		for x:int = -10; x < 10; x += 2{
			translation:glm.vec2
			translation.x = f32(x)/10.0 + offset
			translation.y = f32(y)/10.0 + offset
			translations[index] = translation
			index += 1
		}
	}

	// store instance data in an array buffer
    // --------------------------------------
	instanceVBO:u32
	gl.GenBuffers(1, &instanceVBO)
	gl.BindBuffer(gl.ARRAY_BUFFER, instanceVBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(glm.vec2)*100, &translations[0], gl.STATIC_DRAW)
	gl.BindBuffer(gl.ARRAY_BUFFER,0)

	// set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
	quadVertices:[]f32 = {
        // positions   // colors
        -0.05,  0.05,  1.0, 0.0, 0.0,
         0.05, -0.05,  0.0, 1.0, 0.0,
        -0.05, -0.05,  0.0, 0.0, 1.0,

        -0.05,  0.05,  1.0, 0.0, 0.0,
         0.05, -0.05,  0.0, 1.0, 0.0,
         0.05,  0.05,  0.0, 1.0, 1.0
    }

	quadVAO, quadVBO:u32
	gl.GenVertexArrays(1, &quadVAO)
	gl.GenBuffers(1, &quadVBO)
	gl.BindVertexArray(quadVAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, quadVBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(quadVertices), raw_data(quadVertices), gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0,2,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1,3,gl.FLOAT, gl.FALSE,5 * size_of(f32), cast(uintptr)(2*size_of(f32)))
	
	// also set instance data
	gl.EnableVertexAttribArray(2)
	gl.BindBuffer(gl.ARRAY_BUFFER, instanceVBO) // this attribute comes from a different vertex buffer
	gl.VertexAttribPointer(2,2,gl.FLOAT, gl.FALSE,2 * size_of(f32), cast(uintptr)0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.VertexAttribDivisor(2,1) // tell OpenGL this is an instanced vertex attribute.

	// render loop
    // -----------
	for !glfw.WindowShouldClose(window){



		// render
        // ------
        gl.ClearColor(0.1, 0.1, 0.1, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		// draw 100 instanced quads
        gl.UseProgram(shader)
        gl.BindVertexArray(quadVAO)
        gl.DrawArraysInstanced(gl.TRIANGLES, 0, 6, 100) // 100 triangles of 6 vertices each
        gl.BindVertexArray(0)
		
		
		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
	// optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------

	gl.DeleteVertexArrays(1, &quadVAO)
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

