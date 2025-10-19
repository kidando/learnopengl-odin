package main
/*
CHAPTER: 7 Debugging
TUTORIAL: https://learnopengl.com/In-Practice/Debugging
*/

import "base:runtime"
import "core:fmt"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"


main :: proc() {
	/**
	To request a context for debugging in GLFW, you must do this before calling glfw.CreateWindow() function by adding the following line above it. 
	**/
	glfw.WindowHint(glfw.OPENGL_DEBUG_CONTEXT, true)


	flags: i32
	gl.GetIntegerv(gl.CONTEXT_FLAGS, &flags)
	if (flags & i32(gl.CONTEXT_FLAG_DEBUG_BIT)) != 0 {
		// initialize debug output
		gl.Enable(gl.DEBUG_OUTPUT)
		gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS)
		gl.DebugMessageCallback(glDebugOutput, nil)
		gl.DebugMessageControl(gl.DONT_CARE, gl.DONT_CARE, gl.DONT_CARE, 0, nil, gl.TRUE)

		/**
		Filter debug output (excerpt from the online tutorial)
		-----------------------------------------------------
		With glDebugMessageControl you can potentially filter the type(s) of errors you'd like to receive a message from. In our case we decided to not filter on any of the sources, types, or severity rates. If we wanted to only show messages from the OpenGL API, that are errors, and have a high severity, we'd configure it as follows:
		
		gl.DebugMessageControl(
			gl.DEBUG_SOURCE_API, 
			gl.DEBUG_TYPE_ERROR,
			gl.DEBUG_SEVERITY_HIGH,
			0, 
			nullptr, 
			gl.TRUE
		) 
		**/
	}
}


/**
This is the actual function we call for checking errors. It implements gl_check_error function utilizing odin macros for accessing the current file (or file name) and the line where this function is called using #file and #line
equivalent to macros in the original example in C i.e. __FILE__, __LINE__
**/
glCheckError :: proc() -> u32 {
	return gl_check_error(#file, #line)
}


/**
Prints a string description of the return ENUM value from gl.GetError()
Basically, prints error message instead of just error code.

NOTES: 
#force_inline is a directive used to that tells the compiler to do the implementation of the function where it is called. As opposed to "jump" to the function to implement it. Another way of describing it, is if you think of the following function

glCheckError::proc(){
	gl_check_error()
}

with the #force_inline directive, the gl_check_error() statement is sutitued with the actual code of the fuction

glCheckError::proc(){
	errorCode:u32
		
		for {
			errorCode = gl.GetError()
			......# and so on
}

**/
gl_check_error :: #force_inline proc(file: cstring, line: int) -> u32 {
	errorCode: u32

	for {
		errorCode = gl.GetError()
		if errorCode == gl.NO_ERROR {
			break
		}

		error: string

		switch errorCode {
		case gl.INVALID_ENUM:
			error = "INVALID_ENUM"
		case gl.INVALID_VALUE:
			error = "INVALID_VALUE"
		case gl.INVALID_OPERATION:
			error = "INVALID_OPERATION"
		case gl.STACK_OVERFLOW:
			error = "STACK_OVERFLOW"
		case gl.STACK_UNDERFLOW:
			error = "STACK_UNDERFLOW"
		case gl.OUT_OF_MEMORY:
			error = "OUT_OF_MEMORY"
		case gl.INVALID_FRAMEBUFFER_OPERATION:
			error = "INVALID_FRAMEBUFFER_OPERATION"
		}
		fmt.printfln("%s | %s (%d)", error, file, line)

	}
	return errorCode
}


/**
macros are widely used in C++ and APIENTRY is a macro that that specifies calling convention. Meaning the function is called in a very specific (or non-typical) way. In this case, it represents the __stdcall "directive" (I think it's a compiler directive)

So to translate that into odin, we simply create a function as a proc "c"()
**/

glDebugOutput :: proc "c" (
	source: u32,
	type: u32,
	id: u32,
	severity: u32,
	length: i32,
	message: cstring,
	userParam: rawptr,
) {

	if id == 131169 || id == 131185 || id == 131218 || id == 131204 {
		return
	}

	context = runtime.default_context()

	fmt.println("---------------")
	fmt.printf("Debug message (%d): %s\n", id, message)

	switch source {
	case gl.DEBUG_SOURCE_API:
		fmt.println("Source: API")
	case gl.DEBUG_SOURCE_WINDOW_SYSTEM:
		fmt.println("Source: Window System")
	case gl.DEBUG_SOURCE_SHADER_COMPILER:
		fmt.println("Source: Shader Compiler")
	case gl.DEBUG_SOURCE_THIRD_PARTY:
		fmt.println("Source: Third Party")
	case gl.DEBUG_SOURCE_APPLICATION:
		fmt.println("Source: Application")
	case gl.DEBUG_SOURCE_OTHER:
		fmt.println("Source: Other")
	}

	switch type {
	case gl.DEBUG_TYPE_ERROR:
		fmt.println("Type: Error")
	case gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR:
		fmt.println("Type: Deprecated Behaviour")
	case gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR:
		fmt.println("Type: Undefined Behaviour")
	case gl.DEBUG_TYPE_PORTABILITY:
		fmt.println("Type: Portability")
	case gl.DEBUG_TYPE_PERFORMANCE:
		fmt.println("Type: Performance")
	case gl.DEBUG_TYPE_MARKER:
		fmt.println("Type: Marker")
	case gl.DEBUG_TYPE_PUSH_GROUP:
		fmt.println("Type: Push Group")
	case gl.DEBUG_TYPE_POP_GROUP:
		fmt.println("Type: Pop Group")
	case gl.DEBUG_TYPE_OTHER:
		fmt.println("Type: Other")
	}

	switch severity {
	case gl.DEBUG_SEVERITY_HIGH:
		fmt.println("Severity: high")
	case gl.DEBUG_SEVERITY_MEDIUM:
		fmt.println("Severity: medium")
	case gl.DEBUG_SEVERITY_LOW:
		fmt.println("Severity: low")
	case gl.DEBUG_SEVERITY_NOTIFICATION:
		fmt.println("Severity: notification")
	}
	fmt.println()
}
