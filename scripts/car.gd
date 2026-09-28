extends Node3D
class_name KartCar

var velocity := Vector3.ZERO
var speed := 0.0
var steering := 0.0
var max_speed := 28.0
var acceleration := 24.0
var braking := 36.0
var grip := 7.0
var boost_time := 0.0
var ai := false
var ai_target := 0
var waypoints: Array[Vector3] = []
var body: Node3D
var wheels: Array[Node3D] = []
var visual: Node3D
var driver: Node3D
var color := Color(0.2,0.65,1.0)

func build(p_color: Color, driver_name: String) -> void:
	color = p_color
	visual = Node3D.new()
	add_child(visual)
	body = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8,0.55,3.1)
	body.mesh = bm
	body.material_override = mat(color)
	body.position.y = 0.55
	visual.add_child(body)
	var nose := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(1.45,0.35,1.0)
	nose.mesh = nm
	nose.material_override = mat(color.lightened(0.18))
	nose.position = Vector3(0,0.82,1.0)
	visual.add_child(nose)
	var seat := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.35
	sm.bottom_radius = 0.42
	sm.height = 0.75
	seat.mesh = sm
	seat.material_override = mat(Color(0.06,0.07,0.1))
	seat.position = Vector3(0,1.0,-0.15)
	visual.add_child(seat)
	driver = MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.42
	dm.height = 0.84
	driver.mesh = dm
	driver.material_override = mat(Color(0.96,0.72,0.52))
	driver.position = Vector3(0,1.52,-0.1)
	visual.add_child(driver)
	for x in [-0.82,0.82]:
		for z in [-1.02,1.02]:
			var w := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.27
			wm.bottom_radius = 0.27
			wm.height = 0.18
			wm.radial_segments = 12
			w.mesh = wm
			w.rotation_degrees = Vector3(0,0,90)
			w.position = Vector3(x,0.34,z)
			w.material_override = mat(Color(0.025,0.03,0.04))
			visual.add_child(w)
			wheels.append(w)
	var label := Label3D.new()
	label.text = driver_name
	label.font_size = 32
	label.modulate = Color(1,1,1,0.92)
	label.position.y = 2.15
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.72
	return m

func set_ai(points: Array[Vector3]) -> void:
	ai = true
	waypoints = points
	ai_target = 0

func give_boost(seconds: float) -> void:
	boost_time = max(boost_time, seconds)

func _physics_process(delta: float) -> void:
	if ai:
		drive_ai(delta)
	else:
		drive_player(delta)
	for w in wheels:
		w.rotate_x(-speed * delta * 1.9)
	if visual:
		visual.rotation.z = lerp(visual.rotation.z, -steering * 0.11, delta * 8.0)
		visual.position.y = sin(Time.get_ticks_msec() * 0.008 + position.x) * 0.025
	if boost_time > 0.0:
		boost_time -= delta
		max_speed = 42.0
	else:
		max_speed = 28.0

func drive_player(delta: float) -> void:
	var throttle := Input.get_action_strength("accelerate")
	var brake := Input.get_action_strength("brake")
	steering = Input.get_axis("steer_left","steer_right")
	if throttle > 0.0:
		speed = move_toward(speed,max_speed,acceleration*delta)
	elif brake > 0.0:
		speed = move_toward(speed,0.0,braking*delta)
	else:
		speed = move_toward(speed,0.0,7.0*delta)
	if Input.is_action_just_pressed("boost"):
		give_boost(1.8)
	velocity = -global_transform.basis.z * speed
	rotate_y(-steering * delta * (1.7 + speed * 0.045))
	global_position += velocity * delta

func drive_ai(delta: float) -> void:
	if waypoints.is_empty():
		return
	var target := waypoints[ai_target]
	var to_target := target - global_position
	if to_target.length() < 5.0:
		ai_target = (ai_target + 1) % waypoints.size()
		target = waypoints[ai_target]
	var local_target := global_transform.basis.inverse() * (target - global_position)
	steering = clamp(local_target.x / 8.0,-1.0,1.0)
	speed = move_toward(speed,max_speed * 0.82,acceleration*delta)
	rotate_y(-steering * delta * (1.3 + speed * 0.035))
	velocity = -global_transform.basis.z * speed
	global_position += velocity * delta
