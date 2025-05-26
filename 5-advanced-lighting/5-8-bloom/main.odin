package main
/*
CHAPTER: 5-8 Bloom
TUTORIAL: https://learnopengl.com/Advanced-Lighting/HDR
SOURCE CODE IN C++: https://github.com/Hengle/LearnOpenGL-1/blob/master/src/5.advanced_lighting/6.hdr/hdr.cpp
*/

import "core:fmt"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import "core:math"
import "core:os" 
import "core:strings" 
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

bloom:i32 = 1
bloomKeyPressed:bool = false
exposure:f32 = 1.0


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
    shader, shaderOk := shader_init("./shaders/bloom.vs","./shaders/bloom.fs")
	if !shaderOk{
		return
	}
    shaderLight, shaderLightOk := shader_init("./shaders/bloom.vs","./shaders/light_box.fs")
	if !shaderLightOk{
		return
	}

	shaderBlur, shaderBlurOk := shader_init("./shaders/blur.vs","./shaders/blur.fs")
	if !shaderBlurOk{
		return
	}
	shaderBloomFinal, shaderBloomFinalOk := shader_init("./shaders/bloom_final.vs","./shaders/bloom_final.fs")
	if !shaderBloomFinalOk{
		return
	}
	camera_init(&mainCamera,{0.0,0.0,20.0})


	

	// load textures
    // -------------
    woodTexture:u32  = loadTexture("./assets/textures/wood.png", true) // note that we're loading the texture as an SRGB texture
    containerTexture:u32  = loadTexture("./assets/textures/container2.png", true) // note that we're loading the texture as an SRGB texture

	// configure (floating point) framebuffers
    // ---------------------------------------
    hdrFBO:u32;
    gl.GenFramebuffers(1, &hdrFBO)
    gl.BindFramebuffer(gl.FRAMEBUFFER, hdrFBO)
    // create 2 floating point color buffers (1 for normal rendering, other for brightness threshold values)
    colorBuffers:[2]u32
    gl.GenTextures(2, &colorBuffers[0])
	for i:int; i < 2; i += 1{
		gl.BindTexture(gl.TEXTURE_2D, colorBuffers[i])
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, SCR_WIDTH, SCR_HEIGHT, 0, gl.RGBA, gl.FLOAT, nil)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)  // we clamp to the edge as the blur filter would otherwise sample repeated texture values!
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        // attach texture to framebuffer
        gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0 + u32(i), gl.TEXTURE_2D, colorBuffers[i], 0)
	}
    
    // create and attach depth buffer (renderbuffer)
    rboDepth:u32
    gl.GenRenderbuffers(1, &rboDepth)
    gl.BindRenderbuffer(gl.RENDERBUFFER, rboDepth)
    gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT, SCR_WIDTH, SCR_HEIGHT)
    gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, rboDepth)
    // tell OpenGL which color attachments we'll use (of this framebuffer) for rendering 
    attachments:[2]u32 = { gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1 }
    gl.DrawBuffers(2, &attachments[0])
    // finally check if framebuffer is complete
    if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE{
		fmt.printfln("Framebuffer not complete!")
	}
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

    // ping-pong-framebuffer for blurring
    pingpongFBO:[2]u32
    pingpongColorbuffers:[2]u32
    gl.GenFramebuffers(2, &pingpongFBO[0])
    gl.GenTextures(2, &pingpongColorbuffers[0])
	for i:int; i < 2; i += 1{
		gl.BindFramebuffer(gl.FRAMEBUFFER, pingpongFBO[i])
        gl.BindTexture(gl.TEXTURE_2D, pingpongColorbuffers[i])
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, SCR_WIDTH, SCR_HEIGHT, 0, gl.RGBA, gl.FLOAT, nil)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE) // we clamp to the edge as the blur filter would otherwise sample repeated texture values!
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, pingpongColorbuffers[i], 0)
        // also check if framebuffers are complete (no need for depth buffer)
        if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE{
			fmt.printfln("Framebuffer not complete!")
		}
            
	}
   

    // lighting info
    // -------------
    // positions
    lightPositions:[4]glm.vec3
    lightPositions[0]= {0.0, 0.5,  1.5}
    lightPositions[1]= {-4.0, 0.5, -3.0}
    lightPositions[2]= {3.0, 0.5,  1.0}
    lightPositions[3]= {-0.8,  2.4, -1.0}

    // colors
    lightColors:[4]glm.vec3
	lightColors[0] = {5.0,   5.0,  5.0}
	lightColors[1] = {10.0,  0.0,  0.0}
	lightColors[2] = {0.0,   0.0,  15.0}
	lightColors[3] = {0.0,   5.0,  0.0}


    // shader configuration
    // --------------------
	gl.UseProgram(shader)
	shader_set_int(shader,"diffuseTexture",0)
	gl.UseProgram(shaderBlur)
	shader_set_int(shaderBlur,"image",0)
	gl.UseProgram(shaderBloomFinal)
	shader_set_int(shaderBloomFinal,"scene",0)
	shader_set_int(shaderBloomFinal,"bloomBlur",1)

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

		// 1. render scene into floating point framebuffer
        // -----------------------------------------------
		gl.BindFramebuffer(gl.FRAMEBUFFER, hdrFBO)
            gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
            projection:glm.mat4 = glm.mat4Perspective(
				glm.radians_f32(mainCamera.zoom),
				f32(SCR_WIDTH)/f32(SCR_HEIGHT),
				0.1,
				100
			)
			view:glm.mat4 = camera_get_view_matrix(&mainCamera)
            gl.UseProgram(shader)
            shader_set_mat4(shader,"projection",&projection[0][0])
			shader_set_mat4(shader,"view",&view[0][0])
            gl.ActiveTexture(gl.TEXTURE0)
            gl.BindTexture(gl.TEXTURE_2D, woodTexture)
            // set lighting uniforms
			for i in 0..<len(lightPositions){
				pos_uniform_name := strings.clone_to_cstring(fmt.tprintf("lights[%d].Position",i))
				shader_set_vec3_vec(shader,pos_uniform_name,&lightPositions[i][0])

				col_uniform_name := strings.clone_to_cstring(fmt.tprintf("lights[%d].Color",i))
				shader_set_vec3_vec(shader,col_uniform_name,&lightColors[i][0])
			}
			shader_set_vec3_vec(shader,"viewPos",&mainCamera.position[0])


			// create one large cube that acts as the floor
			model:glm.mat4 = glm.mat4(1.0)
			model = glm.mat4Translate({0.0,-1.0,0.0})
			model *= glm.mat4Scale({12.5,0.5,12.5})
			shader_set_mat4(shader,"model",&model[0][0])
			renderCube()
			// then create multiple cubes as the scenery
			gl.BindTexture(gl.TEXTURE_2D, containerTexture)
			model = glm.mat4(1.0)
			model = glm.mat4Translate({0.0,1.5,0.0})
			model *= glm.mat4Scale(glm.vec3(0.5))
			shader_set_mat4(shader,"model",&model[0][0])
			renderCube()

			model = glm.mat4(1.0)
			model = glm.mat4Translate({2.0,0.5,1.0})
			model *= glm.mat4Scale(glm.vec3(0.5))
			shader_set_mat4(shader,"model",&model[0][0])
			renderCube()

			model = glm.mat4(1.0)
			model = glm.mat4Translate({-1.0,-1.0,2.0})
			model = glm.mat4Rotate(
				glm.normalize_vec3({1.0,0.0,1.0}),
				glm.radians_f32(60.0)
			)
			shader_set_mat4(shader,"model",&model[0][0])
			renderCube()

			model = glm.mat4(1.0)
			model = glm.mat4Translate({0.0,2.7,4.0})
			model = glm.mat4Rotate(
				glm.normalize_vec3({1.0,0.0,1.0}),
				glm.radians_f32(23.0)
			)
			model *= glm.mat4Scale(glm.vec3(1.25))
			shader_set_mat4(shader,"model",&model[0][0])
			renderCube()

			model = glm.mat4(1.0)
			model = glm.mat4Translate({-2.0,1.0,-3.0})
			model = glm.mat4Rotate(
				glm.normalize_vec3({1.0,0.0,1.0}),
				glm.radians_f32(124.0)
			)
			shader_set_mat4(shader,"model",&model[0][0])
			renderCube()

			model = glm.mat4(1.0)
			model = glm.mat4Translate({-3.0,0.0,0.0})
			model *= glm.mat4Scale(glm.vec3(0.5))
			shader_set_mat4(shader,"model",&model[0][0])
			renderCube()

			// finally show all the light sources as bright cubes
			gl.UseProgram(shaderLight)
			shader_set_mat4(shaderLight,"projection",&projection[0][0])
			shader_set_mat4(shaderLight,"view",&view[0][0])

			for i:int; i < len(lightPositions); i += 1{
				model = glm.mat4(1.0)
				model = glm.mat4Translate(lightPositions[i])
				model *= glm.mat4Scale(glm.vec3(0.25))
				shader_set_mat4(shaderLight,"model",&model[0][0])
				shader_set_vec3_vec(shaderLight,"lightColor",&lightColors[i][0])
				renderCube()
			}

			
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

        // 2. blur bright fragments with two-pass Gaussian Blur 
        // --------------------------------------------------
        horizontal,first_iteration:bool = true, true
        amount:int = 10
		gl.UseProgram(shaderBlur)
		for i:int; i < amount; i += 1{
			alt:i32 = 0
			if horizontal{
				alt = 1
			}else{
				alt = 0
			}
			gl.BindFramebuffer(gl.FRAMEBUFFER, pingpongFBO[alt])
			shader_set_int(shaderBlur, "horizontal", alt)

			if first_iteration{
				gl.BindTexture(gl.TEXTURE_2D,  colorBuffers[1])
			}else{
				alt:int = 0
				if horizontal{
					alt = 0
				}else{
					alt = 1
				}
				gl.BindTexture(gl.TEXTURE_2D,  pingpongColorbuffers[alt])
			}

            renderQuad()
            horizontal = !horizontal
            if first_iteration{
				first_iteration = false
			}
		}
        
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

        // 3. now render floating point color buffer to 2D quad and tonemap HDR colors to default framebuffer's (clamped) color range
        // --------------------------------------------------------------------------------------------------------------------------
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
		gl.UseProgram(shaderBloomFinal)
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, colorBuffers[0])
        gl.ActiveTexture(gl.TEXTURE1)
		alt:int = 0
		if horizontal{
			alt = 0
		}else{
			alt = 1
		}
        gl.BindTexture(gl.TEXTURE_2D, pingpongColorbuffers[alt])
		shader_set_int(shaderBloomFinal,"bloom",bloom)
		shader_set_float(shaderBloomFinal,"exposure",exposure)

        renderQuad()

		if bloom == 1{
			fmt.printf("bloom: ON | ")
		}else{
			fmt.printf("bloom: OFF | ")
		}
		fmt.printfln("exposure: %d",exposure)
        

		
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

	if glfw.GetKey(window, glfw.KEY_SPACE) == glfw.PRESS && !bloomKeyPressed{
		if bloom == 1{
			bloom = 0
		}else{
			bloom = 1
		}
		bloomKeyPressed = true
	}

	if glfw.GetKey(window, glfw.KEY_SPACE) == glfw.RELEASE{
		bloomKeyPressed = false
	}

	if glfw.GetKey(window, glfw.KEY_Q) == glfw.PRESS{
		if exposure > 0.0{
			exposure -= 0.01
		}else{
			exposure = 0
		}
	}else if glfw.GetKey(window, glfw.KEY_E) == glfw.PRESS{
		exposure += 0.01
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

loadTexture::proc(_filepath:cstring, gammaCorrection:bool)->u32{
	_texture_id:u32
	gl.GenTextures(1, &_texture_id)

	width, height, nr_components: i32
	data: [^]u8 = stbi.load(_filepath, &width, &height, &nr_components, 0)

	if data != nil {
		dataFormat, internalFormat: u32
		if nr_components == 1 {
			internalFormat = gl.RED
		} else if nr_components == 3 {
			internalFormat = gammaCorrection ? gl.SRGB : gl.RGB
			dataFormat = gl.RGB
		} else if nr_components == 4 {
			internalFormat = gammaCorrection ? gl.SRGB_ALPHA : gl.RGBA
			dataFormat = gl.RGBA
		}
		gl.BindTexture(gl.TEXTURE_2D, _texture_id)
		gl.TexImage2D(
			gl.TEXTURE_2D,
			0,
			i32(internalFormat),
			width,
			height,
			0,
			dataFormat,
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

// renderCube() renders a 1x1 3D cube in NDC.
// -------------------------------------------------
cubeVAO, cubeVBO:u32
renderCube::proc(){
    // initialize (if necessary)
    if cubeVAO == 0 {
        vertices:[]f32 = {
            // back ace
            -1.0, -1.0, -1.0,  0.0,  0.0, -1.0, 0.0, 0.0, // bottom-let
             1.0,  1.0, -1.0,  0.0,  0.0, -1.0, 1.0, 1.0, // top-right
             1.0, -1.0, -1.0,  0.0,  0.0, -1.0, 1.0, 0.0, // bottom-right         
             1.0,  1.0, -1.0,  0.0,  0.0, -1.0, 1.0, 1.0, // top-right
            -1.0, -1.0, -1.0,  0.0,  0.0, -1.0, 0.0, 0.0, // bottom-let
            -1.0,  1.0, -1.0,  0.0,  0.0, -1.0, 0.0, 1.0, // top-let
            // ront ace
            -1.0, -1.0,  1.0,  0.0,  0.0,  1.0, 0.0, 0.0, // bottom-let
             1.0, -1.0,  1.0,  0.0,  0.0,  1.0, 1.0, 0.0, // bottom-right
             1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 1.0, 1.0, // top-right
             1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 1.0, 1.0, // top-right
            -1.0,  1.0,  1.0,  0.0,  0.0,  1.0, 0.0, 1.0, // top-let
            -1.0, -1.0,  1.0,  0.0,  0.0,  1.0, 0.0, 0.0, // bottom-let
            // let ace
            -1.0,  1.0,  1.0, -1.0,  0.0,  0.0, 1.0, 0.0, // top-right
            -1.0,  1.0, -1.0, -1.0,  0.0,  0.0, 1.0, 1.0, // top-let
            -1.0, -1.0, -1.0, -1.0,  0.0,  0.0, 0.0, 1.0, // bottom-let
            -1.0, -1.0, -1.0, -1.0,  0.0,  0.0, 0.0, 1.0, // bottom-let
            -1.0, -1.0,  1.0, -1.0,  0.0,  0.0, 0.0, 0.0, // bottom-right
            -1.0,  1.0,  1.0, -1.0,  0.0,  0.0, 1.0, 0.0, // top-right
            // right ace
             1.0,  1.0,  1.0,  1.0,  0.0,  0.0, 1.0, 0.0, // top-let
             1.0, -1.0, -1.0,  1.0,  0.0,  0.0, 0.0, 1.0, // bottom-right
             1.0,  1.0, -1.0,  1.0,  0.0,  0.0, 1.0, 1.0, // top-right         
             1.0, -1.0, -1.0,  1.0,  0.0,  0.0, 0.0, 1.0, // bottom-right
             1.0,  1.0,  1.0,  1.0,  0.0,  0.0, 1.0, 0.0, // top-let
             1.0, -1.0,  1.0,  1.0,  0.0,  0.0, 0.0, 0.0, // bottom-let     
            // bottom ace
            -1.0, -1.0, -1.0,  0.0, -1.0,  0.0, 0.0, 1.0, // top-right
             1.0, -1.0, -1.0,  0.0, -1.0,  0.0, 1.0, 1.0, // top-let
             1.0, -1.0,  1.0,  0.0, -1.0,  0.0, 1.0, 0.0, // bottom-let
             1.0, -1.0,  1.0,  0.0, -1.0,  0.0, 1.0, 0.0, // bottom-let
            -1.0, -1.0,  1.0,  0.0, -1.0,  0.0, 0.0, 0.0, // bottom-right
            -1.0, -1.0, -1.0,  0.0, -1.0,  0.0, 0.0, 1.0, // top-right
            // top ace
            -1.0,  1.0, -1.0,  0.0,  1.0,  0.0, 0.0, 1.0, // top-let
             1.0,  1.0 , 1.0,  0.0,  1.0,  0.0, 1.0, 0.0, // bottom-right
             1.0,  1.0, -1.0,  0.0,  1.0,  0.0, 1.0, 1.0, // top-right     
             1.0,  1.0,  1.0,  0.0,  1.0,  0.0, 1.0, 0.0, // bottom-right
            -1.0,  1.0, -1.0,  0.0,  1.0,  0.0, 0.0, 1.0, // top-let
            -1.0,  1.0,  1.0,  0.0,  1.0,  0.0, 0.0, 0.0  // bottom-let        
        }
        gl.GenVertexArrays(1, &cubeVAO)
        gl.GenBuffers(1, &cubeVBO)
        // fill buffer
        gl.BindBuffer(gl.ARRAY_BUFFER, cubeVBO)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(f32) * len(vertices), raw_data(vertices), gl.STATIC_DRAW)
        // link vertex attributes
        gl.BindVertexArray(cubeVAO)
        gl.EnableVertexAttribArray(0)
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), cast(uintptr)0)
        gl.EnableVertexAttribArray(1)
		gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), cast(uintptr)(3 * size_of(f32)))
        gl.EnableVertexAttribArray(2)
		gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * size_of(f32), cast(uintptr)(6 * size_of(f32)))
        gl.BindBuffer(gl.ARRAY_BUFFER, 0)
        gl.BindVertexArray(0)
    }
    // render Cube
    gl.BindVertexArray(cubeVAO)
    gl.DrawArrays(gl.TRIANGLES, 0, 36)
    gl.BindVertexArray(0)
}

// renderQuad() renders a 1x1 XY quad in NDC
// -----------------------------------------
quadVAO, quadVBO:u32
renderQuad::proc(){
	if quadVAO == 0
    {
        quadVertices:[]f32 = {
            // positions        // texture Coords
            -1.0,  1.0, 0.0, 0.0, 1.0,
            -1.0, -1.0, 0.0, 0.0, 0.0,
             1.0,  1.0, 0.0, 1.0, 1.0,
             1.0, -1.0, 0.0, 1.0, 0.0,
        };
        // setup plane VAO
        gl.GenVertexArrays(1, &quadVAO)
        gl.GenBuffers(1, &quadVBO)
        gl.BindVertexArray(quadVAO)
        gl.BindBuffer(gl.ARRAY_BUFFER, quadVBO)
        gl.BufferData(gl.ARRAY_BUFFER, size_of(f32) * len(quadVertices), raw_data(quadVertices), gl.STATIC_DRAW)
        gl.EnableVertexAttribArray(0)
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * size_of(f32), cast(uintptr)0)
        gl.EnableVertexAttribArray(1)
        gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), cast(uintptr)(3 * size_of(f32)))
    }
    gl.BindVertexArray(quadVAO)
    gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
    gl.BindVertexArray(0)
}