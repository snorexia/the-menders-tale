extends SceneTree
## Рендерит 3D-модель (.glb / .gltf) в PNG с прозрачным фоном — так модель становится 2D-картинкой.
##
## Запуск (из корня репозитория, окно Godot мелькнёт на пару секунд):
##   "$GODOT_PATH" --path <любой проект> --script <абс. путь к этому файлу> \
##       -- <абс. путь к модели> <файл.png> [пикселей на метр] [поворот в градусах]
## Камера ортогональная, смотрит на модель спереди (вдоль −Z). Поворот — вокруг оси взгляда,
## по часовой стрелке. Свет — тёплый, слева сверху. В режиме --headless не работает.

const FRAMES_TO_WAIT := 10
const DEFAULT_PIXELS_PER_METER := 1000.0
const PADDING_PIXELS := 8
const CAMERA_DISTANCE := 1.0
const KEY_LIGHT_POSITION := Vector3(-1.0, 1.0, 1.5)
const KEY_LIGHT_COLOR := Color(1.0, 0.85, 0.7)
const SKY_TOP_COLOR := Color(0.55, 0.45, 0.35)
const SKY_HORIZON_COLOR := Color(0.35, 0.25, 0.18)
const AMBIENT_ENERGY := 0.6


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Нужно: -- <модель.glb> <файл.png> [пикселей на метр] [поворот°]")
		quit(1)
		return

	var model := _load_model(args[0])
	if model == null:
		push_error("Не удалось загрузить модель: %s" % args[0])
		quit(1)
		return

	var pixels_per_meter := DEFAULT_PIXELS_PER_METER
	if args.size() > 2:
		pixels_per_meter = args[2].to_float()
	var turn_degrees := 0.0
	if args.size() > 3:
		turn_degrees = args[3].to_float()

	_render(model, args[1], pixels_per_meter, turn_degrees)


func _load_model(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	return document.generate_scene(state) as Node3D


func _render(model: Node3D, output_path: String, pixels_per_meter: float, turn: float) -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_8X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var pivot := Node3D.new()
	pivot.rotation_degrees.z = -turn
	viewport.add_child(pivot)
	pivot.add_child(model)
	viewport.add_child(_make_environment())

	# В _initialize корень ещё не в дереве: глобальные координаты модели появятся через кадр.
	await process_frame

	var bounds := _get_bounds(model)
	var padding := Vector2(PADDING_PIXELS, PADDING_PIXELS) * 2.0
	var size_pixels := Vector2(bounds.size.x, bounds.size.y) * pixels_per_meter + padding
	viewport.size = Vector2i(size_pixels.ceil())

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = viewport.size.y / pixels_per_meter
	camera.far = bounds.size.z + CAMERA_DISTANCE * 2.0
	viewport.add_child(camera)
	var center := bounds.get_center()
	camera.position = Vector3(center.x, center.y, bounds.end.z + CAMERA_DISTANCE)

	var light := DirectionalLight3D.new()
	light.light_color = KEY_LIGHT_COLOR
	viewport.add_child(light)
	light.look_at_from_position(center + KEY_LIGHT_POSITION, center)

	for i: int in FRAMES_TO_WAIT:
		await process_frame

	var image := viewport.get_texture().get_image()
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Не удалось сохранить %s (код %d)" % [output_path, error])
		quit(1)
		return

	print("Рендер сохранён: %s (%dx%d)" % [output_path, image.get_width(), image.get_height()])
	quit()


func _make_environment() -> WorldEnvironment:
	# Небо только для отражений и рассеянного света: без него металл выглядит чёрным.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SKY_TOP_COLOR
	sky_material.sky_horizon_color = SKY_HORIZON_COLOR
	sky_material.ground_horizon_color = SKY_HORIZON_COLOR
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = AMBIENT_ENERGY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	return world_environment


func _get_bounds(node: Node) -> AABB:
	var bounds := AABB()
	var is_first := true
	for mesh_instance: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
		if is_first:
			bounds = mesh_bounds
			is_first = false
		else:
			bounds = bounds.merge(mesh_bounds)
	return bounds
