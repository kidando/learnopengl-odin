package main
/*
CHAPTER: 5-9 Deferred Shading
TUTORIAL: https://learnopengl.com/Advanced-Lighting/Deferred-Shading
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/5.advanced_lighting/8.1.deferred_shading/deferred_shading.cpp
*/

import "core:fmt"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import "core:math"
import "core:os" 
import "core:strings" 
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


	shaderGeometryPass, shaderGeometryPassOk := shader_init("./shaders/g_buffer.vs","./shaders/g_buffer.fs")
	if !shaderGeometryPassOk{
		return
	}

	shaderLightingPass, shaderLightingPassOk := shader_init("./shaders/deferred_shading.vs","./shaders/deferred_shading.fs")
	if !shaderLightingPassOk{
		return
	}
	shaderLightBox, shaderLightBoxOk := shader_init("./shaders/deferred_light_box.vs","./shaders/deferred_light_box.fs")
	if !shaderLightBoxOk{
		return
	}


	camera_init(&mainCamera,{0.0,0.0,5.0})

	ourModel:Model
	ai_load_gltf_model(&ourModel, "./assets/models/monkey/monkey.gltf")
	ai_setup_model_for_gpu(&ourModel)
	defer ai_destroy_model(&ourModel)

	objectPositions:[9]glm.vec3
	objectPositions[0] = {-3.0,  -0.5, -3.0}
	objectPositions[1] = { 0.0,  -0.5, -3.0}
	objectPositions[2] = { 3.0,  -0.5, -3.0}
	objectPositions[3] = {-3.0,  -0.5,  0.0}
	objectPositions[4] = {0.0,  -0.5,  0.0}
	objectPositions[5] = {3.0,  -0.5,  0.0}
	objectPositions[6] = {-3.0,  -0.5, 3.0}
	objectPositions[7] = {0.0,  -0.5,  3.0}
	objectPositions[8] = {3.0,  -0.5,  3.0}

	// configure g-buffer framebuffer
    // ------------------------------
    gBuffer:u32
    gl.GenFramebuffers(1, &gBuffer)
    gl.BindFramebuffer(gl.FRAMEBUFFER, gBuffer)
    gPosition, gNormal, gAlbedoSpec:u32
    // position color buffer
    gl.GenTextures(1, &gPosition)
    gl.BindTexture(gl.TEXTURE_2D, gPosition)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, SCR_WIDTH, SCR_HEIGHT, 0, gl.RGBA, gl.FLOAT, nil)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, gPosition, 0)
    // normal color buffer
    gl.GenTextures(1, &gNormal)
    gl.BindTexture(gl.TEXTURE_2D, gNormal)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, SCR_WIDTH, SCR_HEIGHT, 0, gl.RGBA, gl.FLOAT, nil)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT1, gl.TEXTURE_2D, gNormal, 0)
    // color + specular color buffer
    gl.GenTextures(1, &gAlbedoSpec)
    gl.BindTexture(gl.TEXTURE_2D, gAlbedoSpec)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, SCR_WIDTH, SCR_HEIGHT, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT2, gl.TEXTURE_2D, gAlbedoSpec, 0)
    // tell OpenGL which color attachments we'll use (of this framebuffer) for rendering 
    attachments := []u32{gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1, gl.COLOR_ATTACHMENT2}
    gl.DrawBuffers(i32(len(attachments)), raw_data(attachments))


    gl.DrawBuffers(3, &attachments[0])
    // create and attach depth buffer (renderbuffer)
    rboDepth:u32
    gl.GenRenderbuffers(1, &rboDepth)
    gl.BindRenderbuffer(gl.RENDERBUFFER, rboDepth)
    gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT, SCR_WIDTH, SCR_HEIGHT)
    gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, rboDepth)
    // finally check if framebuffer is complete
    if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE{
        fmt.printf("Framebuffer not complete")
    }
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

    // lighting info
    // -------------
    NR_LIGHTS:u32: 32
    lightPositions:[dynamic]glm.vec3
    lightColors:[dynamic]glm.vec3
    defer {
        delete(lightPositions)
        delete(lightColors)
    }
    for i:u32; i < NR_LIGHTS; i+=1{
        // calculate slightly random offsets
        xPos:f32 = (f32(rand.int31_max(100)) / 100.0) * 6.0 - 3.0
        yPos:f32 = (f32(rand.int31_max(100))/ 100.0) * 6.0 - 4.0
        zPos:f32 = (f32(rand.int31_max(100)) / 100.0) * 6.0 - 3.0
        pos:glm.vec3 = {xPos, yPos, zPos}
        append(&lightPositions,pos)
        // also calculate random color
        rColor:f32 = (f32(rand.int31_max(100)) / 200.0) + 0.5 // between 0.5 and 1.0
        gColor:f32 = (f32(rand.int31_max(100)) / 200.0) + 0.5 // between 0.5 and 1.0
        bColor:f32 = (f32(rand.int31_max(100)) / 200.0) + 0.5// between 0.5 and 1.0
        color:glm.vec3 = {rColor, gColor, bColor}
        append(&lightColors,color)
    }

    // shader configuration
    // --------------------
    gl.UseProgram(shaderLightingPass)
    shader_set_int(shaderLightingPass,"gPosition",0)
    shader_set_int(shaderLightingPass,"gNormal",1)
    shader_set_int(shaderLightingPass,"gAlbedoSpec",2)


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
        gl.ClearColor(0.0, 0.0, 0.0, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        // 1. geometry pass: render scene's geometry/color data into gbuffer
        // -----------------------------------------------------------------
        gl.BindFramebuffer(gl.FRAMEBUFFER, gBuffer)
            gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
            projection:glm.mat4 = glm.mat4Perspective(
				glm.radians_f32(mainCamera.zoom),
				f32(SCR_WIDTH)/f32(SCR_HEIGHT),
				0.1,
				100
			)
            view:glm.mat4 = camera_get_view_matrix(&mainCamera)
            model:glm.mat4 = glm.mat4(1.0)
            gl.UseProgram(shaderGeometryPass)
            shader_set_mat4(shaderGeometryPass,"projection",&projection[0][0])
			shader_set_mat4(shaderGeometryPass,"view",&view[0][0])
            for i in 0..<len(objectPositions){
                model = glm.mat4(1.0)
                model = glm.mat4Translate(objectPositions[i])
                model *= glm.mat4Scale(glm.vec3(0.5))
                shader_set_mat4(shaderGeometryPass,"model",&model[0][0])
                ai_draw_model(&ourModel,shaderGeometryPass)
            }
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

        // 2. lighting pass: calculate lighting by iterating over a screen filled quad pixel-by-pixel using the gbuffer's content.
        // -----------------------------------------------------------------------------------------------------------------------
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        gl.UseProgram(shaderLightingPass)
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, gPosition)
        gl.ActiveTexture(gl.TEXTURE1)
        gl.BindTexture(gl.TEXTURE_2D, gNormal)
        gl.ActiveTexture(gl.TEXTURE2)
        gl.BindTexture(gl.TEXTURE_2D, gAlbedoSpec)
        // send light relevant uniforms
        for i in 0..<len(lightPositions){
            // shader_set_vec3_vec(shader,strings.clone_to_cstring(fmt.tprintf("lights[%d].Position",i)),&lightPositions[i][0])
            // shader_set_vec3_vec(shader,strings.clone_to_cstring(fmt.tprintf("lights[%d].Color",i)),&lightColors[i][0])
            // update attenuation parameters and calculate radius
            linear:f32:0.7
            quadratic:f32:1.8
            // shader_set_float(shaderLightingPass,strings.clone_to_cstring(fmt.tprintf("lights[%d].Position",i)),linear)
            // shader_set_float(shaderLightingPass,strings.clone_to_cstring(fmt.tprintf("lights[%d].Quadratic",i)),quadratic)

            pos_name := strings.clone_to_cstring(fmt.tprintf("lights[%d].Position", i))
            color_name := strings.clone_to_cstring(fmt.tprintf("lights[%d].Color", i))
            linear_name := strings.clone_to_cstring(fmt.tprintf("lights[%d].Linear", i))
            quadratic_name := strings.clone_to_cstring(fmt.tprintf("lights[%d].Quadratic", i))

            shader_set_vec3_vec(shaderLightingPass, pos_name, &lightPositions[i][0])
            shader_set_vec3_vec(shaderLightingPass, color_name, &lightColors[i][0])
            shader_set_float(shaderLightingPass, linear_name, linear)
            shader_set_float(shaderLightingPass, quadratic_name, quadratic)
        }
        shader_set_vec3_vec(shaderLightingPass,"viewPos",&mainCamera.position[0])
        // finally render quad
        renderQuad()

        // 2.5. copy content of geometry's depth buffer to default framebuffer's depth buffer
        // ----------------------------------------------------------------------------------
        gl.BindFramebuffer(gl.READ_FRAMEBUFFER, gBuffer)
        gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0) // write to default framebuffer
        // blit to default framebuffer. Note that this may or may not work as the internal formats of both the FBO and default framebuffer have to match.
        // the internal formats are implementation defined. This works on all of my systems, but if it doesn't on yours you'll likely have to write to the 		
        // depth buffer in another shader stage (or somehow see to match the default framebuffer's internal format with the FBO's internal format).
        gl.BlitFramebuffer(0, 0, SCR_WIDTH, SCR_HEIGHT, 0, 0, SCR_WIDTH, SCR_HEIGHT, gl.DEPTH_BUFFER_BIT, gl.NEAREST)
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

        // 3. render lights on top of scene
        // --------------------------------
        gl.UseProgram(shaderLightBox)
        shader_set_mat4(shaderLightBox,"projection",&projection[0][0])
        shader_set_mat4(shaderLightBox,"view",&view[0][0])
        for i in 0..<len(lightPositions){
            model = glm.mat4(1.0)
            model = glm.mat4Translate(lightPositions[i])
            model *= glm.mat4Scale(glm.vec3(0.125))
            shader_set_mat4(shaderLightBox,"model",&model[0][0])
            shader_set_vec3_vec(shaderLightBox,"lightColor",&lightColors[i][0])
            renderCube()
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