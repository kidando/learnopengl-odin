package main
/*
CHAPTER: 4-6 Advanced GLSL
TUTORIAL: https://learnopengl.com/Advanced-OpenGL/Advanced-GLSL
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/4.advanced_opengl/8.advanced_glsl_ubo/advanced_glsl_ubo.cpp
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
    shaderRed, shaderRedOk := shader_init("./shaders/advanced_glsl.vs","./shaders/red.fs")
	if !shaderRedOk{
		return
	}
    shaderGreen, shaderGreenOk := shader_init("./shaders/advanced_glsl.vs","./shaders/green.fs")
	if !shaderGreenOk{
		return
	}
    shaderBlue, shaderBlueOk := shader_init("./shaders/advanced_glsl.vs","./shaders/blue.fs")
	if !shaderBlueOk{
		return
	}
    shaderYellow, shaderYellowOk := shader_init("./shaders/advanced_glsl.vs","./shaders/yellow.fs")
	if !shaderYellowOk{
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
        -0.5,  0.5, -0.5,
    }


	// CUBE VAO
	cubeVBO, cubeVAO:u32
	gl.GenVertexArrays(1, &cubeVAO)
	gl.GenBuffers(1, &cubeVBO)
	gl.BindVertexArray(cubeVAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, cubeVBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(cubeVertices), raw_data(cubeVertices), gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,3 * size_of(f32), cast(uintptr)0)



	// configure a uniform buffer object
    // ---------------------------------
	// first. We get the relevant block indices
    uniformBlockIndexRed:u32 = gl.GetUniformBlockIndex(shaderRed, "Matrices")
    uniformBlockIndexGreen:u32 = gl.GetUniformBlockIndex(shaderGreen, "Matrices")
    uniformBlockIndexBlue:u32 = gl.GetUniformBlockIndex(shaderBlue, "Matrices")
    uniformBlockIndexYellow:u32 = gl.GetUniformBlockIndex(shaderYellow, "Matrices")
    // then we link each shader's uniform block to this uniform binding point
    gl.UniformBlockBinding(shaderRed, uniformBlockIndexRed, 0);
    gl.UniformBlockBinding(shaderGreen, uniformBlockIndexGreen, 0);
    gl.UniformBlockBinding(shaderBlue, uniformBlockIndexBlue, 0);
    gl.UniformBlockBinding(shaderYellow, uniformBlockIndexYellow, 0);
    // Now actually create the buffer
    uboMatrices:u32
    gl.GenBuffers(1, &uboMatrices)
    gl.BindBuffer(gl.UNIFORM_BUFFER, uboMatrices)
    gl.BufferData(gl.UNIFORM_BUFFER, 2 * size_of(glm.mat4), nil, gl.STATIC_DRAW)
    gl.BindBuffer(gl.UNIFORM_BUFFER, 0)
    // define the range of the buffer that links to a uniform binding point
    gl.BindBufferRange(gl.UNIFORM_BUFFER, 0, uboMatrices, 0, 2 * size_of(glm.mat4))

    // store the projection matrix (we only do this once now) (note: we're not using zoom anymore by changing the FoV)
	projection:glm.mat4 = glm.mat4Perspective(
			glm.radians_f32(45),
			f32(SCR_WIDTH)/f32(SCR_HEIGHT),
			0.1,
			100
		)
    gl.BindBuffer(gl.UNIFORM_BUFFER, uboMatrices)
    gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(glm.mat4), &projection[0][0])
    gl.BindBuffer(gl.UNIFORM_BUFFER, 0)


	// shader configuration
    // --------------------

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

		// set the view and projection matrix in the uniform block - we only have to do this once per loop iteration.
		view:glm.mat4 = camera_get_view_matrix(&mainCamera)
		gl.BindBuffer(gl.UNIFORM_BUFFER, uboMatrices)
		gl.BufferSubData(gl.UNIFORM_BUFFER, size_of(glm.mat4), size_of(glm.mat4), &view[0][0])
        gl.BindBuffer(gl.UNIFORM_BUFFER, 0)
		

		// Draw 4 cubes
		// RED
		gl.BindVertexArray(cubeVAO)
		gl.UseProgram(shaderRed)
		model:glm.mat4 = glm.mat4(1.0)
		model = glm.mat4Translate({-0.75, 0.75, 0.0}) // move top-left
		shader_set_mat4(shaderRed,"model",&model[0][0])
		gl.DrawArrays(gl.TRIANGLES,0,36)

		// GREEN
		gl.BindVertexArray(cubeVAO)
		gl.UseProgram(shaderGreen)
		model = glm.mat4(1.0)
		model = glm.mat4Translate({0.75, 0.75, 0.0}) // move top-right
		shader_set_mat4(shaderGreen,"model",&model[0][0])
		gl.DrawArrays(gl.TRIANGLES,0,36)

		// YELLOW
		gl.BindVertexArray(cubeVAO)
		gl.UseProgram(shaderYellow)
		model = glm.mat4(1.0)
		model = glm.mat4Translate({-0.75, -0.75, 0.0}) // move bottom-left
		shader_set_mat4(shaderYellow,"model",&model[0][0])
		gl.DrawArrays(gl.TRIANGLES,0,36)

		// BLUE
		gl.BindVertexArray(cubeVAO)
		gl.UseProgram(shaderBlue)
		model = glm.mat4(1.0)
		model = glm.mat4Translate({0.75, -0.75, 0.0}) // move bottom-right
		shader_set_mat4(shaderBlue,"model",&model[0][0])
		gl.DrawArrays(gl.TRIANGLES,0,36)

		

		


		
		
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