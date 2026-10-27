class_name Interactable
extends Area2D
## Zona con la que Leo puede interactuar con [E]. El dueño conecta `interacted`.

signal interacted(player: Node2D)

const LAYER := 2

var prompt := "Interactuar"
var enabled := true


static func create(center: Vector2, size: Vector2, prompt_text: String) -> Interactable:
	var it := Interactable.new()
	it.position = center
	it.prompt = prompt_text
	it.collision_layer = LAYER
	it.collision_mask = 0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	shape.shape = r
	it.add_child(shape)
	it.add_to_group("interactable")
	return it


func interact(player: Node2D) -> void:
	if enabled:
		interacted.emit(player)
