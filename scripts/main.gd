extends Node3D

const TRACKS := [
	{"name":"SUNSET CIRCUIT","sky":Color("#526ebf"),"ground":Color("#4d8f57"),"road":Color("#30353f"),"accent":Color("#ffc34f"),"desc":"Fast corners and warm sunset scenery.","points":[Vector3(0,0,32),Vector3(28,0,28),Vector3(48,0,5),Vector3(42,0,-24),Vector3(15,0,-38),Vector3(-18,0,-35),Vector3(-46,0,-10),Vector3(-43,0,19),Vector3(-22,0,34)]},
	{"name":"CRYSTAL VALLEY","sky":Color("#8ac9e6"),"ground":Color("#6c9d62"),"road":Color("#4b535e"),"accent":Color("#71e6ff"),"desc":"Cool mountain roads with icy markers.","points":[Vector3(0,0,38),Vector3(35,0,32),Vector3(52,0,0),Vector3(33,0,-34),Vector3(0,0,-42),Vector3(-33,0,-34),Vector3(-52,0,0),Vector3(-35,0,32)]},
	{"name":"NEON HARBOR","sky":Color("#12152f"),"ground":Color("#1c2440"),"road":Color("#292f3a"),"accent":Color("#ff4bd4"),"desc":"Night racing surrounded by neon.","points":[Vector3(0,0,34),Vector3(25,0,31),Vector3(44,0,14),Vector3(44,0,-16),Vector3(18,0,-36),Vector3(-18,0,-36),Vector3(-44,0,-16),Vector3(-44,0,14),Vector3(-25,0,31)]},
	{"name":"SKY GARDEN","sky":Color("#7fc6f4"),"ground":Color("#69a66b"),"road":Color("#3f4a43"),"accent":Color("#e9f15f"),"desc":"Open garden roads and bright landmarks.","points":[Vector3(0,0,30),Vector3(22,0,26),Vector3(38,0,8),Vector3(30,0,-22),Vector3(8,0,-38),Vector3(-25,0,-30),Vector3(-40,0,-2),Vector3(-28,0,23)]}
]

var track_index := 0
var points: Array[Vector3] = []
var player: KartCar
var racers: Array[KartCar] = []
var race_camera: Camera3D
var race_ui: CanvasLayer
var menu_ui: Control
var status_label: Label
var lap_label: Label
var speed_label: Label
var time_label: Label
var track_label: Label
var countdown := 3.0
var elapsed := 0.0
var lap := 1
var next_checkpoint := 1
var total_laps := 3
var racing := false
var paused := false
var finished := false

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.screen_set_keep_on(true)
	build_world()
	build_menu()

func material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m

func build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = TRACKS[track_index].sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9,0.92,1.0)
	env.ambient_light_energy = 1.2
	world.environment = env
	add_child(world)
	points = TRACKS[track_index].points
	build_track()
	build_scenery()

func build_track() -> void:
	var data = TRACKS[track_index]
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(190,190)
	ground.mesh = gm
	ground.material_override = material(data.ground)
	add_child(ground)
	for i in points.size():
		var a := points[i]
		var b := points[(i+1) % points.size()]
		var mid := (a+b)*0.5
		var len := a.distance_to(b)
		var road := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(12,0.24,len+2)
		road.mesh = rm
		road.position = Vector3(mid.x,0.03,mid.z)
		road.look_at(Vector3(b.x,0.03,b.z),Vector3.UP)
		road.material_override = material(data.road)
		add_child(road)
		for side in [-1,1]:
			var curb := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(0.65,0.28,len+2)
			curb.mesh = cm
			curb.position = Vector3(mid.x+side*6.2,0.17,mid.z)
			curb.look_at(Vector3(b.x+side*6.2,0.17,b.z),Vector3.UP)
			curb.material_override = material(data.accent)
			add_child(curb)
	var line := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(12,0.05,1.2)
	line.mesh = lm
	line.position = points[0] + Vector3(0,0.15,0)
	line.material_override = material(Color(0.95,0.95,1.0))
	add_child(line)

func build_scenery() -> void:
	var data = TRACKS[track_index]
	for i in 36:
		var p := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.15
		cm.bottom_radius = 0.30
		cm.height = 2.8 + float(i%3)*0.4
		p.mesh = cm
		var a := float(i)*TAU/36.0
		var r := 58.0 + float(i%4)*7.0
		p.position = Vector3(cos(a)*r,cm.height*0.5,sin(a)*r)
		p.material_override = material(Color("#1c4a25") if i%2==0 else data.accent.darkened(0.2))
		add_child(p)

func style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s

func build_menu() -> void:
	menu_ui = Control.new()
	menu_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_ui)

	var camera := Camera3D.new()
	camera.position = points[0] + Vector3(0,8.0,19.0)
	add_child(camera)
	camera.current = true
	camera.look_at(points[0]+Vector3(0,1.2,0),Vector3.UP)

	var demo := KartCar.new()
	demo.build(Color("#38bdf8"),"NOVA")
	demo.position = points[0] + Vector3(0,0,4.5)
	demo.look_at(points[1],Vector3.UP)
	add_child(demo)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02,0.03,0.06,0.64)
	menu_ui.add_child(shade)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -560
	card.offset_top = -275
	card.offset_right = 560
	card.offset_bottom = 275
	card.add_theme_stylebox_override("panel",style(Color(0.025,0.04,0.075,0.90),Color(0.18,0.25,0.38),24))
	menu_ui.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",28)
	margin.add_theme_constant_override("margin_right",28)
	margin.add_theme_constant_override("margin_top",28)
	margin.add_theme_constant_override("margin_bottom",28)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",26)
	margin.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation",8)
	row.add_child(left)

	var title := Label.new()
	title.text = "HYOUKA KART RACER"
	title.add_theme_font_size_override("font_size",42)
	left.add_child(title)

	var sub := Label.new()
	sub.text = "ORIGINAL ARCADE RACING  •  ANDROID"
	sub.add_theme_font_size_override("font_size",16)
	sub.modulate = Color(0.52,0.82,1.0)
	left.add_child(sub)

	var heading := Label.new()
	heading.text = "SELECT TRACK"
	heading.add_theme_font_size_override("font_size",17)
	heading.modulate = Color(0.82,0.86,0.95)
	left.add_child(heading)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	left.add_child(grid)

	for i in TRACKS.size():
		var b := Button.new()
		b.text = "%d   %s" % [i+1,TRACKS[i].name]
		b.custom_minimum_size = Vector2(310,78)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size",17)
		b.add_theme_stylebox_override("normal",style(Color(0.055,0.08,0.13,0.96),Color(0.16,0.22,0.32),16))
		b.add_theme_stylebox_override("pressed",style(TRACKS[i].accent.darkened(0.45),TRACKS[i].accent,16))
		b.pressed.connect(start_race.bind(i))
		grid.add_child(b)

	var help := Label.new()
	help.text = "3 LAPS  •  8 RACERS  •  TURBO
FULLSCREEN LANDSCAPE  •  TOUCH CONTROLS ONLY"
	help.add_theme_font_size_override("font_size",14)
	help.modulate = Color(0.68,0.73,0.82)
	left.add_child(help)

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(300,0)
	info.add_theme_constant_override("separation",14)
	row.add_child(info)

	var live := Label.new()
	live.text = "LIVE PREVIEW"
	live.add_theme_font_size_override("font_size",15)
	live.modulate = Color(0.45,1.0,0.75)
	info.add_child(live)

	var track_name := Label.new()
	track_name.text = TRACKS[track_index].name
	track_name.add_theme_font_size_override("font_size",25)
	info.add_child(track_name)

	var desc := Label.new()
	desc.text = TRACKS[track_index].desc
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size",16)
	desc.modulate = Color(0.72,0.77,0.86)
	info.add_child(desc)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(fill)

	var mobile := Label.new()
	mobile.text = "ANDROID EDITION
Landscape • Immersive • Touch UI"
	mobile.add_theme_font_size_override("font_size",15)
	mobile.modulate = Color(0.62,0.72,0.90)
	info.add_child(mobile)

func start_race(index: int) -> void:
	track_index = index
	if is_instance_valid(menu_ui):
		menu_ui.queue_free()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	build_world()
	spawn_racers()
	build_hud()
	racing = true
	finished = false
	paused = false
	countdown = 3.2
	elapsed = 0.0
	lap = 1
	next_checkpoint = 1
	status_label.text = "3"
	update_hud()

func spawn_racers() -> void:
	racers.clear()
	var colors = [Color("#38bdf8"),Color("#ff5d73"),Color("#ffd34e"),Color("#9b7bff"),Color("#4ee6a8"),Color("#ff8b3d"),Color("#e76cff"),Color("#d7e2ea")]
	var names = ["NOVA","PIP","RIN","KITE","MILO","VEGA","TARO","LUMA"]
	for i in 8:
		var c := KartCar.new()
		c.build(colors[i],names[i])
		var lane := float(i%4)-1.5
		var row := float(i/4)
		c.position = points[0] + Vector3(lane*2.3,0,4.0+row*3.6)
		c.look_at(points[1],Vector3.UP)
		add_child(c)
		racers.append(c)
		if i==0:
			player = c
		else:
			c.set_ai(points)
	race_camera = Camera3D.new()
	add_child(race_camera)
	race_camera.current = true
	race_camera.global_position = player.global_position + player.global_transform.basis*Vector3(0,6.2,11.5)
	race_camera.look_at(player.global_position+Vector3(0,1.1,0),Vector3.UP)

func build_hud() -> void:
	race_ui = CanvasLayer.new()
	add_child(race_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	race_ui.add_child(root)

	var panel := PanelContainer.new()
	panel.position = Vector2(22,20)
	panel.custom_minimum_size = Vector2(250,0)
	panel.add_theme_stylebox_override("panel",style(Color(0.02,0.04,0.07,0.86),Color(0.15,0.21,0.30),18))
	root.add_child(panel)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",14)
	m.add_theme_constant_override("margin_right",14)
	m.add_theme_constant_override("margin_top",12)
	m.add_theme_constant_override("margin_bottom",12)
	panel.add_child(m)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation",2)
	m.add_child(stats)
	track_label = Label.new()
	track_label.add_theme_font_size_override("font_size",15)
	track_label.modulate = Color(0.55,0.85,1.0)
	stats.add_child(track_label)
	lap_label = Label.new()
	lap_label.add_theme_font_size_override("font_size",25)
	stats.add_child(lap_label)
	speed_label = Label.new()
	speed_label.add_theme_font_size_override("font_size",17)
	speed_label.modulate = Color(0.78,0.82,0.9)
	stats.add_child(speed_label)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size",17)
	time_label.modulate = Color(0.78,0.82,0.9)
	stats.add_child(time_label)

	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_CENTER)
	status_label.offset_left=-140
	status_label.offset_right=140
	status_label.offset_top=-80
	status_label.offset_bottom=20
	status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size",58)
	status_label.modulate = Color(1,0.84,0.40)
	root.add_child(status_label)

	var pause := Button.new()
	pause.text = "II"
	pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause.offset_left=-82
	pause.offset_right=-22
	pause.offset_top=20
	pause.offset_bottom=74
	pause.focus_mode=Control.FOCUS_NONE
	pause.add_theme_stylebox_override("normal",style(Color(0.02,0.04,0.07,0.82),Color(0.18,0.23,0.33),16))
	pause.add_theme_stylebox_override("pressed",style(Color(0.13,0.17,0.24,0.96),Color(0.55,0.75,1.0),16))
	pause.pressed.connect(toggle_pause)
	root.add_child(pause)

	add_mobile_button(root,"◀","steer_left",Control.PRESET_BOTTOM_LEFT,28,-128,148,-24,30)
	add_mobile_button(root,"▶","steer_right",Control.PRESET_BOTTOM_LEFT,162,-128,282,-24,30)
	add_mobile_button(root,"GO","accelerate",Control.PRESET_BOTTOM_RIGHT,-190,-128,-28,-24,20)
	add_mobile_button(root,"BRAKE","brake",Control.PRESET_BOTTOM_RIGHT,-190,-240,-28,-150,15)

	var turbo := Button.new()
	turbo.text="TURBO"
	turbo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	turbo.offset_left=-348
	turbo.offset_right=-196
	turbo.offset_top=-128
	turbo.offset_bottom=-24
	turbo.focus_mode=Control.FOCUS_NONE
	turbo.add_theme_font_size_override("font_size",17)
	turbo.add_theme_stylebox_override("normal",style(Color(0.26,0.09,0.06,0.92),Color(1,0.55,0.22),26))
	turbo.add_theme_stylebox_override("pressed",style(Color(0.55,0.19,0.06,0.98),Color(1,0.78,0.34),26))
	turbo.pressed.connect(func() -> void:
		if player and racing and not finished:
			player.give_boost(1.8)
	)
	root.add_child(turbo)
	update_track_label()
	update_hud()

func add_mobile_button(root: Control, text_value: String, action: String, preset: Control.LayoutPreset, left: float, top: float, right: float, bottom: float, fs: int) -> void:
	var b := Button.new()
	b.text=text_value
	b.set_anchors_preset(preset)
	b.offset_left=left
	b.offset_top=top
	b.offset_right=right
	b.offset_bottom=bottom
	b.focus_mode=Control.FOCUS_NONE
	b.mouse_filter=Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size",fs)
	b.add_theme_stylebox_override("normal",style(Color(0.025,0.04,0.07,0.78),Color(0.22,0.29,0.40),26))
	b.add_theme_stylebox_override("pressed",style(Color(0.10,0.18,0.28,0.96),Color(0.42,0.74,1.0),26))
	b.button_down.connect(func() -> void:
		if player and racing and not finished:
			player.set_mobile_control(action,true)
	)
	b.button_up.connect(func() -> void:
		if player:
			player.set_mobile_control(action,false)
	)
	root.add_child(b)

func toggle_pause() -> void:
	if not racing or finished:
		return
	paused=!paused
	get_tree().paused=paused
	if status_label:
		status_label.text="PAUSED" if paused else ""

func update_track_label() -> void:
	if track_label:
		track_label.text = TRACKS[track_index].name

func update_hud() -> void:
	if lap_label:
		lap_label.text="LAP  %d / %d" % [lap,total_laps]
	if speed_label and player:
		speed_label.text="%d KM/H" % int(player.speed*4.2)
	if time_label:
		time_label.text="%02d:%04.1f" % [int(elapsed)/60,fmod(elapsed,60.0)]

func checkpoint_tick() -> void:
	if not player or finished or points.is_empty():
		return
	if player.global_position.distance_to(points[next_checkpoint]) > 7.0:
		return
	next_checkpoint=(next_checkpoint+1)%points.size()
	if next_checkpoint==0:
		lap+=1
		if lap>total_laps:
			finished=true
			racing=false
			player.clear_mobile_controls()
			status_label.text="FINISH!"
		elif lap_label:
			lap_label.text="LAP  %d / %d" % [lap,total_laps]

func _process(delta: float) -> void:
	if not racing or finished or paused:
		return
	countdown-=delta
	if countdown>0.0:
		status_label.text=str(int(ceil(countdown)))
	else:
		if status_label.text!="GO!":
			status_label.text="GO!"
			get_tree().create_timer(0.65).timeout.connect(func() -> void:
				if status_label and racing:
					status_label.text=""
			)
		elapsed+=delta
		checkpoint_tick()
		update_hud()
		if player and race_camera:
			var target:=player.global_position+player.global_transform.basis*Vector3(0,6.2,11.5)
			race_camera.global_position=race_camera.global_position.lerp(target,delta*5.0)
			race_camera.look_at(player.global_position+Vector3(0,1.1,0),Vector3.UP)
