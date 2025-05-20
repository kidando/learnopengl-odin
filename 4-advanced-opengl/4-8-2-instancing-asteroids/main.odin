package main
/*
CHAPTER: 4-8-2 Instancing Asteroids
TUTORIAL: https://learnopengl.com/Advanced-OpenGL/Instancing
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/4.advanced_opengl/10.2.asteroids/asteroids.cpp
*/

import "core:fmt"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import "core:math"
import "core:os" 
import stbi "vendor:stb/image" 
import glm "core:math/linalg/glsl"
import "core:math/rand"

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
    shader, shaderOk := shader_init("./shaders/instancing.vs","./shaders/instancing.fs")
	if !shaderOk{
		return
	}
	camera_init(&mainCamera,{0.0,0.0,55.0})


	rock:Model
	ai_load_gltf_model(&rock, "./assets/models/rock/rock.gltf")
	ai_setup_model_for_gpu(&rock)
	defer ai_destroy_model(&rock)

	planet:Model
	ai_load_gltf_model(&planet, "./assets/models/planet/planet.gltf")
	ai_setup_model_for_gpu(&planet)
	defer ai_destroy_model(&planet)


	// generate a large list of semi-random model transformation matrices
    // ------------------------------------------------------------------
	amount:int = 1000
	modelMatrices := make([]glm.mat4, amount)
	defer delete(modelMatrices)

	// Initialize random seed using GLFW time
	seed := glfw.GetTime()
	rand.reset(u64(seed))
	radius:f32 = 50
	offset:f32 = 2.5

	for i:int; i < amount; i += 1{
		model:glm.mat4 = glm.mat4(1.0)

		// 1. translation: displace along circle with 'radius' in range [-offset, offset]
		angle:f32 = f32(i)/f32(amount) * 360
		displacement:f32 = f32(rand.int31()%i32(2*offset*100))/100-offset
		x:f32 = math.sin_f32(angle) * radius + displacement
		displacement = f32(rand.int31()%i32(2*offset*100))/100-offset
		y:f32 = displacement * 0.4 // keep height of asteroid field smaller compared to width of x and z
		displacement = f32(rand.int31()%i32(2*offset*100))/100-offset
		z:f32 = math.cos_f32(angle) * radius + displacement
		model *= glm.mat4Translate({x,y,z})

		// 2. scale: Scale between 0.05 and 0.25f
		scale:f32 = f32(rand.int31()%20)/(100+0.05)
		model *= glm.mat4Scale(glm.vec3(scale))

		// 3. rotation: add random rotation around a (semi)randomly picked rotation axis vector
		rotAngle:f32 = f32(rand.int31()%360)
		model *= glm.mat4Rotate({0.4,0.6,0.8},rotAngle)

		// 4. now add to list of matrices
        modelMatrices[i] = model

	}


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
		model = glm.mat4Translate({0.0,-3.0,0.0})
		model *= glm.mat4Scale({4.0,4.0,4.0})
		shader_set_mat4(shader,"model",&model[0][0])
		ai_draw_model(&planet, shader)

	
		// draw meteorites
		for i:int; i < amount; i += 1{
			model +=  modelMatrices[i]
			shader_set_mat4(shader,"model",&model[0][0])
			ai_draw_model(&rock, shader)
		}

	

		
		
		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
	// optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------


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