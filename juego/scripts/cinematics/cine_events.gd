class_name CineEvents
extends RefCounted
## Eventos de guion compartidos por las cinemáticas a pantalla completa (cinematic.gd)
## y las escenas dentro de un nivel (zona_02.gd). Formato de data/cinematica*.json:
## narra, radio, hora, capitulo, sfx, loop, fade_loop, silencio y accion.


## Ejecuta un evento. Las acciones propias de la escena se delegan a `on_action`.
static func fire(e: Dictionary, on_action: Callable) -> void:
	if e.has("narra"):
		Narrator.say(e["narra"], float(e.get("hold", 2.0)))
	elif e.has("radio"):
		Narrator.line(e["radio"][0], e["radio"][1], float(e.get("hold", 1.5)), bool(e.get("arriba", false)))
	elif e.has("hora"):
		Narrator.stamp(e["hora"], float(e.get("hold", 3.0)))
	elif e.has("capitulo"):
		Narrator.chapter_card(e["capitulo"][0], e["capitulo"][1])
	elif e.has("sfx"):
		AudioManager.play(e["sfx"], float(e.get("vol", 0.0)))
	elif e.has("loop"):
		AudioManager.loop(e["loop"], float(e.get("vol", 0.0)), e.get("bus", "Ambiente"))
	elif e.has("fade_loop"):
		AudioManager.fade_loop(e["fade_loop"], float(e["vol"]), float(e.get("tiempo", 1.5)))
	elif e.has("silencio"):
		AudioManager.stop_loops()
	elif e.has("accion"):
		on_action.call(e["accion"])
