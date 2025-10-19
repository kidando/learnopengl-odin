package main
/*
CHAPTER: 8 Text Rendering
TUTORIAL: https://learnopengl.com/In-Practice/Text-Rendering
SOURCE CODE IN C++: https://learnopengl.com/code_viewer_gh.php?code=src/7.in_practice/2.text_rendering/text_rendering.cpp
*/

import "core:fmt"
import glm "core:math/linalg/glsl"
import FT "shared:freetype"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"

// Holds all state information relevant to a character as loaded using FreeType
Character :: struct {
	TextureID: u32, // ID handle of the glyph texture
	Size:      glm.ivec2, // Size of glyph
	Bearing:   glm.ivec2, // Offset from baseline to left/top of glyph
	Advance:   u32, // Horizontal offset to advance to next glyph
}

// settings
SCR_WIDTH: i32 : 800
SCR_HEIGHT: i32 : 600

OPENGL_MAJOR_VERSION :: 3
OPENGL_MINOR_VERSION :: 3

window: glfw.WindowHandle
Characters: map[rune]Character
VAO, VBO: u32


main :: proc() {
	// glfw: initialize and configure
	// ------------------------------
	if !renderer_init() {
		return
	}
	// build and compile our shader programs
	// ------------------------------------
	shader, shaderOk := shader_init("./shaders/text.vs", "./shaders/text.fs")
	if !shaderOk {
		return
	}

	projection: glm.mat4 = glm.mat4Ortho3d(0, f32(SCR_WIDTH), 0, f32(SCR_HEIGHT), -1, 1)
	gl.UseProgram(shader)
	shader_set_mat4(shader, "projection", &projection[0][0])

	// Free Type
	//-----------
	ft: FT.Library
	// All functions return a value different than 0 whenever an error occurred
	font_init_error := FT.init_free_type(&ft)
	if font_init_error != .Ok {
		fmt.printfln("ERROR::FREETYPE: Could not init FreeType Library")
		return
	}


	// load font as face
	face: FT.Face
	font_face_load_error := FT.new_face(ft, "./fonts/NunitoSans-Regular.ttf", 0, &face)

	if font_face_load_error != .Ok {
		fmt.println("ERROR::FREETYPE: Failed to load font")
		return
	}
	// set size to load glyphs as
	FT.set_pixel_sizes(face, 0, 48)

	// disable byte-alignment restriction
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

	// load first 128 characters of ASCII set
	for c: rune; c < 128; c += 1 {
		// Load character glyph
		loan_char_error := FT.load_char(face, u32(c), FT.Load_Flags{.Render})
		if loan_char_error != .Ok {
			fmt.println("ERROR::FREETYTPE: Failed to load Glyph")
			continue
		}
		// generate texture
		texture: u32
		gl.GenTextures(1, &texture)
		gl.BindTexture(gl.TEXTURE_2D, texture)
		gl.TexImage2D(
			gl.TEXTURE_2D,
			0,
			gl.RED,
			i32(face.glyph.bitmap.width),
			i32(face.glyph.bitmap.rows),
			0,
			gl.RED,
			gl.UNSIGNED_BYTE,
			face.glyph.bitmap.buffer,
		)
		// set texture options
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
		// now store character for later use
		character: Character = {
			TextureID = texture,
			Size      = {i32(face.glyph.bitmap.width), i32(face.glyph.bitmap.rows)},
			Bearing   = {face.glyph.bitmap_left, face.glyph.bitmap_top},
			Advance   = u32(face.glyph.advance.x),
		}
		// Debug: Check if texture has data
		if face.glyph.bitmap.width > 0 && face.glyph.bitmap.rows > 0 {
			fmt.printf(
				"Loaded '%c': %dx%d pixels, buffer: %p\n",
				c,
				face.glyph.bitmap.width,
				face.glyph.bitmap.rows,
				face.glyph.bitmap.buffer,
			)
		} else {
			fmt.printf("WARNING: '%c' has empty bitmap!\n", c)
		}
		Characters[c] = character
	}
	// Check that all characters are loaded
	fmt.printf("Loaded %d characters into the map\n", len(Characters))

	// Check if specific characters exist
	test_chars := "This"
	for c in test_chars {
		if ch, exists := Characters[c]; exists {
			fmt.printf(
				"Character '%c': texture=%d, size=%v, bearing=%v, advance=%d\n",
				c,
				ch.TextureID,
				ch.Size,
				ch.Bearing,
				ch.Advance,
			)
		} else {
			fmt.printf("Character '%c' NOT FOUND in map!\n", c)
		}
	}

	gl.BindTexture(gl.TEXTURE_2D, 0)

	FT.done_face(face)
	FT.done_free_type(ft)

	// configure VAO/VBO for texture quads
	// -----------------------------------
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	gl.BindVertexArray(VAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(f32) * 6 * 4, nil, gl.DYNAMIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)


	// render loop
	// -----------
	for !glfw.WindowShouldClose(window) {

		// input
		// -----
		processInput(window)

		// render
		// ------
		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		RenderText(shader, "This is sample text", 25.0, 25.0, 1.0, {0.5, 0.8, 0.2})
		RenderText(shader, "(C) LearnOpenGL.com", 540.0, 570.0, 0.5, {0.3, 0.7, 0.9})


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
processInput :: proc "c" (window: glfw.WindowHandle) {
	if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
		glfw.SetWindowShouldClose(window, true)
	}
}


// render line of text
// -------------------
RenderText :: proc(shader: u32, text: string, x: f32, y: f32, scale: f32, color: glm.vec3) {
	// activate corresponding render state	
	gl.UseProgram(shader)
	check_gl_error("Use program")

	shader_set_vec3_f32(shader, "textColor", color.x, color.y, color.z)
	check_gl_error("set uniform")

	gl.ActiveTexture(gl.TEXTURE0)
	check_gl_error("ActivateTexture")

	gl.BindVertexArray(VAO)
	check_gl_error("Bind VAO")

	// iterate through all characters
	new_x := x

	for c in text {
		ch := Characters[c]

		xpos: f32 = new_x + f32(ch.Bearing.x) * scale
		ypos: f32 = y - f32(ch.Size.y - ch.Bearing.y) * scale

		w: f32 = f32(ch.Size.x) * scale
		h: f32 = f32(ch.Size.y) * scale
		// update VBO for each character
		vertices: [6][4]f32 = {
			{xpos, ypos + h, 0.0, 0.0},
			{xpos, ypos, 0.0, 1.0},
			{xpos + w, ypos, 1.0, 1.0},
			{xpos, ypos + h, 0.0, 0.0},
			{xpos + w, ypos, 1.0, 1.0},
			{xpos + w, ypos + h, 1.0, 0.0},
		}
		// render glyph texture over quad
		gl.BindTexture(gl.TEXTURE_2D, ch.TextureID)
		check_gl_error("Bind Texture")

		// update content of VBO memory
		gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
		check_gl_error("Bind Buffer VBO")

		gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(vertices), &vertices[0][0])
		check_gl_error("Bind Buffer SubData")

		gl.BindBuffer(gl.ARRAY_BUFFER, 0)
		check_gl_error("UnBind ARRAY BUFFER")

		// render quad
		gl.DrawArrays(gl.TRIANGLES, 0, 6)
		check_gl_error("Draw Triangles")
		// now advance cursors for next glyph (note that advance is number of 1/64 pixels)
		new_x += f32(ch.Advance >> 6) * scale // bitshift by 6 to get value in pixels (2^6 = 64 (divide amount of 1/64th pixels by 64 to get amount of pixels)
	}
	gl.BindVertexArray(0)
	check_gl_error("UnBind VAO")
	
	gl.BindTexture(gl.TEXTURE_2D, 0)
	check_gl_error("UnBind Texture")
}


check_gl_error :: proc(location: string) {
	if error := gl.GetError(); error != gl.NO_ERROR {
		fmt.eprintf("OpenGL error at %s: %d\n", location, error)
	}
}
