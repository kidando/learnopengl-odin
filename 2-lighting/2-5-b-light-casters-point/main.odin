package main
/*
CHAPTER: 2-5-b Light Casters (Point)
TUTORIAL: https://learnopengl.com/Lighting/Light-casters
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/2.lighting/5.2.light_casters_point/light_casters_point.cpp
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
    lightingShader, lightingShaderOk := shader_init("./shaders/light_casters.vs","./shaders/light_casters.fs")
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
		// positions       // normals        // texture coords
        -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  0.0,
         0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  0.0,
         0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  1.0,
         0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  1.0,
        -0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  1.0,
        -0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  0.0,

        -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  0.0,
         0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  0.0,
         0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  1.0,
         0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  1.0,
        -0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  1.0,
        -0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  0.0,

        -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0,  0.0,
        -0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  1.0,  1.0,
        -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0,  1.0,
        -0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0,  1.0,
        -0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  0.0,  0.0,
        -0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0,  0.0,

         0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0,  0.0,
         0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  1.0,  1.0,
         0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0,  1.0,
         0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0,  1.0,
         0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  0.0,  0.0,
         0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0,  0.0,

        -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0,  1.0,
         0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  1.0,  1.0,
         0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0,  0.0,
         0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0,  0.0,
        -0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  0.0,  0.0,
        -0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0,  1.0,

        -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0,  1.0,
         0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  1.0,  1.0,
         0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0,  0.0,
         0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0,  0.0,
        -0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  0.0,  0.0,
        -0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0,  1.0
	}

	cubePositions:[]glm.vec3 = {
		 {0.0,  0.0,  0.0},
         {2.0,  5.0, -15.0},
        {-1.5, -2.2, -2.5},
        {-3.8, -2.0, -12.3},
         {2.4, -0.4, -3.5},
        {-1.7,  3.0, -7.5},
         {1.3, -2.0, -2.5},
         {1.5,  2.0, -2.5},
         {1.5,  0.2, -1.5},
        {-1.3,  1.0, -1.5}
	}

	// first, configure the cube's VAO (and VBO)
	VBO, cubeVAO:u32
	gl.GenVertexArrays(1, &cubeVAO)
	gl.GenBuffers(1, &VBO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(vertices), raw_data(vertices), gl.STATIC_DRAW)

	gl.BindVertexArray(cubeVAO)
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,8 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(1,3,gl.FLOAT, gl.FALSE,8 * size_of(f32), cast(uintptr)(3*size_of(f32)))
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(2,2,gl.FLOAT, gl.FALSE,8 * size_of(f32), cast(uintptr)(6*size_of(f32)))
	gl.EnableVertexAttribArray(2)

	// second, configure the light's VAO (VBO stays the same; the vertices are the same for the light object which is also a 3D cube)
	lightCubeVAO:u32
	gl.GenVertexArrays(1, &lightCubeVAO)
	gl.BindVertexArray(lightCubeVAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	// note that we update the lamp's position attribute's stride to reflect the updated buffer data
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,8 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)

	// load textures (we now use a utility function to keep the code more organized)
    // -----------------------------------------------------------------------------
	diffuseMap, diffuseMapOk := load_texture("./assets/images/container2.png")
	if !diffuseMapOk{
		return
	}
	specularMap, specularMapOk := load_texture("./assets/images/container2_specular.png")
	if !specularMapOk{
		return
	}

	// shader configuration
    // --------------------
	gl.UseProgram(lightingShader)
	shader_set_int(lightingShader,"material.diffuse", 0)
	shader_set_int(lightingShader,"material.specular", 1)

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
		shader_set_vec3_f32(lightingShader,"light.ambient",0.2,0.2,0.2)
		shader_set_vec3_f32(lightingShader,"light.diffuse",0.5,0.5,0.5)
		shader_set_vec3_f32(lightingShader,"light.specular",1.0,1.0,1.0)
		shader_set_float(lightingShader,"light.constant",1.0)
		shader_set_float(lightingShader,"light.linear",0.09)
		shader_set_float(lightingShader,"light.quadratic",0.032)
	
        // material properties
		shader_set_float(lightingShader,"material.shininess",32.0)
	
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

		// bind diffuse map
		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, diffuseMap)
		// bind specular map
		gl.ActiveTexture(gl.TEXTURE1)
		gl.BindTexture(gl.TEXTURE_2D, specularMap)

		// render the containers
		gl.BindVertexArray(cubeVAO);
        for i:int = 0; i < 10; i+=1{
            // calculate the model matrix for each object and pass it to shader before drawing
            model:glm.mat4 = glm.mat4(1.0)
            model = model * glm.mat4Translate(cubePositions[i])
            angle:f32 = 20.0 * f32(i)
			model = model * glm.mat4Rotate({1.0, 0.3, 0.5},glm.radians_f32(angle))
			shader_set_mat4(lightingShader,"model",&model[0][0])

            gl.DrawArrays(gl.TRIANGLES, 0, 36)
        }

		// also draw the lamp object
		gl.UseProgram(lightCubeShader)
		shader_set_mat4(lightCubeShader,"projection",&projection[0][0])
		shader_set_mat4(lightCubeShader,"view",&view[0][0])
	
		model = glm.mat4(1.0)
		model = model * glm.mat4Translate(lightPos)
		model = model * glm.mat4Scale(glm.vec3(0.2))

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

// utility function for loading a 2D texture from file
// ---------------------------------------------------
load_texture::proc(filepath:cstring)->(u32,bool){
	texture:u32
	gl.GenTextures(1, &texture)

	width, height, nrComponents:i32
	filepath:cstring = filepath
	data:[^]u8 = stbi.load(filepath, &width, &height, &nrComponents, 0)
	if data != nil{
		format:u32
		if nrComponents == 1{
			format = gl.RED
		}else if nrComponents == 3{
			format = gl.RGB
		}else if nrComponents == 4{
			format = gl.RGBA
		}
		gl.BindTexture(gl.TEXTURE_2D, texture)
		gl.TexImage2D(gl.TEXTURE_2D, 0, i32(format), width,height,0,format,gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	}else{
		fmt.printfln("Failed to load texture: \n%v",filepath)
		fmt.println("Loading file error: %v", stbi.failure_reason())
		stbi.image_free(data)
		glfw.Terminate()
		return 0, false
	}
	stbi.image_free(data)
	return texture, true
}