class_name UIKit
extends RefCounted
## Ayudantes para construir paneles con el mismo aspecto.


## Fondo oscuro a pantalla completa + panel centrado con título. Devuelve el VBox de contenido.
static func window(host: Control, title: String, size: Vector2) -> VBoxContainer:
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(GameState.C_BG, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = (Vector2(426, 240) - size) / 2.0
	panel.size = size
	panel.custom_minimum_size = size
	host.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var head := Label.new()
	head.text = title
	head.modulate = GameState.C_YELLOW
	vb.add_child(head)
	var line := ColorRect.new()
	line.color = GameState.C_LINE
	line.custom_minimum_size = Vector2(0, 1)
	vb.add_child(line)
	return vb


static func button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		AudioManager.play("click", -4.0)
		action.call())
	parent.add_child(b)
	return b


static func text(parent: Control, content: String, color := Color("c9d2e0")) -> Label:
	var l := Label.new()
	l.text = content
	l.modulate = color
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(l)
	return l


static func hud(node: Node) -> Node:
	return node.get_tree().get_first_node_in_group("hud")


const CONTROLES := "WASD / flechas .... Moverse\nSHIFT ............. Correr\nE ................. Interactuar\nQ / R ............. Cambiar herramienta\nTAB ............... Inventario\nM ................. Mapa\nESC ............... Pausa\n\nEN EL TABLERO\n2 ................. Medir fusible\nF ................. Cambiar fusible\n1 ................. Energizar\nESPACIO / clic .... Girar nodo"
