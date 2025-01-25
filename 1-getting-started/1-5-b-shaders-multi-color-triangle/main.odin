package main
/*
CHAPTER: 1-5-b SHADERS (MULTI-COLOR TRIANGLE)
TUTORIAL: https://learnopengl.com/Getting-started/Shaders
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/1.getting_started/3.2.shaders_interpolation/shaders_interpolation.cpp
*/

import "core:fmt"
import gl "vendor:OpenGL" // GL loader similar to GLAD (if not GLAD itself but in ODIN)
import glfw "vendor:glfw"
import "core:math" // For math functions

// settings
SCR_WIDTH:i32:800
SCR_HEIGHT:i32:600

vertexShaderSource:cstring =`#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
out vec3 ourColor;
void main()
{
	gl_Position = vec4(aPos, 1.0);
	ourColor = aColor;
}`
fragmentShaderSource:cstring = `#version 330 core
out vec4 FragColor;
in vec3 ourColor;
void main()
{
	FragColor = vec4(ourColor, 1.0f);
}`

main::proc(){
	// glfw: initialize and configure
    // ------------------------------
	glfw.Init()
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR,3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR,3)
	glfw.WindowHint(glfw.OPENGL_PROFILE,glfw.OPENGL_CORE_PROFILE)

	// glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT,gl.TRUE) // If you are an APPLE

	// glfw window creation
    // --------------------
	window:glfw.WindowHandle = glfw.CreateWindow(SCR_WIDTH, SCR_HEIGHT, "LearnOpenGL", nil, nil)
	if window == nil{
		fmt.printfln("Failed to create GLFW window")
		glfw.Terminate()
		return
	}
	glfw.MakeContextCurrent(window)
	glfw.SetFramebufferSizeCallback(window, framebuffer_size_callback)

	// glad: load all OpenGL function pointers
    // ---------------------------------------
	gl.load_up_to(3, 3, proc(p: rawptr, name: cstring) {
		(^rawptr)(p)^ = glfw.GetProcAddress(name)
	})

	// build and compile our shader program
    // ------------------------------------
    // vertex shader
	vertexShader:u32 = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertexShader, 1, &vertexShaderSource, nil)
	gl.CompileShader(vertexShader)
	// check for shader compile errors
	success:i32
	infoLog:[^]u8
	gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &success)
	if success == 0{
		gl.GetShaderInfoLog(vertexShader,512, nil, infoLog)
		fmt.printfln("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n%v",infoLog)
		glfw.Terminate()
		return
	}
	 // fragment shader
	 fragmentShader:u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
	 gl.ShaderSource(fragmentShader, 1, &fragmentShaderSource, nil)
	 gl.CompileShader(fragmentShader)
	 // check for shader compile errors
	 gl.GetShaderiv(fragmentShader, gl.COMPILE_STATUS, &success)
	 if success == 0{
		gl.GetShaderInfoLog(fragmentShader, 512, nil, infoLog)
		fmt.printfln("ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n%v",infoLog)
		glfw.Terminate()
		return
	 }
	 // link shaders
	 shaderProgram:u32 = gl.CreateProgram()
	 gl.AttachShader(shaderProgram, vertexShader)
	 gl.AttachShader(shaderProgram, fragmentShader)
	 gl.LinkProgram(shaderProgram)
	 // check for linking errors
	 gl.GetProgramiv(shaderProgram, gl.LINK_STATUS, &success)
	 if success == 0{
		gl.GetProgramInfoLog(shaderProgram,512,nil,infoLog)
		fmt.printfln("ERROR::SHADER::PROGRAM::LINKING_FAILED\n%v",infoLog)
		glfw.Terminate()
		return
	 }
	 gl.DeleteShader(vertexShader)
	 gl.DeleteShader(fragmentShader)

	 // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
	vertices:[]f32 = {
		// positions     // colors
		0.5, -0.5, 0.0,  1.0, 0.0, 0.0,  // bottom right
        -0.5, -0.5, 0.0,  0.0, 1.0, 0.0,  // bottom left
        0.0,  0.5, 0.0,  0.0, 0.0, 1.0   // top 
	}
	
	VBO, VAO:u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	// bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
	gl.BindVertexArray(VAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(vertices), raw_data(vertices), gl.STATIC_DRAW)

	// position attribute
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,6 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)

	// position attribute
	gl.VertexAttribPointer(1,3,gl.FLOAT, gl.FALSE,6 * size_of(f32), cast(uintptr)(3*size_of(f32)))
	gl.EnableVertexAttribArray(1)

	// You can unbind the VAO afterwards so other VAO calls won't accidentally modify this VAO, but this rarely happens. Modifying other
    // VAOs requires a call to glBindVertexArray anyways so we generally don't unbind VAOs (nor VBOs) when it's not directly necessary.
    // glBindVertexArray(0);

    // as we only have a single shader, we could also just activate our shader once beforehand if we want to 
    gl.UseProgram(shaderProgram)

	// render loop
    // -----------
	for !glfw.WindowShouldClose(window){
		// input
        // -----
		processInput(window)

		// render
        // ------
        gl.ClearColor(0.2, 0.3, 0.3, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

		// render the triangle
        gl.BindVertexArray(VAO)
        gl.DrawArrays(gl.TRIANGLES, 0, 3)

		// glfw: swap buffers and poll IO events (keys pressed/released, mouse moved etc.)
        // -------------------------------------------------------------------------------
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
	// optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------
	gl.DeleteVertexArrays(1, &VAO)
	gl.DeleteBuffers(1, &VBO)
	gl.DeleteProgram(shaderProgram)

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
processInput::proc(window:glfw.WindowHandle){
	if glfw.GetKey(window, glfw.KEY_ESCAPE)==glfw.PRESS{
		glfw.SetWindowShouldClose(window, true)
	}
}