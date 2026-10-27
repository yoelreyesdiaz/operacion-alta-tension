@tool
extends EditorPlugin
## Captura la ventana real del editor de Godot con cada script abierto.
## Lista de trabajo en res://addons/captura_editor/lista.json: [[ruta, línea, archivo_png], ...]

func _enter_tree() -> void:
	_run.call_deferred()


func _run() -> void:
	var lista: Array = JSON.parse_string(FileAccess.get_file_as_string("res://addons/captura_editor/lista.json"))
	await _frames(90)
	for item: Array in lista:
		var path: String = item[0]
		if path == "2D":
			EditorInterface.set_main_screen_editor("2D")
		else:
			EditorInterface.set_main_screen_editor("Script")
			EditorInterface.edit_script(load(path), int(item[1]), 0)
			var se := EditorInterface.get_script_editor()
			var ed := se.get_current_editor()
			if ed:
				var te := ed.get_base_editor() as CodeEdit
				if te:
					te.set_line_as_first_visible(max(0, int(item[1]) - 2))
		await _frames(25)
		await RenderingServer.frame_post_draw
		EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(item[2])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
