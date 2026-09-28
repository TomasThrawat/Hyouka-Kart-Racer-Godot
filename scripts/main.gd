extends Node3D

const TRACKS = [
	{"name":"Sunset Circuit","sky":Color("#5d7bdc"),"ground":Color("#4b8f55"),"road":Color("#343943"),"accent":Color("#ffbd4a"),"points":[Vector3(0,0,32),Vector3(28,0,28),Vector3(48,0,5),Vector3(42,0,-24),Vector3(15,0,-38),Vector3(-18,0,-35),Vector3(-46,0,-10),Vector3(-43,0,19),Vector3(-22,0,34)]},
	{"name":"Crystal Valley","sky":Color("#a7d8ef"),"ground":Color("#79a66e"),"road":Color("#49515b"),"accent":Color("#77e7ff"),"points":[Vector3(0,0,38),Vector3(35,0,32),Vector3(52,0,0),Vector3(33,0,-34),Vector3(0,0,-42),Vector3(-33,0,-34),Vector3(-52,0,0),Vector3(-35,0,32)]},
	{"name":"Neon Harbor","sky":Color("#171a36"),"ground":Color("#20263d"),"road":Color("#252b35"),"accent":Color("#ff4edb"),"points":[Vector3(0,0,34),Vector3(25,0,31),Vector3(44,0,14),Vector3(44,0,-16),Vector3(18,0,-36),Vector3(-18,0,-36),Vector3(-44,0,-16),Vector3(-44,0,14),Vector3(-25,0,31)]},
	{"name":"Sky Garden","sky":Color("#8bd0ff"),"ground":Color("#6eaf70"),"road":Color("#3f4a43"),"accent":Color("#e9f06a"),"points":[Vector3(0,0,30),Vector3(22,0,26),Vector3(38,0,8),Vector3(30,0,-22),Vector3(8,0,-38),Vector3(-25,0,-30),Vector3(-40,0,-2),Vector3(-28,0,23)]}
]

var track_index := 0
var track_points: Array[Vector3] = []
var player: KartCar
var racers: Array[KartCar] = []
var camera: Camera3D
var ui: CanvasLayer
var race_started := false
var countdown := 3.0
var lap := 1
var total_laps := 3
var next_checkpoint := 0
var checkpoint_count := 0
var elapsed := 0.0
var finished := false
var menu: Control
var hud: Control
var status_label: Label
var lap_label: Label
var speed_label: Label
var time_label: Label
var audio_player: AudioStreamPlayer

func _ready() -> void:
	create_world()
	show_menu()

func create_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = TRACKS[track_index].sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8,0.85,1.0)
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	track_points = TRACKS[track_index].points
	build_track()
	build_props()
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

func build_track() -> void:
	var data = TRACKS[track_index]
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(180,180)
	ground.mesh = gm
	ground.material_override = material(data.ground)
	add_child(ground)
	for i in track_points.size():
		var a = track_points[i]
		var b = track_points[(i+1)%track_points.size()]
		var mid = (a+b)*0.5
		var road := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(12,0.22,a.distance_to(b)+2.0)
		road.mesh = box
		road.position = Vector3(mid.x,0.02,mid.z)
		road.look_at(Vector3(b.x,0.02,b.z),Vector3.UP)
		road.material_override = material(data.road)
		add_child(road)
		for side in [-1,1]:
			var curb := MeshInstance3D.new()
			var cb := BoxMesh.new()
			cb.size = Vector3(0.7,0.28,a.distance_to(b)+2.0)
			curb.mesh = cb
			curb.position = Vector3(mid.x + side*6.2,0.18,mid.z)
			curb.look_at(Vector3(b.x + side*6.2,0.18,b.z),Vector3.UP)
			curb.material_override = material(data.accent)
			add_child(curb)
	for i in track_points.size():
		var cp := Area3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(12,3,4)
		cs.shape = shape
		cp.add_child(cs)
		cp.position = track_points[i]
		cp.set_meta("index",i)
		cp.body_entered.connect(_checkpoint_entered.bind(i))
		add_child(cp)
	checkpoint_count = track_points.size()

func build_props() -> void:
	var data = TRACKS[track_index]
	for i in 32:
		var p := MeshInstance3D.new()
		var tree := CylinderMesh.new()
		tree.top_radius = 0.15
		tree.bottom_radius = 0.3
		tree.height = 2.8
		p.mesh = tree
		var angle = i * TAU / 32.0
		var r = 58.0 + (i%3)*7.0
		p.position = Vector3(cos(angle)*r,1.4,sin(angle)*r)
		p.material_override = material(Color(0.18,0.42,0.2) if i%2==0 else data.accent.darkened(0.15))
		add_child(p)
	for i in 12:
		var arch := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(14,5,0.6)
		arch.mesh = am
		arch.position = track_points[0] + Vector3(0,2.5,-i*7)
		arch.material_override = material(data.accent)
		add_child(arch)

func material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m

func show_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.025,0.035,0.065,0.96)
	menu.add_child(bg)
	var title := Label.new()
	title.text = "HYOUKA KART RACER"
	title.position = Vector2(70,70)
	title.add_theme_font_size_override("font_size",54)
	menu.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ORIGINAL ARCADE RACING • ANDROID"
	subtitle.position = Vector2(74,135)
	subtitle.add_theme_font_size_override("font_size",20)
	subtitle.modulate = Color(0.55,0.8,1)
	menu.add_child(subtitle)
	for i in TRACKS.size():
		var b := Button.new()
		b.text = str(i+1)+". "+TRACKS[i].name
		b.position = Vector2(74,210+i*62)
		b.size = Vector2(390,50)
		b.add_theme_font_size_override("font_size",20)
		b.pressed.connect(start_race.bind(i))
		menu.add_child(b)
	var info := Label.new()
	info.text = "WASD / D-Pad: drive    SPACE: Turbo    ESC: pause\n4 original tracks • 8 racers • 3 laps • procedural art/audio"
	info.position = Vector2(74,490)
	info.add_theme_font_size_override("font_size",17)
	info.modulate = Color(0.72,0.75,0.82)
	menu.add_child(info)

func start_race(index: int) -> void:
	track_index = index
	menu.queue_free()
	# Rebuild world for selected track.
	for child in get_children():
		if child != ui:
			child.queue_free()
	await get_tree().process_frame
	create_world()
	spawn_racers()
	build_hud()
	race_started = true
	countdown = 3.0
	elapsed = 0.0
	lap = 1
	next_checkpoint = 1
	finished = false

func spawn_racers() -> void:
	var colors = [Color("#38bdf8"),Color("#ff5d73"),Color("#ffd34e"),Color("#9b7bff"),Color("#4ee6a8"),Color("#ff8b3d"),Color("#e76cff"),Color("#d7e2ea")]
	var names = ["Nova","Pip","Rin","Kite","Milo","Vega","Taro","Luma"]
	for i in 8:
		var c := KartCar.new()
		c.build(colors[i],names[i])
		var start = track_points[0] + Vector3((i%4-1.5)*2.3,0,-(i/4)*4.0)
		c.position = start
		c.look_at(track_points[1],Vector3.UP)
		add_child(c)
		racers.append(c)
		if i == 0:
			player = c
		else:
			c.set_ai(track_points)
	camera = Camera3D.new()
	camera.position = player.position + Vector3(0,7,11)
	add_child(camera)
	camera.current = true

func build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui = CanvasLayer.new()
	add_child(ui)
	ui.add_child(hud)
	lap_label = make_label("LAP 1 / 3",Vector2(35,30),28)
	speed_label = make_label("0 KM/H",Vector2(35,70),22)
	time_label = make_label("00:00.0",Vector2(35,102),20)
	status_label = make_label("GET READY",Vector2(0,55),42)
	status_label.anchor_left = 0.5
	status_label.anchor_right = 0.5
	status_label.position.x = -120
	hud.add_child(status_label)
	var boost := Button.new()
	boost.text = "TURBO"
	boost.position = Vector2(1050,590)
	boost.size = Vector2(170,70)
	boost.add_theme_font_size_override("font_size",22)
	boost.pressed.connect(func(): if player: player.give_boost(1.8))
	hud.add_child(boost)
	add_touch_button("◀",Vector2(35,585),"steer_left")
	add_touch_button("▶",Vector2(215,585),"steer_right")
	add_touch_button("GO",Vector2(125,500),"accelerate")
	add_touch_button("BRAKE",Vector2(235,500),"brake")

func make_label(t:String,p:Vector2,s:int) -> Label:
	var l:=Label.new()
	l.text=t
	l.position=p
	l.add_theme_font_size_override("font_size",s)
	hud.add_child(l)
	return l

func add_touch_button(t:String,p:Vector2,action:String) -> void:
	var b:=Button.new()
	b.text=t
	b.position=p
	b.size=Vector2(150,72)
	b.modulate=Color(1,1,1,0.78)
	b.button_down.connect(func(): Input.action_press(action))
	b.button_up.connect(func(): Input.action_release(action))
	hud.add_child(b)

func _checkpoint_entered(body: Node, index: int) -> void:
	if body != player or finished:
		return
	if index == next_checkpoint:
		next_checkpoint = (next_checkpoint + 1) % checkpoint_count
		if next_checkpoint == 0:
			lap += 1
			if lap > total_laps:
				finished = true
				status_label.text = "FINISH!"
			else:
				lap_label.text = "LAP %d / %d" % [lap,total_laps]

func _process(delta: float) -> void:
	if not race_started or finished:
		return
	countdown -= delta
	if countdown > 0:
		status_label.text = str(ceil(countdown))
	else:
		if status_label.text != "GO!":
			status_label.text = "GO!"
			get_tree().create_timer(0.8).timeout.connect(func(): if status_label: status_label.text = "")
		elapsed += delta
		if player:
			speed_label.text = "%d KM/H" % int(player.speed*4.2)
			time_label.text = "%02d:%04.1f" % [int(elapsed)/60,fmod(elapsed,60.0)]
			var target_cam = player.global_position + player.global_transform.basis * Vector3(0,6,10)
			camera.global_position = camera.global_position.lerp(target_cam,delta*5.0)
			camera.look_at(player.global_position + Vector3(0,1,0),Vector3.UP)
