extends SceneTree
## Comprobación rápida: ¿arranca la escena principal y dibuja algo?

var frames := 0


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 30:
		var img := root.get_texture().get_image()
		img.save_png("C:/Users/WOLF/AppData/Local/Temp/claude/D--Laboratorio-de-Apps-Writer-Fighter/b6b40e15-7ce6-4d88-98dc-61b51c96a3b1/scratchpad/arranque.png")
		print("escena actual: ", current_scene.name if current_scene != null else "NINGUNA")
		return true
	return false
