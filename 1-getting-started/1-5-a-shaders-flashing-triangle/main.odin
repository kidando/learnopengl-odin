package main
/*
CHAPTER: 1-5-a SHADERS (FLASHING TRIANGLE)
TUTORIAL: https://learnopengl.com/Getting-started/Shaders
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/1.getting_started/3.1.shaders_uniform/shaders_uniform.cpp
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
void main()
{
	gl_Position = vec4(aPos, 1.0);
}`
fragmentShaderSource:cstring = `#version 330 core
out vec4 FragColor;
uniform vec4 ourColor;
void main()
{
	FragColor = ourColor;
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
		0.5, -0.5, 0.0,  // bottom right
        -0.5, -0.5, 0.0,  // bottom left
         0.0,  0.5, 0.0   // top  
	}
	
	VBO, VAO:u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	// bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
	gl.BindVertexArray(VAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	/*
	The following line is slightly different from it's C++ counterpart. 
	That is due to how Odin is different from the language. 
	Instead of sizeof(vertices) we take the size_of(f32) or single float type and 
	multiply it to the number of elements in the array
	Why? Because under the hood vertices is a slice
	Raw_Slice :: struct {
		data: rawptr,
		len:  int,
	}
	So even the next parameter which just takes vertices has to instead be raw_data(vertices)
	*/
	gl.BufferData(gl.ARRAY_BUFFER,size_of(f32)*len(vertices), raw_data(vertices), gl.STATIC_DRAW)
	/*
	cast(uintptr)0 is the equivalent for (void*)0 in C++. The 0 means the attribute data starts at the beginning of the buffer. It is of type "pointer" but in this case it is a void pointer which we cast type cast on 0.
	*/
	gl.VertexAttribPointer(0,3,gl.FLOAT, gl.FALSE,3 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)

	// You can unbind the VAO afterwards so other VAO calls won't accidentally modify this VAO, but this rarely happens. Modifying other
    // VAOs requires a call to glBindVertexArray anyways so we generally don't unbind VAOs (nor VBOs) when it's not directly necessary.
    // glBindVertexArray(0);


    // bind the VAO (it was already bound, but just to demonstrate): seeing as we only have a single VAO we can 
    // just bind it beforehand before rendering the respective triangle; this is another approach.
	gl.BindVertexArray(VAO)

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

		// be sure to activate the shader before any calls to glUniform
		gl.UseProgram(shaderProgram)
		
		// update shader uniform
		timeValue:f64 = glfw.GetTime()
		greenValue:f32 = f32((math.sin_f32(f32(timeValue))/2.0)+0.5)
		vertexColorLocation:i32 = gl.GetUniformLocation(shaderProgram, "ourColor")
		gl.Uniform4f(vertexColorLocation, 0.0, greenValue,0.0,1.0)

		// render the triangle
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

/* The "c" is a calling convention that just says that this function "framebuffer_size_callback"
* should be treated like a C-language procedure/function. This is often done in Odin when
* interfacing with C-libraries to ensure function compatibility
*/
framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
}

processInput::proc(window:glfw.WindowHandle){
	if glfw.GetKey(window, glfw.KEY_ESCAPE)==glfw.PRESS{
		glfw.SetWindowShouldClose(window, true)
	}
}