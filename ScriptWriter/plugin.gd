tool
extends EditorPlugin


const WAKE = "#/" 

var from_script : String  # path
var current_text_edit : TextEdit
var timer : Timer


# VIRTUAL FUNCTIONS ————————————————————————————————————————————————————————————————————————————————
func _enter_tree():
	
	var editor_interface = get_editor_interface()
	var script_editor = editor_interface.get_script_editor()
	
	script_editor.connect("editor_script_changed", self, "_on_editor_script_changed")
	
	timer = Timer.new() # setup typing timer
	add_child(timer)
	timer.set_one_shot(true)


func _exit_tree():
	pass


# SCRIPT PARSING FUNCTIONS —————————————————————————————————————————————————————————————————————————
func _on_editor_script_changed(script):
	var editor_interface = get_editor_interface()
	var script_editor = editor_interface.get_script_editor()
	var textEdit = get_active_text_edit(script_editor)
	
	if !textEdit.is_connected("text_changed", self, "_on_script_text_changed"):
		if is_instance_valid(current_text_edit):
			current_text_edit.disconnect("text_changed", self, "_on_script_text_changed")
		textEdit.connect("text_changed", self, "_on_script_text_changed", [textEdit])
	
	current_text_edit = textEdit


func _on_script_text_changed(textEdit:TextEdit):
	if WAKE + "clear" in textEdit.text:
		textEdit.text = ""
	
	elif WAKE + "from" in textEdit.text:
		from_script = textEdit.text
		save_settings()
		print("From script successfully saved")
	
	elif WAKE + "to" in textEdit.text:
		if !from_script:
			print("NO from SCRIPT DETECTED")
			return
		
		textEdit.set_text("") # clear TO script
		
		load_settings()
		var script = parse_script_text(from_script)
		write_to(script, textEdit)


func write_to(script:Array, textEdit:TextEdit, cpm:int=1000) -> void:
	timer.set_wait_time(60.0 / cpm) # set time between characrters by chars per minute
	
	var settings = get_editor_interface().get_editor_settings() # "turn off" code suggestions
	var prev_delay = settings.get("text_editor/completion/code_complete_delay")
	settings.set_setting("text_editor/completion/code_complete_delay", 5.0)
	settings.emit_signal("settings_changed")
	
	for block_num in script.size():
		for block in script:
			if block[0] == block_num:
				for character in block[1]:
					timer.start()
					yield(timer, "timeout")
					textEdit.text += character
					
					var line_count = textEdit.text.count("\n")
					textEdit.cursor_set_line(line_count)
					textEdit.cursor_set_column(textEdit.text.split("\n")[line_count].length())
	
	settings.set_setting("text_editor/completion/code_complete_delay", prev_delay)


func parse_script_text(text:String) -> Array:
	# returns an 2D array of [block_num:int, block_text:String], with the idx corresponding
	# to the order of the blocks in the script.  The minimum block_num will always be 0.
	var blocks := []
	
	var blocks_raw := text.split(WAKE)
	for block in blocks_raw:
		if block and block[0].is_valid_integer():
			var block_num = int(block[0])
			
			block = PoolStringArray(block.split("\n"))
			block.remove(0) # remove line with WAKE word
			block = block.join("\n")
			
			blocks.append([block_num, block])
	
	if blocks: # make 0 the min block_num
		var block_nums := []
		for block in blocks:
			block_nums.append(block[0])
		var min_block_num = block_nums.min()
		
		if min_block_num > 0:
			for block in blocks:
				block[0] -= min_block_num
	else:
		blocks = [[0, text]]

	return blocks

#func parse_script_text(text:String):
#	var blocks := {}
#
#	var lines = text.split("\n")
#	for line_num in lines.size():
#		var line : String = lines[line_num]
#		if line and line.begins_with(WAKE) and line[2].is_valid_integer(): # is block
#			var block_num = int(line[2])
#			if not blocks.has(block_num): # make it a key if not already
#				blocks[block_num] = {
#					"line_nums" : [],
#					"texts" : []
#				}
#			blocks.get(block_num).get("line_nums").append(line_num)
#
#	var blocks_raw := text.split(WAKE)
#	for block in blocks_raw:
#		if block and block[0].is_valid_integer():
#			var block_num = int(block[0])
#			block = PoolStringArray(block.split("\n"))
#			block.remove(0)
#			block = block.join("\n")
#			blocks.get(block_num).get("texts").append(block)
#
#	print(blocks.get(1).get("texts"))
#
#	return blocks


#func get_script_text(path:String):
#	var file = File.new()
#	file.open(path, File.READ)
#	var content = file.get_as_text()
#	file.close()
#	return content


# SAVE/LOAD SETTINGS FUNCTIONS —————————————————————————————————————————————————————————————————————
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


# GET ACTIVE TEXTEDIT FUNCTIONS ————————————————————————————————————————————————————————————————————
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
