tool
extends EditorPlugin


const WAKE = "#/" 

var from_script : String  # path
var current_text_edit : TextEdit
var timer : Timer


func _enter_tree():
	var editor_interface = get_editor_interface()
	var script_editor = editor_interface.get_script_editor()
	
	script_editor.connect("editor_script_changed", self, "_on_editor_script_changed")
	
	load_settings()


func _exit_tree():
	pass


func _on_editor_script_changed(script):
	var editor_interface = get_editor_interface()
	var script_editor = editor_interface.get_script_editor()
	
	var textEdit = get_active_text_edit(script_editor)
	
	if !textEdit.is_connected("text_changed", self, "_on_text_changed"):
		if is_instance_valid(current_text_edit):
			current_text_edit.disconnect("text_changed", self, "_on_text_changed")
		textEdit.connect("text_changed", self, "_on_text_changed", [textEdit])
	
	current_text_edit = textEdit


func _on_text_changed(textEdit:TextEdit):
	if WAKE + "from" in textEdit.text:
		from_script = get_editor_interface().get_script_editor().get_current_script().get_path()
		print("%s successfully added" % from_script)
		save_settings()
	
	if WAKE + "to" in textEdit.text and from_script:
		textEdit.set_text("") # clear TO script
		
		timer = Timer.new() # setup typing timer
		add_child(timer)
		timer.set_wait_time(.05)
		timer.set_one_shot(true)
		
		var settings = get_editor_interface().get_editor_settings() # "turn off" autocomplete
		var prev_delay = settings.get("text_editor/completion/code_complete_delay")
		settings.set_setting("text_editor/completion/code_complete_delay", 5.0)
		settings.emit_signal("settings_changed")
		
		for character in get_script_text(from_script):
			timer.start()
			yield(timer, "timeout")
			textEdit.text += character
			
			var line_count = textEdit.text.count("\n")
			textEdit.cursor_set_line(line_count)
			textEdit.cursor_set_column(textEdit.text.split("\n")[line_count].length())
		
		settings.set_setting("text_editor/completion/code_complete_delay", prev_delay)


func parse_text(text:String):
	pass


func get_script_text(path:String):
	var file = File.new()
	file.open(path, File.READ)
	var content = file.get_as_text()
	file.close()
	return content


# SAVE/LOAD SETTINGS ———————————————————————————————————————————————————————————————————————————————
func load_settings():
	var path = get_config_path()
	var dir = Directory.new()
	var config = ConfigFile.new()
	
	if dir.file_exists(path):
		var ERR = config.load(path)
		if ERR == OK:
			from_script = config.get_value("settings", "from_path")
		else:
			push_error("ScriptWriter plugin unable to load settings. ERR = %s" % ERR)
	else:
		dir.make_dir_recursive(path.get_base_dir())
		config.save(path)

func save_settings():
	if from_script:
		var config = ConfigFile.new()
		config.set_value("settings", "from_path", from_script)
		config.save(get_config_path())
	else:
		push_error("ScriptWriter plugin unable to save settings.  from_script == null")

func get_config_path():
	var dir = get_editor_interface().get_editor_settings().get_project_settings_dir()
	var path = dir.plus_file("ScriptWriter/ScriptWriterSave.cfg")
	return path


# GET ACTIVE TEXTEDIT FUNCS ————————————————————————————————————————————————————————————————————————
func find_all_nodes_by_name(root, name) -> Array:
	var found_nodes : Array
	if(name in root.get_name()): found_nodes.append(root)
	for child in root.get_children():
		found_nodes.append_array(find_all_nodes_by_name(child, name))
	return found_nodes


func fetch_all_script_text_editors(script_editor) -> Array:
	var found_script_text_editors : Array
	found_script_text_editors = find_all_nodes_by_name(script_editor, "ScriptTextEditor")
	return found_script_text_editors


func get_active_text_edit(script_editor) -> TextEdit:
	for script_text_editor in fetch_all_script_text_editors(script_editor):
		if script_text_editor.is_visible():
			return script_text_editor.get_node("VSplitContainer/CodeTextEditor/TextEdit")
	return null
