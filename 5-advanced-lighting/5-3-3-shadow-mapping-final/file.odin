package main
/*
Helper functions for rendering, file loading and camera controls
*/
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"


file_read_to_cstring :: proc(_filePath: string) -> (cstring, bool) {
	data, ok := os.read_entire_file(_filePath, context.allocator)
	if !ok {
		fmt.printfln("Unable to read file: %s", _filePath)
		return "", false
	}
	defer delete(data, context.allocator)
	cstr, err := strings.clone_to_cstring(string(data), context.allocator)
	if err != nil {
		fmt.printfln("Error in reading file: \n%v", err)
		return "", false
	}

	return cstr, true
}

file_get_directory_from_path :: proc(file_path: string) -> string{
	return filepath.dir(file_path)
}
