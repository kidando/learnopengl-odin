package main

import "core:strings"
import ai "shared:odin-assimp"

assimp_string_to_odin_string :: proc(_ai_str:^ ai.String) -> string {
	return strings.string_from_ptr(&_ai_str.data[0], int(_ai_str.length))
}

