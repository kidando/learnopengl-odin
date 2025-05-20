package main
/*
CHAPTER: 4-8-3 Instancing Asteroids Instanced
TUTORIAL: https://learnopengl.com/Advanced-OpenGL/Instancing
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/4.advanced_opengl/10.3.asteroids_instanced/asteroids_instanced.cpp
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
    asteroidShader, asteroidShaderOk := shader_init("./shaders/asteroids.vs","./shaders/asteroids.fs")
	if !asteroidShaderOk{
		return
	}
    planetShader, planetShaderOk := shader_init("./shaders/planet.vs","./shaders/planet.fs")
	if !planetShaderOk{
		return
	}
	camera_init(&mainCamera,{0.0,0.0,105.0})


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
	amount:int = 10000
	modelMatrices := make([]glm.mat4, amount)
	defer delete(modelMatrices)

	// Initialize random seed using GLFW time
	seed := glfw.GetTime()
	rand.reset(u64(seed))
	radius:f32 = 150
	offset:f32 = 25.0

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
	// configure instanced array
    // -------------------------
	buffer:u32
	gl.GenBuffers(1, &buffer)
	gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
	gl.BufferData(gl.ARRAY_BUFFER, amount * size_of(glm.mat4), &modelMatrices[0], gl.STATIC_DRAW);

	 // set transformation matrices as an instance vertex attribute (with divisor 1)
    // note: we're cheating a little by taking the, now publicly declared, VAO of the model's mesh(es) and adding new vertexAttribPointers
    // normally you'd want to do this in a more organized fashion, but for learning purposes this will do.
    // -----------------------------------------------------------------------------------------------------------------------------------
	for i:int; i < len(rock.meshes); i += 1{
		mesh := rock.meshes[i]
		for j:int; j < len(mesh.primitives); j += 1{
			primitive := mesh.primitives[j]
			VAO:u32 = primitive.vao
			gl.BindVertexArray(VAO)
			// set attribute pointers for matrix (4 times vec4)
			gl.EnableVertexAttribArray(3)
			gl.VertexAttribPointer(3,4,gl.FLOAT, gl.FALSE, size_of(glm.mat4),cast(uintptr)0)
			gl.EnableVertexAttribArray(4)
			gl.VertexAttribPointer(4,4,gl.FLOAT, gl.FALSE, size_of(glm.mat4),cast(uintptr)(size_of(glm.vec4)))
			gl.EnableVertexAttribArray(5)
			gl.VertexAttribPointer(5,4,gl.FLOAT, gl.FALSE, size_of(glm.mat4),cast(uintptr)(2*size_of(glm.vec4)))
			gl.EnableVertexAttribArray(6)
			gl.VertexAttribPointer(6,4,gl.FLOAT, gl.FALSE, size_of(glm.mat4),cast(uintptr)(3*size_of(glm.vec4)))

			gl.VertexAttribDivisor(3,1)
			gl.VertexAttribDivisor(4,1)
			gl.VertexAttribDivisor(5,1)
			gl.VertexAttribDivisor(6,1)

			gl.BindVertexArray(0)
		}
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
		

		// view/projection transformations
		projection:glm.mat4 = glm.mat4Perspective(
			glm.radians_f32(mainCamera.zoom),
			f32(SCR_WIDTH)/f32(SCR_HEIGHT),
			0.1,
			100
		)
		view:glm.mat4 = camera_get_view_matrix(&mainCamera)

		gl.UseProgram(asteroidShader)
		shader_set_mat4(asteroidShader,"projection",&projection[0][0])
		shader_set_mat4(asteroidShader,"view",&view[0][0])
		gl.UseProgram(planetShader)
		shader_set_mat4(planetShader,"projection",&projection[0][0])
		shader_set_mat4(planetShader,"view",&view[0][0])
		
		// Draw Planet
		model:glm.mat4 = glm.mat4(1.0)
		model = glm.mat4Translate({0.0,-3.0,0.0})
		model *= glm.mat4Scale({4.0,4.0,4.0})
		shader_set_mat4(planetShader,"model",&model[0][0])
		ai_draw_model(&planet, planetShader)

	
		// draw meteorites
		gl.UseProgram(asteroidShader)
		shader_set_int(asteroidShader,"texture_diffuse1",0)
		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, rock.meshes[0].primitives[0].textures[0].id)
		for i:int; i < len(rock.meshes); i += 1{
			mesh := rock.meshes[i]
			for j:int; j < len(mesh.primitives); j += 1{
				primitive := mesh.primitives[i]
				gl.BindVertexArray(primitive.vao)
				gl.DrawElementsInstanced(gl.TRIANGLES,i32(len(primitive.indices)), gl.UNSIGNED_INT, nil, i32(amount) )
				gl.BindVertexArray(0)
			}
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