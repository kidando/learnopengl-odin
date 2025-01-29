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

// utility uniform functions
// ------------------------------------------------------------------------
shader_set_bool::proc(shaderProgram:u32, name:cstring, value:bool){
	gl.Uniform1i(gl.GetUniformLocation(shaderProgram, name), i32(value))
}

shader_set_int::proc(shaderProgram:u32, name:cstring, value:i32){
	gl.Uniform1i(gl.GetUniformLocation(shaderProgram, name), value)
}

shader_set_float::proc(shaderProgram:u32, name:cstring, value:f32){
	gl.Uniform1f(gl.GetUniformLocation(shaderProgram, name), value)
}

shader_set_vec2_vec::proc(shaderProgram:u32, name:cstring, value:[^]f32){
	gl.Uniform2fv(gl.GetUniformLocation(shaderProgram, name), 1, value)
}
shader_set_vec2_f32::proc(shaderProgram:u32, name:cstring, val0:f32, val1:f32){
	gl.Uniform2f(gl.GetUniformLocation(shaderProgram, name), val0, val1)
}

shader_set_vec3_vec::proc(shaderProgram:u32, name:cstring, value:[^]f32){
	gl.Uniform3fv(gl.GetUniformLocation(shaderProgram, name), 1, value)
}
shader_set_vec3_f32::proc(shaderProgram:u32, name:cstring, val0:f32, val1:f32, val2:f32){
	gl.Uniform3f(gl.GetUniformLocation(shaderProgram, name), val0, val1, val2)
}

shader_set_vec4_vec::proc(shaderProgram:u32, name:cstring, value:[^]f32){
	gl.Uniform4fv(gl.GetUniformLocation(shaderProgram, name), 1, value)
}
shader_set_vec4_f32::proc(shaderProgram:u32, name:cstring, val0:f32, val1:f32, val2:f32, val3:f32){
	gl.Uniform4f(gl.GetUniformLocation(shaderProgram, name), val0, val1, val2, val3)
}

shader_set_mat2::proc(shaderProgramId:u32, name:cstring, transform_value:[^]f32){
	gl.UniformMatrix2fv(gl.GetUniformLocation(shaderProgramId, name), 1, gl.FALSE, transform_value)
}
shader_set_mat3::proc(shaderProgramId:u32, name:cstring, transform_value:[^]f32){
	gl.UniformMatrix3fv(gl.GetUniformLocation(shaderProgramId, name), 1, gl.FALSE, transform_value)
}
shader_set_mat4::proc(shaderProgramId:u32, name:cstring, transform_value:[^]f32){
	gl.UniformMatrix4fv(gl.GetUniformLocation(shaderProgramId, name), 1, gl.FALSE, transform_value)
}