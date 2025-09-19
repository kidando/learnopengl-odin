package main
/*
CHAPTER: 6-2 IBL Irradiance
TUTORIAL: https://learnopengl.com/PBR/IBL/Specular-IBL
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/6.pbr/2.1.2.ibl_irradiance/ibl_irradiance.cpp
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
SCR_WIDTH:i32:1280
SCR_HEIGHT:i32:720

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


	pbrShader, pbrShaderOk := shader_init("./shaders/pbr.vs","./shaders/pbr.fs")
	if !pbrShaderOk{
		return
	}
	equirectangularToCubemapShader, equirectangularToCubemapShaderOk := shader_init("./shaders/cubemap.vs","./shaders/equirectangular_to_cubemap.fs")
	if !equirectangularToCubemapShaderOk{
		return
	}
	irradianceShader, irradianceShaderOk := shader_init("./shaders/cubemap.vs","./shaders/irradiance_convolution.fs")
	if !irradianceShaderOk{
		return
	}
	backgroundShader, backgroundShaderOk := shader_init("./shaders/background.vs","./shaders/background.fs")
	if !backgroundShaderOk{
		return
	}
	
    camera_init(&mainCamera,{0.0,0.0,3.0})
	
    gl.UseProgram(pbrShader)
    shader_set_int(pbrShader,"irradianceMap",0)
    shader_set_vec3_f32(pbrShader,"albedo",0.5,0.0,0.0)
    shader_set_float(pbrShader,"ao",1.0)

    gl.ValidateProgram(backgroundShader)
    status: i32
    gl.GetProgramiv(backgroundShader, gl.VALIDATE_STATUS, &status)
    if status == 0 {
        log_length: i32
        gl.GetProgramiv(backgroundShader, gl.INFO_LOG_LENGTH, &log_length)
        if log_length > 0 {
            log := make([]u8, log_length)
            gl.GetProgramInfoLog(backgroundShader, log_length, nil, raw_data(log))
            fmt.println("Shader validation error:", string(log))
        }
    }

    gl.UseProgram(backgroundShader)
    shader_set_int(backgroundShader,"environmentMap",0)
	
	// lights
    // ------
    lightPositions:[]glm.vec3 = {
        {-10.0,  10.0, 10.0},
        {10.0,  10.0, 10.0},
        {-10.0, -10.0, 10.0},
        {10.0, -10.0, 10.0},
    }
    lightColors:[]glm.vec3 = {
        {300.0, 300.0, 300.0},
        {300.0, 300.0, 300.0},
        {300.0, 300.0, 300.0},
        {300.0, 300.0, 300.0}
    }
    nrRows :i32= 7
    nrColumns :i32= 7
    spacing:f32 = 2.5

    // pbr: setup framebuffer
    // ----------------------
    captureFBO:u32
    captureRBO:u32
    gl.GenFramebuffers(1, &captureFBO)
    gl.GenRenderbuffers(1, &captureRBO)

    gl.BindFramebuffer(gl.FRAMEBUFFER, captureFBO)
    gl.BindRenderbuffer(gl.RENDERBUFFER, captureRBO)
    gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT24, 512, 512)
    gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, captureRBO)

    // pbr: load the HDR environment map
    // ---------------------------------
    if !os.exists("./assets/textures/newport_loft.hdr") {
        fmt.println("HDR file does not exist!")
        return
    }
    stbi.set_flip_vertically_on_load(1)
    width, height, nrComponents:i32
    data: [^]f32 = stbi.loadf("./assets/textures/newport_loft.hdr", &width, &height, &nrComponents, 0)
    hdrTexture:u32
    if data != nil {
        gl.GenTextures(1, &hdrTexture)
        gl.BindTexture(gl.TEXTURE_2D, hdrTexture)
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB16F, width, height, 0, gl.RGB, gl.FLOAT, data) // note how we specify the texture's data value to be float

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

        stbi.image_free(data)
    } else {
        fmt.printfln("Failed to load texture:\n")
		fmt.println("Loading file error: %v", stbi.failure_reason())
    }

    // pbr: setup cubemap to render to and attach to framebuffer
    // ---------------------------------------------------------
    envCubemap:u32
    gl.GenTextures(1, &envCubemap)
    gl.BindTexture(gl.TEXTURE_CUBE_MAP, envCubemap)
    gl.GenerateMipmap(gl.TEXTURE_CUBE_MAP)
    for i:u32; i < 6; i += 1{
        gl.TexImage2D(gl.TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, gl.RGB16F, 512, 512, 0, gl.RGB, gl.FLOAT, nil)
    }
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    // pbr: set up projection and view matrices for capturing data onto the 6 cubemap face directions
    // ----------------------------------------------------------------------------------------------
    captureProjection:glm.mat4 = glm.mat4Perspective(glm.radians_f32(90),1.0,0.1,10.0)
    captureViews:[]glm.mat4 = {
        glm.mat4LookAt({0,0,0},{1.0,0.0,0.0},{0.0,-1.0,0.0}),
        glm.mat4LookAt({0,0,0},{-1.0,0.0,0.0},{0.0,-1.0,0.0}),
        glm.mat4LookAt({0,0,0},{0.0,1.0,0.0},{0.0,0.0,1.0}),
        glm.mat4LookAt({0,0,0},{0.0,-1.0,0.0},{0.0,0.0,-1.0}),
        glm.mat4LookAt({0,0,0},{0.0,0.0,1.0},{0.0,-1.0,0.0}),
        glm.mat4LookAt({0,0,0},{0.0,0.0,-1.0},{0.0,-1.0,0.0}),
    };
    // pbr: convert HDR equirectangular environment map to cubemap equivalent
    // ----------------------------------------------------------------------
    gl.UseProgram(equirectangularToCubemapShader)
    shader_set_int(equirectangularToCubemapShader,"equirectangularMap",0)
    shader_set_mat4(equirectangularToCubemapShader,"projection",&captureProjection[0][0])
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, hdrTexture)

    gl.Viewport(0, 0, 512, 512) // don't forget to configure the viewport to the capture dimensions.
    gl.BindFramebuffer(gl.FRAMEBUFFER, captureFBO)
    for i:u32; i < 6; i += 1 {
        shader_set_mat4(equirectangularToCubemapShader,"view",&captureViews[i][0][0])
        gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_CUBE_MAP_POSITIVE_X + i, envCubemap, 0)
        if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
            fmt.println("Framebuffer not complete!")
            return
        }
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        renderCube()
    }
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

    // Restore original viewport
    scrWidth, scrHeight := glfw.GetFramebufferSize(window)
    gl.Viewport(0, 0, scrWidth, scrHeight)

    // pbr: create an irradiance cubemap, and re-scale capture FBO to irradiance scale.
    // --------------------------------------------------------------------------------
    irradianceMap:u32
    gl.GenTextures(1, &irradianceMap)
    gl.BindTexture(gl.TEXTURE_CUBE_MAP, irradianceMap)
    for i:u32; i < 6; i += 1{
        gl.TexImage2D(gl.TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, gl.RGB16F, 32, 32, 0, gl.RGB, gl.FLOAT, nil)
    }
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    gl.BindFramebuffer(gl.FRAMEBUFFER, captureFBO)
    gl.BindRenderbuffer(gl.RENDERBUFFER, captureRBO)
    gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT24, 32, 32)

    // pbr: solve diffuse integral by convolution to create an irradiance (cube)map.
    // -----------------------------------------------------------------------------
    gl.UseProgram(irradianceShader)
    shader_set_int(irradianceShader, "environmentMap",0)
    shader_set_mat4(irradianceShader,"projection",&captureProjection[0][0])
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_CUBE_MAP, envCubemap)

    gl.Viewport(0, 0, 32, 32) // don't forget to configure the viewport to the capture dimensions.
    gl.BindFramebuffer(gl.FRAMEBUFFER, captureFBO)
    for i:u32; i < 6; i += 1{
        shader_set_mat4(irradianceShader,"view",&captureViews[i][0][0])
        gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_CUBE_MAP_POSITIVE_X + i, irradianceMap, 0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        renderCube()
    }
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

    // initialize static shader uniforms before rendering
    // --------------------------------------------------
    projection:glm.mat4 = glm.mat4Perspective(glm.radians(mainCamera.zoom),f32(SCR_WIDTH)/f32(SCR_HEIGHT),0.1,100)
    gl.UseProgram(pbrShader)
    shader_set_mat4(pbrShader,"projection",&projection[0][0])

    gl.UseProgram(backgroundShader)
    shader_set_mat4(backgroundShader,"projection",&projection[0][0])

    // then before rendering, configure the viewport to the original framebuffer's screen dimensions
    scrWidth, scrHeight = glfw.GetFramebufferSize(window)
    gl.Viewport(0, 0, scrWidth, scrHeight);

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
        gl.ClearColor(0.2, 0.3, 0.3, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		// render scene, supplying the convoluted irradiance map to the final shader.
        // ------------------------------------------------------------------------------------------
        gl.UseProgram(pbrShader)
        view:glm.mat4 = camera_get_view_matrix(&mainCamera)
        shader_set_mat4(pbrShader,"view",&view[0][0])
        shader_set_vec3_vec(pbrShader,"camPos",&mainCamera.position[0])

        // bind pre-computed IBL data
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_CUBE_MAP, irradianceMap)

        // render rows*column number of spheres with varying metallic/roughness values scaled by rows and columns respectively
        model:glm.mat4 = glm.mat4(1.0)
        for row:i32; row < nrRows; row +=1 {
            shader_set_float(pbrShader,"metallic",f32(row)/f32(nrRows))
            for col:i32; col < nrColumns; col += 1{
                // we clamp the roughness to 0.025 - 1.0 as perfectly smooth surfaces (roughness of 0.0) tend to look a bit off
                // on direct lighting.
                shader_set_float(
                    pbrShader,
                    "roughness",
                    glm.clamp(f32(col)/f32(nrColumns),0.05,1.0)
                )

                model = glm.mat4(1.0)
                model = glm.mat4Translate({
                    (f32(col) - f32(nrColumns/2)) * spacing,
                    (f32(row) - f32(nrRows/2)) * spacing,
                    -2.0
                })

                shader_set_mat4(pbrShader,"model",&model[0][0])
                normal_matrix := glm.mat3(glm.transpose(glm.inverse(model)))
                shader_set_mat3(pbrShader, "normalMatrix", &normal_matrix[0][0])
                renderSphere()
            }
        }


    
        // render light source (simply re-render sphere at light positions)
        // this looks a bit off as we use the same shader, but it'll make their positions obvious and 
        // keeps the codeprint small.
		for i in 0..<len(lightPositions) {
			newPos:glm.vec3 = lightPositions[i] + glm.vec3({
                math.sin(f32(glfw.GetTime())*5.0) * 5.0,
                0.0,
                0.0
            }
            )
            //newPos = lightPositions[i]
			pos_uniform_name := strings.clone_to_cstring(fmt.tprintf("lightPositions[%d]",i))
			shader_set_vec3_vec(pbrShader,pos_uniform_name,&newPos[0])

			color_uniform_name := strings.clone_to_cstring(fmt.tprintf("lightColors[%d]",i))
			shader_set_vec3_vec(pbrShader,color_uniform_name,&lightColors[i][0])

            model:glm.mat4 = glm.mat4(1.0)
			model = glm.mat4Translate(newPos)
			model *= glm.mat4Scale(glm.vec3(0.5))
			shader_set_mat4(pbrShader,"model",&model[0][0])
            normal_matrix := glm.mat3(glm.transpose(glm.inverse(model)))
            normal_array: [9]f32 = {
                normal_matrix[0, 0], normal_matrix[0, 1], normal_matrix[0, 2],
                normal_matrix[1, 0], normal_matrix[1, 1], normal_matrix[1, 2], 
                normal_matrix[2, 0], normal_matrix[2, 1], normal_matrix[2, 2],
            } 
            shader_set_mat3(pbrShader,"normalMatrix",&normal_array[0])
            renderSphere()
        }

        // render skybox (render as last to prevent overdraw)
        gl.DepthFunc(gl.LEQUAL) 
        gl.UseProgram(backgroundShader)
        skybox_view := glm.mat4(glm.mat3(view))
        shader_set_mat4(backgroundShader,"view",&skybox_view[0][0])
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_CUBE_MAP, envCubemap)
        //glBindTexture(GL_TEXTURE_CUBE_MAP, irradianceMap); // display irradiance map
        renderCube()
        gl.DepthFunc(gl.LESS)

        

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
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	} else {
		fmt.printfln("Failed to load texture: \n%v", _filepath)
		fmt.println("Loading file error: %v", stbi.failure_reason())
	}
	stbi.image_free(data)
	return _texture_id
}

// renders (and builds at first invocation) a sphere
// -------------------------------------------------
sphere_vao: u32
index_count: u32

renderSphere :: proc() {
    if sphere_vao == 0 {
        gl.GenVertexArrays(1, &sphere_vao)

        vbo, ebo: u32
        gl.GenBuffers(1, &vbo)
        gl.GenBuffers(1, &ebo)

        positions: [dynamic][3]f32
        uv: [dynamic][2]f32
        normals: [dynamic][3]f32
        indices: [dynamic]u32
        defer {
            delete(positions)
            delete(uv)
            delete(normals)
            delete(indices)
        }

        X_SEGMENTS :: 64
        Y_SEGMENTS :: 64
        PI :: math.PI

        for x in 0..=X_SEGMENTS {
            for y in 0..=Y_SEGMENTS {
                x_segment := f32(x) / f32(X_SEGMENTS)
                y_segment := f32(y) / f32(Y_SEGMENTS)
                x_pos := math.cos(x_segment * 2.0 * PI) * math.sin(y_segment * PI)
                y_pos := math.cos(y_segment * PI)
                z_pos := math.sin(x_segment * 2.0 * PI) * math.sin(y_segment * PI)

                append(&positions, [3]f32{x_pos, y_pos, z_pos})
                append(&uv, [2]f32{x_segment, y_segment})
                append(&normals, [3]f32{x_pos, y_pos, z_pos})
            }
        }

        odd_row := false
        for y in 0..<Y_SEGMENTS {
            if !odd_row {
                for x in 0..=X_SEGMENTS {
                    append(&indices, u32(y) * u32(X_SEGMENTS + 1) + u32(x))
                    append(&indices, u32(y + 1) * u32(X_SEGMENTS + 1) + u32(x))
                }
            } else {
                for x := X_SEGMENTS; x >= 0; x -= 1 {
                    append(&indices, u32(y + 1) * u32(X_SEGMENTS + 1) + u32(x))
                    append(&indices, u32(y) * u32(X_SEGMENTS + 1) + u32(x))
                }
            }
            odd_row = !odd_row
        }
        index_count = u32(len(indices))

        data: [dynamic]f32
        defer delete(data)
        for i in 0..<len(positions) {
            append(&data, positions[i].x, positions[i].y, positions[i].z)
            if len(normals) > 0 {
                append(&data, normals[i].x, normals[i].y, normals[i].z)
            }
            if len(uv) > 0 {
                append(&data, uv[i].x, uv[i].y)
            }
        }

        gl.BindVertexArray(sphere_vao)
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
        gl.BufferData(gl.ARRAY_BUFFER, len(data) * size_of(f32), raw_data(data), gl.STATIC_DRAW)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(u32), raw_data(indices), gl.STATIC_DRAW)
        
        stride :i32= (3 + 3 + 2) * size_of(f32)
        gl.EnableVertexAttribArray(0)
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, stride, cast(uintptr)0)
        gl.EnableVertexAttribArray(1)
        gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, stride, cast(uintptr)(3 * size_of(f32)))
        gl.EnableVertexAttribArray(2)
        gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, stride, cast(uintptr)(6 * size_of(f32)))
    }

    gl.BindVertexArray(sphere_vao)
    gl.DrawElements(gl.TRIANGLE_STRIP, i32(index_count), gl.UNSIGNED_INT, nil)
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