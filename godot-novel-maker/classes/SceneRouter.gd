extends Node
class_name SceneRouterService

const MAIN_MENU_SCENE := "res://scenes/main.tscn"
const NOVEL_SCENE := "res://scenes/novel_scene.tscn"


func go_to_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE, "main_menu")


func start_new_game(selected_world: Dictionary = {}, selected_characters: Array = [], selected_player_character: Dictionary = {}) -> void:
	game_state.reset_for_new_game(selected_world, selected_characters, selected_player_character)
	_change_scene(NOVEL_SCENE, "novel_scene")


func continue_from_quick_save() -> void:
	if save_manager.has_quick_save():
		var payload := save_manager.load_quick_save()
		if not payload.is_empty():
			game_state.apply_save_payload(payload)
	else:
		game_state.reset_for_new_game()

	_change_scene(NOVEL_SCENE, "novel_scene")


func load_from_slot(slot_id: int) -> void:
	var payload := save_manager.load_from_slot(slot_id)
	if payload.is_empty():
		return

	game_state.apply_save_payload(payload)
	_change_scene(NOVEL_SCENE, "novel_scene")


func quit_game() -> void:
	get_tree().quit()


func _change_scene(scene_path: String, scene_name: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to change scene to %s (error %d)." % [scene_path, error])
		return

	game_state.set_current_scene_name(scene_name)
