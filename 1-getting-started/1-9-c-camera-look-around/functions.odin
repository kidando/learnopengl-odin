package main
/*
Helper functions for rendering, file loading and camera controls
*/
import "core:os"
import "core:fmt"
import "core:strings"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"


file_read_to_cstring :: proc(_filePath: string)->(cstring, bool){
	data, ok := os.read_entire_file(_filePath, context.allocator)
	if !ok {
		fmt.printfln("Unable to read file: %s", _filePath)
		return  "",false
	}
	defer delete(data, context.allocator)
	cstr,err := strings.clone_to_cstring(string(data), context.allocator)
	if err != nil{
		fmt.printfln("Error in reading file: \n%v", err)
		return "", false
	}

	return cstr, true
}

renderer_init::proc()->bool{
	// glfw: initialize and configure
    // ------------------------------
	glfw.Init()
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR,OPENGL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR,OPENGL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE,glfw.OPENGL_CORE_PROFILE)

	// glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT,gl.TRUE) // If you are an APPLE

	// glfw window creation
    // --------------------
	window = glfw.CreateWindow(SCR_WIDTH, SCR_HEIGHT, "LearnOpenGL", nil, nil)
	if window == nil{
		fmt.printfln("Failed to create GLFW window")
		glfw.Terminate()
		return false
	}
	glfw.MakeContextCurrent(window)
	glfw.SetFramebufferSizeCallback(window, framebuffer_size_callback)
	glfw.SetCursorPosCallback(window, mouse_callback)
	glfw.SetScrollCallback(window, scroll_callback)
	// tell GLFW to capture our mouse
    glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)

	// glad: load all OpenGL function pointers
    // ---------------------------------------
	gl.load_up_to(3, 3, proc(p: rawptr, name: cstring) {
		(^rawptr)(p)^ = glfw.GetProcAddress(name)
	})

	// configure global opengl state
    // -----------------------------
	gl.Enable(gl.DEPTH_TEST)

	return true
}

shader_init::proc(_vertexShaderFilePath:string, _fragmentShaderFilePath:string)->bool{
	// Load shader code from files
	vertexShaderSource, vertexOk := file_read_to_cstring(_vertexShaderFilePath)
	if !vertexOk{
		glfw.Terminate()
		return false
	}
	fragmentShaderSource, fragmentOk := file_read_to_cstring(_fragmentShaderFilePath)
	if !fragmentOk{
		glfw.Terminate()
		return false
	}

	// Vertex Shader Setup
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
		return false
	}

	// Fragment Shader Setup
	fragmentShader:u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragmentShader, 1, &fragmentShaderSource, nil)
	gl.CompileShader(fragmentShader)
	// check for shader compile errors
	gl.GetShaderiv(fragmentShader, gl.COMPILE_STATUS, &success)
	if success == 0{
	   gl.GetShaderInfoLog(fragmentShader, 512, nil, infoLog)
	   fmt.printfln("ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n%v",infoLog)
	   glfw.Terminate()
	   return false
	}

	// Link shaders
	shaderProgram = gl.CreateProgram()
	gl.AttachShader(shaderProgram, vertexShader)
	gl.AttachShader(shaderProgram, fragmentShader)
	gl.LinkProgram(shaderProgram)
	// check for linking errors
	gl.GetProgramiv(shaderProgram, gl.LINK_STATUS, &success)
	if success == 0{
	   gl.GetProgramInfoLog(shaderProgram,512,nil,infoLog)
	   fmt.printfln("ERROR::SHADER::PROGRAM::LINKING_FAILED\n%v",infoLog)
	   glfw.Terminate()
	   return false
	}
	gl.DeleteShader(vertexShader)
	gl.DeleteShader(fragmentShader)

	return true
}