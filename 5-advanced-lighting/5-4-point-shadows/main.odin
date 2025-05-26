package main
/*
CHAPTER: 5-4-1 Point Shadows
TUTORIAL: https://learnopengl.com/Advanced-Lighting/Shadows/Point-Shadows
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/5.advanced_lighting/3.2.1.point_shadows/point_shadows.cpp
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

shadows:i32 = 1
shadowsKeyPressed:bool = false


main::proc(){
	// glfw: initialize and configure
    // ------------------------------
	if !renderer_init(){
		return
	}
    camera_init(&mainCamera,{0.0,0.0,3.0})

	stbi.set_flip_vertically_on_load(1)
	// build and compile our shader programs
    // ------------------------------------
    shader, shaderOk := shader_init("./shaders/point_shadows.vs","./shaders/point_shadows.fs")
	if !shaderOk{
		return
	}
    simpleDepthShader, simpleDepthShaderOk := shader_init("./shaders/point_shadows_depth.vs","./shaders/point_shadows_depth.fs","./shaders/point_shadows_depth.gs")
	if !simpleDepthShaderOk{
		return
	}

    // load textures
    // -------------
    woodTexture:u32 = loadTexture("./assets/textures/wood.png")

    // configure depth map FBO
    // -----------------------
	SHADOW_WIDTH::1024
    SHADOW_HEIGHT :: 1024
	depthMapFBO:u32
	gl.GenFramebuffers(1, &depthMapFBO)

	// create depth texture
	depthCubemap: u32
	gl.GenTextures(1, &depthCubemap)
    gl.BindTexture(gl.TEXTURE_CUBE_MAP, depthCubemap)
    for i:int; i < 6; i += 1{
         gl.TexImage2D(gl.TEXTURE_CUBE_MAP_POSITIVE_X + u32(i), 0, gl.DEPTH_COMPONENT, SHADOW_WIDTH, SHADOW_HEIGHT, 0, gl.DEPTH_COMPONENT, gl.FLOAT, nil)
    }
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE)
    // attach depth texture as FBO's depth buffer
    gl.BindFramebuffer(gl.FRAMEBUFFER, depthMapFBO)
    gl.FramebufferTexture(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, depthCubemap, 0)
    gl.DrawBuffer(gl.NONE)
    gl.ReadBuffer(gl.NONE)
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
   


	// shader configuration
    // --------------------
    gl.UseProgram(shader)
    shader_set_int(shader,"diffuseTexture",0)
    shader_set_int(shader,"depthMap",1)

	// lighting info
    // -------------
	lightPos:glm.vec3 = {0.0,0.0,0.0}

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

        // move light position over time
        lightPos.z = f32(math.sin(glfw.GetTime() * 0.5) * 3.0)

		// render
        // ------
        gl.ClearColor(0.1, 0.1, 0.1, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		// 0. create depth cubemap transformation matrices
        // -----------------------------------------------
		near_plane:f32 = 1.0 
        far_plane :f32 = 25.0
        shadowProj :glm.mat4 = glm.mat4Perspective(glm.radians_f32(90.0), f32(SHADOW_WIDTH)/f32(SHADOW_HEIGHT),near_plane, far_plane)
        shadowTransforms:[]glm.mat4 ={
            shadowProj * glm.mat4LookAt(lightPos, lightPos + {1.0,0.0,0.0}, {0.0,-1.0,0.0}),
            shadowProj * glm.mat4LookAt(lightPos, lightPos + {-1.0,0.0,0.0}, {0.0,-1.0,0.0}),
            shadowProj * glm.mat4LookAt(lightPos, lightPos + {0.0,1.0,0.0}, {0.0,0.0,1.0}),
            shadowProj * glm.mat4LookAt(lightPos, lightPos + {0.0,-1.0,0.0}, {0.0,0.0,-1.0}),
            shadowProj * glm.mat4LookAt(lightPos, lightPos + {0.0,0.0,1.0}, {0.0,-1.0,0.0}),
            shadowProj * glm.mat4LookAt(lightPos, lightPos + {0.0,0.0,-1.0}, {0.0,-1.0,0.0})
        }
        

		// 1. render scene to depth cubemap
        // --------------------------------
		gl.Viewport(0, 0, SHADOW_WIDTH, SHADOW_HEIGHT)
        gl.BindFramebuffer(gl.FRAMEBUFFER, depthMapFBO)
            gl.Clear(gl.DEPTH_BUFFER_BIT)
            gl.UseProgram(simpleDepthShader)
            for i:int; i < 6; i+= 1{
                uniform_name := strings.clone_to_cstring(fmt.tprint("shadowMatrices[%d]",i))
                defer delete(uniform_name)
                shader_set_mat4(simpleDepthShader,uniform_name,&shadowTransforms[i][0][0])
                
            }
            shader_set_float(simpleDepthShader, "far_plane", far_plane)
            shader_set_vec3_vec(simpleDepthShader, "lightPos", &lightPos[0])
            renderScene(simpleDepthShader)
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)


        // 2. render scene as normal using the generated depth/shadow map  
        // --------------------------------------------------------------
        gl.Viewport(0, 0, SCR_WIDTH, SCR_HEIGHT)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        gl.UseProgram(shader)
        projection:glm.mat4 = glm.mat4Perspective(
			glm.radians_f32(mainCamera.zoom),
			f32(SCR_WIDTH)/f32(SCR_HEIGHT),
			0.1,
			100
		)
        view:glm.mat4 = camera_get_view_matrix(&mainCamera)
		shader_set_mat4(shader,"projection",&projection[0][0])
		shader_set_mat4(shader,"view",&view[0][0])
        // set lighting uniforms
        shader_set_vec3_vec(shader,"lightPos",&lightPos[0])
        shader_set_vec3_vec(shader,"viewPos",&mainCamera.position[0])
        shader_set_int(shader,"shadows",shadows) // enable/disable shadows by pressing 'SPACE'
        shader_set_float(shader,"far_plane",far_plane)
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, woodTexture)
        gl.ActiveTexture(gl.TEXTURE1)
        gl.BindTexture(gl.TEXTURE_CUBE_MAP, depthCubemap)
        renderScene(shader)
     

        
		
		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
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

    if glfw.GetKey(window, glfw.KEY_SPACE) == glfw.PRESS && !shadowsKeyPressed{
        if shadows == 1{
            shadows = 0
        }else{
            shadows = 1
        }
        shadowsKeyPressed = true
    }

    if glfw.GetKey(window, glfw.KEY_SPACE) == glfw.RELEASE{
        shadowsKeyPressed = false
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


// renders the 3D scene
// --------------------
renderScene::proc(shader:u32)
{
    // room cube
    model:glm.mat4 = glm.mat4(1.0)
    model *= glm.mat4Scale(glm.vec3(5.0))
    shader_set_mat4(shader,"model",&model[0][0])
    gl.Disable(gl.CULL_FACE) // note that we disable culling here since we render 'inside' the cube instead of the usual 'outside' which throws off the normal culling methods.
    shader_set_int(shader, "reverse_normals", 1)// A small little hack to invert normals when drawing cube from the inside so lighting still works.
    renderCube()
    shader_set_int(shader, "reverse_normals",0)// and of course disable it
    gl.Enable(gl.CULL_FACE)

    // cubes
    model = glm.mat4(1.0)
    model = glm.mat4Translate({4.0,-3.5,0.0})
    model *= glm.mat4Scale(glm.vec3(0.5))
    shader_set_mat4(shader,"model",&model[0][0])
    renderCube()
    model = glm.mat4(1.0)
    model = glm.mat4Translate({2.0,3.0,1.0})
    model *= glm.mat4Scale(glm.vec3(0.75))
    shader_set_mat4(shader,"model",&model[0][0])
    renderCube()
    model = glm.mat4(1.0)
    model = glm.mat4Translate({-3.0,-1.0,0.0})
    model *= glm.mat4Scale(glm.vec3(0.5))
    shader_set_mat4(shader,"model",&model[0][0])
    renderCube()
    model = glm.mat4(1.0)
    model = glm.mat4Translate({-1.5,1.0,1.5})
    model *= glm.mat4Scale(glm.vec3(0.5))
    shader_set_mat4(shader,"model",&model[0][0])
    renderCube()
    model = glm.mat4(1.0)
    model = glm.mat4Translate({-1.5,2.0,-3.0})
    model *= glm.mat4Rotate({1.0,0.0,1.0},glm.radians_f32(60.0))
    model *= glm.mat4Scale(glm.vec3(0.75))
    shader_set_mat4(shader,"model",&model[0][0])
    renderCube()
}

// renderCube() renders a 1x1 3D cube in NDC.
// -------------------------------------------------
cubeVAO :u32 = 0
cubeVBO :u32 = 0
renderCube::proc(){
    // initialize (if necessary)
    if cubeVAO == 0{
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

