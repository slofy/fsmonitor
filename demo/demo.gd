extends Control


export var open_folder_dialog_path = NodePath()
export var hint_lbl_path = NodePath()
export var current_folder_lbl_path = NodePath()
export var open_folder_btn_path = NodePath()
export var folders_lbl_path = NodePath()
export var files_lbl_path = NodePath()
export var folders_itemlist_path = NodePath()
export var files_itemlist_path = NodePath()
export var output_log_path = NodePath()
export var clear_output_log_btn_path = NodePath()

onready var open_folder_dialog: FileDialog = get_node(open_folder_dialog_path)
onready var hint_lbl: Label = get_node(hint_lbl_path)
onready var current_folder_lbl: Label = get_node(current_folder_lbl_path)
onready var open_folder_btn: Button = get_node(open_folder_btn_path)
onready var folders_lbl: Label = get_node(folders_lbl_path)
onready var files_lbl: Label = get_node(files_lbl_path)
onready var folders_itemlist: ItemList = get_node(folders_itemlist_path)
onready var files_itemlist: ItemList = get_node(files_itemlist_path)
onready var output_log: TextEdit = get_node(output_log_path)
onready var clear_output_log_btn: Button = get_node(clear_output_log_btn_path)

const HINT_LBL_TEMPLATE = "Hint: modify, create, and delete files and folders inside of [%hint%] and watch for changes below :)"

var fsm: FSMonitor

var folders := []
var files := []


func _ready():
	fsm = FSMonitor.new()
	add_child(fsm)
	
	fsm.connect("file_created", self, "_on_fsm_file_created")
	fsm.connect("file_modified", self, "_on_fsm_file_modified")
	fsm.connect("file_deleted", self, "_on_fsm_file_deleted")
	fsm.connect("directory_created", self, "_on_fsm_directory_created")
	fsm.connect("directory_deleted", self, "_on_fsm_directory_deleted")
	
	open_folder_btn.connect("pressed", open_folder_dialog, "popup_centered")
	open_folder_dialog.connect("dir_selected", self, "_on_dir_selected")
	clear_output_log_btn.connect("pressed", output_log, "set_text", [""])


func _on_dir_selected(dir: String) -> void:
	output_log.text = ""
	
	current_folder_lbl.visible = true
	current_folder_lbl.text = dir
	
	hint_lbl.text = HINT_LBL_TEMPLATE.replace("%hint%", dir)
	hint_lbl.visible = true
	
	fsm.watch(dir)
	output_log.text = ""
	
	# Normally you won't directly access the cached directories and files, as FSM provides no structure/hierarchy, just a one dimensional array. If you were building a Tree for example, you'd want to maintain your own structure and index the files initially on your own, then use fsm to check for changes.
	
	# I'd recommend doing it in a separate thread, as the initial index and cache build is roughly 100x slower than the scans that follow (30000ms vs 300ms, sampled on ~1300 files/folders total). This will be fixed soon with the addition of threading in fsmonitor.gd
	folders = fsm.get_cached_dirs()
	files = fsm.get_cached_files()
	
	update_itemlists()


func update_itemlists() -> void:
	folders_itemlist.clear()
	files_itemlist.clear()
	
	for folder_obj in folders:
		folders_itemlist.add_item(folder_obj["absolute_path"])
	
	for file_obj in files:
		files_itemlist.add_item(file_obj["absolute_path"])


func _on_fsm_file_created(file_obj: Dictionary) -> void:
	files.append(file_obj)
	update_itemlists()
	_append_output_log("File created: %s" % file_obj["absolute_path"])


func _on_fsm_file_modified(file_obj: Dictionary) -> void:
	_append_output_log("File modified: %s" % file_obj["absolute_path"])


func _on_fsm_file_deleted(file_obj: Dictionary) -> void:
	_remove_resource(file_obj["absolute_path"], files)
	update_itemlists()
	_append_output_log("File deleted: %s" % file_obj["absolute_path"])


func _on_fsm_directory_created(dir_obj: Dictionary) -> void:
	folders.append(dir_obj)
	update_itemlists()
	_append_output_log("Folder created: %s" % dir_obj["absolute_path"])


func _on_fsm_directory_deleted(dir_obj: Dictionary) -> void:
	_remove_resource(dir_obj["absolute_path"], folders)
	update_itemlists()
	_append_output_log("Folder deleted: %s" % dir_obj["absolute_path"])


# We do this instead of just directly removing the object itself because we are not passing by reference, but instead making copies. Again, something specific to this demo, as in a real project you likely wouldn't be storing the FSM objects, but rather your own mapping of folders and files however you need them.
func _remove_resource(path: String, source: Array) -> void:
	for obj in source:
		if not obj is Dictionary:
			return
		
		if obj["absolute_path"] == path:
			source.erase(obj)


func _append_output_log(message: String) -> void:
	output_log.text += message
	output_log.text += "\n"
	output_log.cursor_set_line(output_log.get_line_count())
