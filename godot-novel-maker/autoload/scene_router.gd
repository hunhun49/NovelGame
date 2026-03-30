extends Node

const MAIN_MENU_SCENE := "res://scenes/main.tscn"
const NOVEL_SCENE := "res://scenes/novel_scene.tscn"


func go_to_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE, "main_menu")


func start_new_game() -> void:
	GameState.reset_for_new_game()
	_change_scene(NOVEL_SCENE, "novel_scene")


func continue_from_quick_save() -> void:
	if SaveManager.has_quick_save():
		var payload := SaveManager.load_quick_save()
		if not payload.is_empty():
			GameState.apply_save_payload(payload)
	else:
		GameState.reset_for_new_game()

	_change_scene(NOVEL_SCENE, "novel_scene")


func quit_game() -> void:
	get_tree().quit()


func _change_scene(scene_path: String, scene_name: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to change scene to %s (error %d)." % [scene_path, error])
		return

	GameState.set_current_scene_name(scene_name)
