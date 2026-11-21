extends Node3D

const TANK_SCENE := preload("res://vendor/tron_1982_tank/scene.gltf")
const ARENA := 54.0
const PLAYER_SPEED := 7.2
const TURN_RATE := 1.45
const SHELL_SPEED := 24.0

var player: Node3D
var enemies: Array[Node3D] = []
var shells: Array[Dictionary] = []
var obstacles: Array[Vector3] = []
var score := 0
var armor := 5
var reloading := 0.0
var enemy_brain_timer := 0.0
var ended := false
var hud: Label
var armor_bar: ProgressBar
var message: Label
var joystick: Control
var fire_button: Button
var joystick_touch := -1
var aim_touch := -1
var joystick_vector := Vector2.ZERO
var aim_vector := Vector2.ZERO
var aim_delta := Vector2.ZERO
var firing := false
var arena_rng := RandomNumberGenerator.new()

func _ready() -> void:
	arena_rng.randomize()
	_build_lighting()
	_build_arena()
	_spawn_player()
	_spawn_enemies(4)
	_build_hud()
	_build_touch_controls()
	_update_hud()

func _process(delta: float) -> void:
	if ended:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return
	reloading = maxf(0.0, reloading - delta)
	_update_player(delta)
	_update_enemies(delta)
	_update_shells(delta)
	_update_camera(delta)
	if (firing or Input.is_action_pressed("fire")) and reloading <= 0.0:
		_fire(player, true)
		reloading = 0.72
	if enemy_brain_timer <= 0.0:
		for enemy in enemies:
			if enemy.get_meta("state") == "search":
				enemy.set_meta("state", "hunt")
		enemy_brain_timer = 0.4
	else:
		enemy_brain_timer -= delta

func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.015, 0.025, 0.06)
	sky_mat.sky_horizon_color = Color(0.08, 0.12, 0.19)
	sky_mat.ground_bottom_color = Color(0.008, 0.012, 0.022)
	sky_mat.ground_horizon_color = Color(0.035, 0.06, 0.09)
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.25, 0.38, 0.52)
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_color = Color(0.55, 0.76, 1.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

func _build_arena() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA, ARENA)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.045, 0.065, 0.082)
	ground_mat.roughness = 0.92
	ground_mat.metallic = 0.15
	ground.material_override = ground_mat
	add_child(ground)
	for i in range(-27, 28, 3):
		var c := Color(0.0, 0.45, 0.65, 0.22) if i % 9 == 0 else Color(0.0, 0.32, 0.44, 0.10)
		_add_line(Vector3(i, 0.016, -27), Vector3(i, 0.016, 27), c, 0.025 if i % 9 == 0 else 0.012)
		_add_line(Vector3(-27, 0.016, i), Vector3(27, 0.016, i), c, 0.025 if i % 9 == 0 else 0.012)
	var wall_material := _material(Color(0.02, 0.22, 0.31), Color(0.0, 0.6, 0.85), 0.9)
	for side in [-1, 1]:
		_add_wall(Vector3(0, 1.2, side * 27), Vector3(54, 2.4, 0), wall_material)
		_add_wall(Vector3(side * 27, 1.2, 0), Vector3(0, 2.4, 54), wall_material)
	for p in [Vector3(-10, 0, -10), Vector3(10, 0, -10), Vector3(-10, 0, 10), Vector3(10, 0, 10), Vector3(-18, 0, 1), Vector3(18, 0, -1), Vector3(0, 0, -17)]:
		obstacles.append(p)
		_make_bunker(p)

func _make_bunker(p: Vector3) -> void:
	var root := Node3D.new()
	root.position = p
	add_child(root)
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4.2, 2.7, 4.2)
	block.mesh = mesh
	block.position.y = 1.35
	block.material_override = _material(Color(0.10, 0.15, 0.19), Color(0.01, 0.12, 0.18), 0.0)
	root.add_child(block)
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(4.35, 0.16, 4.35)
	roof.mesh = roof_mesh
	roof.position.y = 2.74
	roof.material_override = _material(Color(0.12, 0.23, 0.28), Color(0.0, 0.55, 0.7), 0.45)
	root.add_child(roof)
	var bunker_body := StaticBody3D.new()
	var bunker_shape := CollisionShape3D.new()
	var bunker_box := BoxShape3D.new()
	bunker_box.size = Vector3(4.2, 2.7, 4.2)
	bunker_shape.shape = bunker_box
	bunker_shape.position.y = 1.35
	bunker_body.add_child(bunker_shape)
	root.add_child(bunker_body)
	_add_line(p + Vector3(-2.1, 0.04, 0), p + Vector3(2.1, 0.04, 0), Color(0.0, 0.75, 1.0, 0.55), 0.08)

func _add_wall(pos: Vector3, size: Vector3, material: Material) -> void:
	var wall := StaticBody3D.new()
	wall.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	wall.add_child(visual)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)

func _spawn_player() -> void:
	player = _make_tank(true)
	player.position = Vector3(0, 0, 20)
	add_child(player)

func _spawn_enemies(count: int) -> void:
	for i in range(count):
		var enemy := _make_tank(false)
		var candidate := Vector3(arena_rng.randf_range(-21, 21), 0, arena_rng.randf_range(-16, 4))
		var tries := 0
		while (candidate.distance_to(player.position) < 18.0 or _near_obstacle(candidate, 5.0)) and tries < 24:
			candidate = Vector3(arena_rng.randf_range(-21, 21), 0, arena_rng.randf_range(-16, 4))
			tries += 1
		enemy.position = candidate
		enemy.rotation.y = arena_rng.randf_range(-PI, PI)
		add_child(enemy)
		enemies.append(enemy)

func _make_tank(is_player: bool) -> Node3D:
	var root := Node3D.new()
	root.set_meta("hp", 3 if is_player else 2)
	root.set_meta("reload", arena_rng.randf_range(1.1, 2.0))
	root.set_meta("state", "hunt")
	root.set_meta("speed", 7.2 if is_player else arena_rng.randf_range(2.5, 3.6))
	root.set_meta("turret_yaw", 0.0)
	var collider := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	var hull_shape := BoxShape3D.new()
	hull_shape.size = Vector3(2.5, 1.5, 3.5)
	collision_shape.shape = hull_shape
	collision_shape.position.y = 0.75
	collider.add_child(collision_shape)
	root.add_child(collider)
	var model := TANK_SCENE.instantiate()
	model.scale = Vector3.ONE * 1.8
	model.rotation.y = PI
	root.add_child(model)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.3, 0)
	light.light_color = Color(0.0, 0.72, 1.0) if is_player else Color(1.0, 0.18, 0.035)
	light.light_energy = 0.25
	light.omni_range = 4.5
	root.add_child(light)
	var turret := Node3D.new()
	turret.name = "TurretPivot"
	turret.position = Vector3(0, 1.0, 0)
	root.add_child(turret)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.09
	barrel_mesh.bottom_radius = 0.13
	barrel_mesh.height = 2.0
	barrel.mesh = barrel_mesh
	barrel.rotation.x = PI * 0.5
	barrel.position = Vector3(0, 0.0, -1.0)
	barrel.material_override = _material(Color(0.07, 0.16, 0.2), Color(0.0, 0.55, 0.85), 0.45)
	turret.add_child(barrel)
	var mantle := MeshInstance3D.new()
	var mantle_mesh := BoxMesh.new()
	mantle_mesh.size = Vector3(1.0, 0.45, 0.9)
	mantle.mesh = mantle_mesh
	mantle.position.y = -0.12
	mantle.material_override = _material(Color(0.08, 0.15, 0.19), Color(0.0, 0.22, 0.32), 0.2)
	turret.add_child(mantle)
	if is_player:
		var pivot := Node3D.new()
		pivot.name = "CameraPivot"
		pivot.position = Vector3(0, 2.4, 0)
		root.add_child(pivot)
		var camera := Camera3D.new()
		camera.name = "Camera3D"
		camera.position = Vector3(0, 5.4, 10.5)
		camera.rotation_degrees = Vector3(-22, 0, 0)
		camera.fov = 66
		camera.current = true
		pivot.add_child(camera)
	return root

func _update_player(delta: float) -> void:
	var steer := Input.get_axis("turn_left", "turn_right")
	var throttle := Input.get_axis("move_backward", "move_forward")
	if joystick_touch >= 0:
		steer = joystick_vector.x
		throttle = -joystick_vector.y
	player.rotate_y(-steer * TURN_RATE * delta)
	var forward := -player.global_basis.z
	var speed: float = player.get_meta("speed")
	var next_pos := player.position + forward * throttle * speed * delta
	if _can_move(next_pos):
		player.position = next_pos
	var camera := player.get_node("CameraPivot/Camera3D") as Camera3D
	if aim_touch >= 0:
		camera.rotation.y -= aim_delta.x * 0.0025
		camera.rotation.x = clampf(camera.rotation.x - aim_delta.y * 0.0017, -0.1, 0.34)
		var turret: Node3D = player.get_node("TurretPivot")
		turret.rotation.y = -camera.rotation.y
		aim_delta = Vector2.ZERO
	else:
		var turret: Node3D = player.get_node("TurretPivot")
		turret.rotation.y = move_toward(turret.rotation.y, 0.0, delta * 1.6)

func _update_enemies(delta: float) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var to_player := player.position - enemy.position
		var distance := to_player.length()
		var target_yaw := atan2(-to_player.x, -to_player.z)
		enemy.rotation.y = rotate_toward(enemy.rotation.y, target_yaw, 0.7 * delta)
		var clear := _line_clear(enemy.position + Vector3.UP + to_player.normalized() * 2.0, player.position + Vector3.UP)
		var state: String = enemy.get_meta("state")
		if clear:
			enemy.set_meta("state", "engage")
			if distance > 13.0:
				var next_pos := enemy.position - enemy.global_basis.z * float(enemy.get_meta("speed")) * delta
				if _can_move(next_pos):
					enemy.position = next_pos
		elif state == "engage":
			enemy.set_meta("state", "search")
		else:
			var next_pos := enemy.position - enemy.global_basis.z * float(enemy.get_meta("speed")) * 0.55 * delta
			if _can_move(next_pos):
				enemy.position = next_pos
		var reload: float = enemy.get_meta("reload")
		reload -= delta
		if reload <= 0.0 and clear and distance < 36.0:
			_fire(enemy, false)
			reload = arena_rng.randf_range(1.8, 3.2)
		enemy.set_meta("reload", reload)
		var turret: Node3D = enemy.get_node("TurretPivot")
		turret.rotation.y = 0.0

func _update_camera(delta: float) -> void:
	var pivot := player.get_node("CameraPivot") as Node3D
	var target := player.position + Vector3(0, 2.4, 0)
	pivot.global_position = pivot.global_position.lerp(target, minf(1.0, 5.0 * delta))

func _fire(from: Node3D, player_shell: bool) -> void:
	var direction: Vector3
	var muzzle: Vector3
	if player_shell:
		var camera := player.get_node("CameraPivot/Camera3D") as Camera3D
		direction = -camera.global_basis.z.normalized()
		muzzle = from.global_position + Vector3.UP * 1.45 + (-from.global_basis.z * 1.7)
	else:
		direction = (player.global_position + Vector3.UP * 0.9 - from.global_position - Vector3.UP).normalized()
		muzzle = from.global_position + Vector3.UP * 1.1 + direction * 1.8
	var color := Color(0.12, 0.78, 1.0) if player_shell else Color(1.0, 0.22, 0.07)
	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	shell.mesh = sphere
	shell.position = muzzle
	shell.material_override = _material(color, color, 2.5)
	add_child(shell)
	shells.append({"node": shell, "direction": direction, "player": player_shell, "life": 2.5})
	_spawn_flash(muzzle, color, 0.25)

func _update_shells(delta: float) -> void:
	for i in range(shells.size() - 1, -1, -1):
		var shell_data: Dictionary = shells[i]
		var shell: Node3D = shell_data.node
		shell_data.life = float(shell_data.life) - delta
		var from: Vector3 = shell.position
		var to: Vector3 = from + shell_data.direction * SHELL_SPEED * delta
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var did_hit := not hit.is_empty()
		if did_hit:
			var hit_pos: Vector3 = hit.position
			if shell_data.player:
				var target: Node = hit.collider
				while target != null and not target in enemies:
					target = target.get_parent()
				if target != null:
					_damage_enemy(target)
			else:
				var target := hit.collider as Node
				while target != null and target != player:
					target = target.get_parent()
				if target == player:
					_damage_player()
			_spawn_impact(hit_pos, Color(0.12, 0.72, 1.0) if shell_data.player else Color(1.0, 0.2, 0.06))
		else:
			shell.position = to
			if shell_data.life <= 0.0 or absf(to.x) > ARENA * 0.5 or absf(to.z) > ARENA * 0.5:
				did_hit = true
		if did_hit:
			shell.queue_free()
			shells.remove_at(i)
		else:
			shells[i] = shell_data

func _damage_enemy(enemy: Node) -> void:
	enemy.set_meta("hp", int(enemy.get_meta("hp")) - 1)
	_spawn_impact(enemy.global_position + Vector3.UP, Color(1.0, 0.6, 0.18))
	if int(enemy.get_meta("hp")) <= 0:
		enemies.erase(enemy)
		score += 100
		enemy.queue_free()
		if enemies.is_empty():
			_spawn_enemies(4)
	_update_hud()

func _damage_player() -> void:
	armor -= 1
	_spawn_impact(player.position + Vector3.UP, Color(1.0, 0.15, 0.08))
	_update_hud()
	if armor <= 0:
		ended = true
		message.text = "TANK DESTROYED\nTap to deploy again"
		message.visible = true

func _spawn_impact(p: Vector3, color: Color) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.36
	sphere.height = 0.72
	flash.mesh = sphere
	flash.position = p
	flash.material_override = _material(color, color, 3.0)
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 3.0, 0.18)
	tween.parallel().tween_property(flash, "transparency", 1.0, 0.18)
	tween.tween_callback(flash.queue_free)

func _spawn_flash(p: Vector3, color: Color, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = p
	light.light_color = color
	light.light_energy = 3.2
	light.omni_range = radius * 8.0
	add_child(light)
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.1)
	tween.tween_callback(light.queue_free)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)
	var top := ColorRect.new()
	top.position = Vector2(18, 16)
	top.size = Vector2(360, 76)
	top.color = Color(0.01, 0.025, 0.045, 0.72)
	root.add_child(top)
	hud = Label.new()
	hud.position = Vector2(36, 22)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color(0.74, 0.92, 1.0))
	root.add_child(hud)
	armor_bar = ProgressBar.new()
	armor_bar.position = Vector2(36, 58)
	armor_bar.size = Vector2(220, 14)
	armor_bar.max_value = 5
	armor_bar.show_percentage = false
	root.add_child(armor_bar)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-8, -18)
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0, 0.8))
	root.add_child(crosshair)
	message = Label.new()
	message.set_anchors_preset(Control.PRESET_CENTER)
	message.position = Vector2(-220, -65)
	message.size = Vector2(440, 130)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 34)
	message.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0))
	message.visible = false
	root.add_child(message)
	var hint := Label.new()
	hint.text = "LEFT STICK: DRIVE     RIGHT SIDE: AIM     FIRE: CANNON"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.position = Vector2(0, -34)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.62, 0.78, 0.86, 0.8))
	root.add_child(hint)
	joystick = Control.new()
	joystick.position = Vector2(28, 0)
	joystick.size = Vector2(210, 210)
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position.y = -232
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(joystick)
	joystick.draw.connect(_draw_joystick)
	joystick.visible = OS.has_feature("mobile")
	root.gui_input.connect(_on_screen_input)

func _build_touch_controls() -> void:
	var root := joystick.get_parent() as Control
	fire_button = Button.new()
	fire_button.text = "FIRE"
	fire_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fire_button.position = Vector2(-168, -184)
	fire_button.size = Vector2(132, 132)
	fire_button.add_theme_font_size_override("font_size", 22)
	fire_button.add_theme_color_override("font_color", Color(1.0, 0.91, 0.86))
	fire_button.add_theme_stylebox_override("normal", _button_style(Color(0.54, 0.12, 0.08, 0.78)))
	fire_button.add_theme_stylebox_override("pressed", _button_style(Color(0.95, 0.29, 0.11, 0.9)))
	fire_button.button_down.connect(func(): firing = true)
	fire_button.button_up.connect(func(): firing = false)
	fire_button.visible = OS.has_feature("mobile")
	root.add_child(fire_button)

func _on_screen_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < get_viewport().get_visible_rect().size.x * 0.42 and joystick_touch < 0:
				joystick_touch = event.index
				_set_joystick(event.position)
			elif aim_touch < 0:
				aim_touch = event.index
		else:
			if event.index == joystick_touch:
				joystick_touch = -1
				joystick_vector = Vector2.ZERO
			elif event.index == aim_touch:
				aim_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == joystick_touch:
			_set_joystick(event.position)
		elif event.index == aim_touch:
			aim_delta += event.relative
			if event.position.y > get_viewport().get_visible_rect().size.y - 170 and event.position.x > get_viewport().get_visible_rect().size.x - 180:
				firing = true
			else:
				firing = false

func _set_joystick(screen_pos: Vector2) -> void:
	var size := get_viewport().get_visible_rect().size
	var center := Vector2(132, size.y - 132)
	joystick_vector = ((screen_pos - center) / 82.0).limit_length(1.0)
	joystick.queue_redraw()

func _draw_joystick() -> void:
	var center := Vector2(105, 105)
	joystick.draw_circle(center, 84, Color(0.01, 0.07, 0.11, 0.38))
	joystick.draw_arc(center, 84, 0, TAU, 64, Color(0.3, 0.78, 0.9, 0.52), 2.0)
	var knob := center + joystick_vector * 42.0
	joystick.draw_circle(knob, 36, Color(0.08, 0.45, 0.58, 0.55))
	joystick.draw_arc(knob, 36, 0, TAU, 48, Color(0.55, 0.94, 1.0, 0.75), 2.0)

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(1.0, 0.43, 0.23, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(66)
	return style

func _update_hud() -> void:
	if is_instance_valid(hud):
		hud.text = "COMBAT ZONE     %05d" % score
		armor_bar.value = armor

func _can_move(p: Vector3) -> bool:
	if absf(p.x) > ARENA * 0.5 - 2.0 or absf(p.z) > ARENA * 0.5 - 2.0:
		return false
	return not _near_obstacle(p, 3.4)

func _near_obstacle(p: Vector3, radius: float) -> bool:
	for obstacle in obstacles:
		if Vector2(p.x - obstacle.x, p.z - obstacle.z).length() < radius:
			return true
	return false

func _line_clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _add_line(a: Vector3, b: Vector3, color: Color, width: float) -> void:
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, _material(color, color, 1.0))
	immediate.surface_add_vertex(a)
	immediate.surface_add_vertex(b)
	immediate.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = immediate
	add_child(instance)

func _material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.5
	material.roughness = 0.38
	material.emission_enabled = energy > 0.0
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
