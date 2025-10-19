package main

import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import "core:fmt"

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

	// glad: load all OpenGL function pointers
    // ---------------------------------------
	gl.load_up_to(3, 3, proc(p: rawptr, name: cstring) {
		(^rawptr)(p)^ = glfw.GetProcAddress(name)
	})

	// configure global opengl state
    // -----------------------------
	// OpenGL state
    // ------------
    gl.Enable(gl.CULL_FACE)
    gl.Enable(gl.BLEND) // Comment this out to the rendered quads
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	return true
}