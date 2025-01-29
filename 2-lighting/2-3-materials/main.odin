package main
/*
CHAPTER: 2-3 Materials
TUTORIAL: https://learnopengl.com/Lighting/Materials
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/2.lighting/3.1.materials/materials.cpp
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

// lighting
lightPos:glm.vec3 = {1.2, 1.0, 2.0}

main::proc(){
	// glfw: initialize and configure
    // ------------------------------
	if !renderer_init(){
		return
	}
	// build and compile our shader programs
    // ------------------------------------
    lightingShader, lightingShaderOk := shader_init("./shaders/materials.vs","./shaders/materials.fs")
	if !lightingShaderOk{
		return
	}
    lightCubeShader, lightCubeShaderOk := shader_init("./shaders/light_cube.vs","./shaders/light_cube.fs")
	if !lightCubeShaderOk{
		return
	}

	camera_init(&mainCamera,{0.0,0.0,3.0})

	 // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
	vertices:[]f32 = {
		-0.5, -0.5, -0.5,  0.0,  0.0, -1.0,
         0.5, -0.5, -0.5,  0.0,  0.0, -1.0,
         0.5,  0.5, -0.5,  0.0,  0.0, -1.0,
         0.5,  0.5, -0.5,  0.0,  0.0, -1.0,
        -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,
        -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,

        -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,
         0.5, -0.5,  0.5,  0.0,  0.0,  1.0,
         0.5,  0.5,  0.5,  0.0,  0.0,  1.0,
         0.5,  0.5,  0.5,  0.0,  0.0,  1.0,
        -0.5,  0.5,  0.5,  0.0,  0.0,  1.0,
        -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,

        -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,
        -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,
        -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,
        -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,
        -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,
        -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,

         0.5,  0.5,  0.5,  1.0,  0.0,  0.0,
         0.5,  0.5, -0.5,  1.0,  0.0,  0.0,
         0.5, -0.5, -0.5,  1.0,  0.0,  0.0,
         0.5, -0.5, -0.5,  1.0,  0.0,  0.0,
         0.5, -0.5,  0.5,  1.0,  0.0,  0.0,
         0.5,  0.5,  0.5,  1.0,  0.0,  0.0,

        -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,
         0.5, -0.5, -0.5,  0.0, -1.0,  0.0,
         0.5, -0.5,  0.5,  0.0, -1.0,  0.0,
         0.5, -0.5,  0.5,  0.0, -1.0,  0.0,
        -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,
        -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,

        -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,
         0.5,  0.5, -0.5,  0.0,  1.0,  0.0,
         0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
         0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
        -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,
        -0.5,  0.5, -0.5,  0.0,  1.0,  0.0 
	}

	// first, configure the cube's VAO (and VBO)
	VBO, cubeVAO:u32
	gl.GenVertexArrays(1, &cubeVAO)
	gl.GenBuffers(1, &VBO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(vertices), raw_data(vertices), gl.STATIC_DRAW)

	gl.BindVertexArray(cubeVAO)

	// position attribute
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,6 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)

	// normal attribute
	gl.VertexAttribPointer(1,3,gl.FLOAT, gl.FALSE,6 * size_of(f32), cast(uintptr)(3*size_of(f32)))
	gl.EnableVertexAttribArray(1)

	// second, configure the light's VAO (VBO stays the same; the vertices are the same for the light object which is also a 3D cube)
	lightCubeVAO:u32
	gl.GenVertexArrays(1, &lightCubeVAO)
	gl.BindVertexArray(lightCubeVAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	// note that we update the lamp's position attribute's stride to reflect the updated buffer data
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,6 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)


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

		// be sure to activate shader when setting uniforms/drawing objects
		gl.UseProgram(lightingShader)
		shader_set_vec3_vec(lightingShader,"light.position",&lightPos[0])
		shader_set_vec3_vec(lightingShader,"viewPos",&mainCamera.position[0])
    

        // light properties
        lightColor:glm.vec3
        lightColor.x = math.sin_f32(f32(glfw.GetTime())*2.0)
        lightColor.y = math.sin_f32(f32(glfw.GetTime())*0.7)
        lightColor.z = math.sin_f32(f32(glfw.GetTime())*1.3)
		diffuseColor:glm.vec3 = lightColor * glm.vec3(0.5) // decrease the influence
		ambientColor:glm.vec3 = diffuseColor * glm.vec3(0.2) // low influence
		shader_set_vec3_vec(lightingShader,"light.ambient",&ambientColor[0])
		shader_set_vec3_vec(lightingShader,"light.diffuse",&diffuseColor[0])
		shader_set_vec3_f32(lightingShader,"light.specular",1.0,1.0,1.0)

        // material properties
		shader_set_vec3_f32(lightingShader,"material.ambient",1.0,0.5,0.31)
		shader_set_vec3_f32(lightingShader,"material.diffuse",1.0,0.5,0.31)
		shader_set_vec3_f32(lightingShader,"material.specular",0.5,0.5,0.5) // specular lighting doesn't have full effect on this object's material
		shader_set_float(lightingShader,"material.shininess", 32)

		// view/projection transformations
		projection:glm.mat4 = glm.mat4Perspective(
			glm.radians_f32(mainCamera.zoom),
			f32(SCR_WIDTH)/f32(SCR_HEIGHT),
			0.1,
			100
		)
		view:glm.mat4 = camera_get_view_matrix(&mainCamera)
		shader_set_mat4(lightingShader,"projection",&projection[0][0])
		shader_set_mat4(lightingShader,"view",&view[0][0])

		// world transformation
		model:glm.mat4 = glm.mat4(1.0)
		shader_set_mat4(lightingShader,"model",&model[0][0])

		// render the cube
		gl.BindVertexArray(cubeVAO)
        gl.DrawArrays(gl.TRIANGLES, 0, 36)

		// also draw the lamp object
		gl.UseProgram(lightCubeShader)
		shader_set_mat4(lightCubeShader,"projection",&projection[0][0])
		shader_set_mat4(lightCubeShader,"view",&view[0][0])
		model = glm.mat4(1.0)
		model = model * glm.mat4Translate(lightPos)
		model = model * glm.mat4Scale(glm.vec3(0.2))// a smaller cube
		shader_set_mat4(lightCubeShader,"model",&model[0][0])

		gl.BindVertexArray(lightCubeVAO)
        gl.DrawArrays(gl.TRIANGLES, 0, 36)
		
		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
	// optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------
	gl.DeleteVertexArrays(1, &cubeVAO)
    gl.DeleteVertexArrays(1, &lightCubeVAO)
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