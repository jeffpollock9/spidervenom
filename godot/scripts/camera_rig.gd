class_name CameraRig
extends Node3D
## Over-the-shoulder third-person camera. The mouse turns it; a spring arm keeps it out of walls.

const SENSITIVITY := 0.0028

var target: Node3D
var height := 2.0        # how far above the target's feet the camera looks
var shoulder := 0.9      # sideways offset, for an over-the-shoulder view
var yaw := -PI / 2      # start looking down the street (+X)
var pitch := -0.18
var shake := 0.0
var camera: Camera3D
var arm: SpringArm3D
var _pitch_node: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	_pitch_node = Node3D.new()
	add_child(_pitch_node)
	arm = SpringArm3D.new()
	arm.spring_length = 6.5
	arm.margin = 0.3
	arm.collision_mask = 1
	var probe := SphereShape3D.new()
	probe.radius = 0.3
	arm.shape = probe
	_pitch_node.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 900.0
	arm.add_child(camera)
	camera.current = true


func exclude(body: CollisionObject3D) -> void:
	arm.add_excluded_object(body.get_rid())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		yaw -= m.relative.x * SENSITIVITY
		pitch = clamp(pitch - m.relative.y * SENSITIVITY, -1.3, 0.75)


func face_dir(dir: Vector3) -> void:
	yaw = atan2(-dir.x, -dir.z)


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func right() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


func follow(dt: float, snap := false) -> void:
	if target == null:
		return
	var goal := target.global_position + Vector3(0, height, 0)
	global_position = goal if snap else global_position.lerp(goal, min(1.0, 14.0 * dt))
	rotation = Vector3(0, yaw, 0)
	_pitch_node.rotation = Vector3(pitch, 0, 0)
	camera.h_offset = shoulder + _rng.randf_range(-1, 1) * shake
	camera.v_offset = _rng.randf_range(-1, 1) * shake
	shake = max(0.0, shake - 3.0 * dt)


func aim_point(exclude_rid: RID) -> Vector3:
	## Where the crosshair (screen centre) points in the world.
	var centre := camera.get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(centre)
	var dir := camera.project_ray_normal(centre)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 250.0, 1 | 16, [exclude_rid])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else origin + dir * 250.0


func aim_dir() -> Vector3:
	return -camera.global_basis.z
