class_name CamaraFeed
extends SubViewport
## Cámara de seguridad en vivo: un SubViewport de 160×96 que comparte el mundo del nivel
## y lo mira con una Camera2D fija sobre un cuarto. Su textura la usan los monitores de
## pared (CamaraMonitor) y la consola (ConsolaCamaras).

const FEED_SIZE := Vector2i(160, 96)

## Nombre del cuarto, se dibuja como etiqueta en los monitores.
var nombre := ""
## Cámara interna (hija de este SubViewport).
var camera: Camera2D


func _init() -> void:
	size = FEED_SIZE
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	gui_disable_input = true
	audio_listener_enable_2d = false


## Comparte `world` y encuadra `focus` (px del mundo) completo y centrado.
func setup(world: World2D, focus: Rect2, nombre_cuarto: String) -> void:
	world_2d = world
	nombre = nombre_cuarto
	if camera == null:
		camera = Camera2D.new()
		add_child(camera)
	camera.position = focus.get_center()
	var z := minf(FEED_SIZE.x / maxf(focus.size.x, 1.0), FEED_SIZE.y / maxf(focus.size.y, 1.0))
	camera.zoom = Vector2(z, z)
	camera.enabled = true
