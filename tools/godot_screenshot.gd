extends SceneTree
## Открывает сцену проекта, ждёт несколько кадров и сохраняет кадр в PNG.
##
## Запуск (из корня репозитория, окно Godot мелькнёт на пару секунд):
##   "$GODOT_PATH" --path <проект> --script <абс. путь к этому файлу> \
##       -- <res://сцена.tscn> <файл.png>
## В режиме --headless не работает: без отрисовки кадр пустой.

const FRAMES_TO_WAIT := 5


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Нужно: -- <res://сцена.tscn> <файл.png>")
		quit(1)
		return

	var scene_path: String = args[0]
	var output_path: String = args[1]
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("Не удалось загрузить сцену: %s" % scene_path)
		quit(1)
		return

	root.add_child(packed.instantiate())
	_capture(output_path)


func _capture(output_path: String) -> void:
	for i in FRAMES_TO_WAIT:
		await process_frame

	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Не удалось сохранить %s (код %d)" % [output_path, error])
		quit(1)
		return

	print("Скриншот сохранён: %s (%dx%d)" % [output_path, image.get_width(), image.get_height()])
	quit()
