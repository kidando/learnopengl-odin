package main

import "core:fmt"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import "core:math"
import glm "core:math/linalg/glsl"


CameraMovement::enum{
	FORWARD,
	BACKWARD,
	LEFT,
	RIGHT
}

Camera::struct{
	position:glm.vec3,
	front:glm.vec3,
	up:glm.vec3,
	right:glm.vec3,
	worldUp:glm.vec3,
	yaw:f32,
	pitch:f32,
	movementSpeed:f32,
	mouseSensitivity:f32,
	zoom:f32
}

CAMERA_DEFAULT_YAW:f32:-90.0
CAMERA_DEFAULT_PITCH:f32:0.0
CAMERA_DEFAULT_SPEED:f32:2.5
CAMERA_DEFAULT_SENSITIVITY:f32:0.1
CAMERA_DEFAULT_ZOOM:f32:45.0

camera_init::proc "c"(camera:^Camera,
	position:glm.vec3 = {0.0,0.0,0.0},
	up:glm.vec3 = {0.0,1.0,0.0},
	yaw:f32 = CAMERA_DEFAULT_YAW,
	pitch:f32 = CAMERA_DEFAULT_PITCH,
	front:glm.vec3 = {0.0,0.0,-1.0},
	movementSpeed:f32 = CAMERA_DEFAULT_SPEED,
	mouseSensitivity:f32 = CAMERA_DEFAULT_SENSITIVITY,
	zoom:f32 = CAMERA_DEFAULT_ZOOM
){
	
	camera.position = position
	camera.worldUp = up
	camera.yaw = yaw
	camera.pitch = pitch
	camera.movementSpeed = movementSpeed
	camera.zoom = zoom
	camera.mouseSensitivity = mouseSensitivity
	camera_update_vectors(camera)
}

// returns the view matrix calculated using Euler Angles and the LookAt Matrix
camera_get_view_matrix::proc(camera:^Camera)->glm.mat4{
	return glm.mat4LookAt(camera.position, camera.position + camera.front, camera.up)
}

// processes input received from any keyboard-like input system. Accepts input parameter in the form of camera defined ENUM (to abstract it from windowing systems)
camera_process_keyboard::proc "c"(camera:^Camera, direction:CameraMovement, deltaTime:f32) {
	velocity:f32 = camera.movementSpeed * deltaTime
	if direction == .FORWARD{
		camera.position += camera.front * velocity
	}
	if direction == .BACKWARD{
		camera.position -= camera.front * velocity
	}
	if direction == .LEFT{
		camera.position -= camera.right * velocity
	}
	if direction == .RIGHT{
		camera.position += camera.right * velocity
	}
}

// processes input received from a mouse input system. Expects the offset value in both the x and y direction.
camera_process_mouse_movement::proc "c"(camera:^Camera, xoffset:f32, yoffset:f32, constrainPitch:bool = true) {

	camera.yaw += xoffset * camera.mouseSensitivity
	camera.pitch += yoffset * camera.mouseSensitivity

	// make sure that when pitch is out of bounds, screen doesn't get flipped
	if constrainPitch{
		if camera.pitch > 89.0{
			camera.pitch = 89.0
		}
		if camera.pitch < -89.0{
			camera.pitch = -89.0
		}
	}

	// update Front, Right and Up Vectors using the updated Euler angles
	camera_update_vectors(camera)
}

// processes input received from a mouse scroll-wheel event. Only requires input on the vertical wheel-axis
camera_process_mouse_scroll::proc "c"(camera:^Camera, yoffset:f32){
	camera.zoom -= yoffset
	if camera.zoom < 1.0{
		camera.zoom = 1.0
	}
	if camera.zoom > 45.0{
		camera.zoom = 45.0
	}
}

// calculates the front vector from the Camera's (updated) Euler Angles
camera_update_vectors::proc "c"(camera:^Camera){
	// calculate the new Front vector
	front:glm.vec3
	front.x = math.cos_f32(glm.radians_f32(camera.yaw)) * math.cos_f32(glm.radians_f32(camera.pitch))
	front.y = math.sin_f32(glm.radians_f32(camera.pitch))
	front.z = math.sin_f32(glm.radians_f32(camera.yaw)) * math.cos_f32(glm.radians_f32(camera.pitch))
	camera.front = glm.normalize(front)
	// also re-calculate the Right and Up vector
	camera.right = glm.normalize(glm.cross_vec3(camera.front, camera.worldUp))// normalize the vectors, because their length gets closer to 0 the more you look up or down which results in slower movement.
	camera.up = glm.normalize(glm.cross_vec3(camera.right, camera.front))
}