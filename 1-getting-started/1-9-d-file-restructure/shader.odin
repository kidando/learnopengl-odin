package main

import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import "core:fmt"

shader_init :: proc(_vertexShaderFilePath: string, _fragmentShaderFilePath: string)->(u32, bool) {
	// Load shader code from files
	vertexShaderSource, vertexOk := file_read_to_cstring(_vertexShaderFilePath)
	if !vertexOk {
		glfw.Terminate()
		return 0, false
	}
	fragmentShaderSource, fragmentOk := file_read_to_cstring(_fragmentShaderFilePath)
	if !fragmentOk {
		glfw.Terminate()
		return 0, false
	}

	// Vertex Shader Setup
	vertexShader: u32 = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertexShader, 1, &vertexShaderSource, nil)
	gl.CompileShader(vertexShader)
	// check for shader compile errors
	success: i32
	infoLog: [^]u8
	gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(vertexShader, 512, nil, infoLog)
		fmt.printfln("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n%v", infoLog)
		glfw.Terminate()
		return 0, false
	}

	// Fragment Shader Setup
	fragmentShader: u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragmentShader, 1, &fragmentShaderSource, nil)
	gl.CompileShader(fragmentShader)
	// check for shader compile errors
	gl.GetShaderiv(fragmentShader, gl.COMPILE_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(fragmentShader, 512, nil, infoLog)
		fmt.printfln("ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n%v", infoLog)
		glfw.Terminate()
		return 0, false
	}

	// Link shaders
	shaderProgram:u32 = gl.CreateProgram()
	gl.AttachShader(shaderProgram, vertexShader)
	gl.AttachShader(shaderProgram, fragmentShader)
	gl.LinkProgram(shaderProgram)
	// check for linking errors
	gl.GetProgramiv(shaderProgram, gl.LINK_STATUS, &success)
	if success == 0 {
		gl.GetProgramInfoLog(shaderProgram, 512, nil, infoLog)
		fmt.printfln("ERROR::SHADER::PROGRAM::LINKING_FAILED\n%v", infoLog)
		glfw.Terminate()
		return 0, false
	}
	gl.DeleteShader(vertexShader)
	gl.DeleteShader(fragmentShader)

	return shaderProgram, true
}

shader_set_mat4::proc(shaderProgramId:u32, name:cstring, transform_value:[^]f32){
	gl.UniformMatrix4fv(gl.GetUniformLocation(shaderProgramId, name), 1, gl.FALSE, transform_value);
}