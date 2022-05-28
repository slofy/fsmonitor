extends Node
class_name FSMonitor


signal file_created(file_obj)
signal file_deleted(file_obj)
signal file_modified(file_obj)

signal directory_created(dir_obj)
signal directory_deleted(dir_obj)

signal on_error(message)


var _directory: String = ""
var _indexed_files_cache := []
var _indexed_dirs_cache := []

var _timer: Timer
var _delay: float = 5.0


func _ready() -> void:
	_timer = Timer.new()
	_timer.connect("timeout", self, "_on_timer_timeout")
	add_child(_timer)


func watch(path: String, delay: float = 5.0) -> void:
	_directory = path
	_delay = delay
	_timer.wait_time = _delay
	_timer.paused = true
	
	_indexed_files_cache.clear()
	_indexed_dirs_cache.clear()
	
	_map_dir_contents(_directory)
	
	_timer.paused = false
	_timer.start(_delay)


func _on_timer_timeout() -> void:
	if not _directory:
		return
		
	_map_dir_contents(_directory)


func _map_dir_contents(dir: String) -> void:
	# var total_time = 0
	# var start_time = OS.get_ticks_msec()
	# print("begin - %s" % str(start_time))
	_validate_caches()
	_index_dir_recursive(dir)
	# var end_time = OS.get_ticks_msec()
	# print("end - %s" % str(end_time))
	# total_time = end_time - start_time
	# print("total time in msec: %s" % str(total_time))


func _validate_caches() -> void:
	if _indexed_files_cache.empty() and _indexed_dirs_cache.empty():
		return
	
	var f: File = File.new()
	var files_to_delete = []
	for file_obj in _indexed_files_cache:
		var absolute_path = file_obj["absolute_path"]
		
		if not f.file_exists(absolute_path):
			files_to_delete.append(file_obj)
			continue
		
		var modified_at = f.get_modified_time(absolute_path)
		
		if modified_at != file_obj["modified_at"]:
			file_obj["modified_at"] = modified_at
			emit_signal("file_modified", file_obj.duplicate())
	
	var d: Directory = Directory.new()
	var dirs_to_delete = []
	for dir_obj in _indexed_dirs_cache:
		var absolute_path = dir_obj["absolute_path"]
		
		if not d.dir_exists(absolute_path):
			dirs_to_delete.append(dir_obj)
	
	for file_obj in files_to_delete:
		_indexed_files_cache.erase(file_obj)
		emit_signal("file_deleted", file_obj.duplicate())

	for dir_obj in dirs_to_delete:
		_indexed_dirs_cache.erase(dir_obj)
		emit_signal("directory_deleted", dir_obj.duplicate())


func _index_dir_recursive(dir: String) -> void:
	var directory_stream: Directory = Directory.new()
	if directory_stream.open(dir) != OK:
		emit_signal("on_error", "Error opening directory [%s]" % dir)
		return
	
	directory_stream.list_dir_begin(true)
	
	var next = directory_stream.get_next()
	while next != "":
		var file: File = File.new()
		var new_path = dir.plus_file(next)
		var tmp_obj = {
			"name": next,
			"absolute_path": new_path,
			"modified_at": file.get_modified_time(new_path)
		}
		if directory_stream.current_is_dir():
			if not _resource_is_cached(new_path, _indexed_dirs_cache):
				_indexed_dirs_cache.append(tmp_obj)
				emit_signal("directory_created", tmp_obj.duplicate())
			
			_index_dir_recursive(new_path)
		else:
			if not _resource_is_cached(new_path, _indexed_files_cache):
				_indexed_files_cache.append(tmp_obj)
				emit_signal("file_created", tmp_obj.duplicate())
		
		next = directory_stream.get_next()
	
	directory_stream.list_dir_end()


func _resource_is_cached(path: String, cache: Array) -> bool:
	for obj in cache:
		if not obj is Dictionary:
			continue
		
		if obj.get("absolute_path") == path:
			return true
		
	return false


func get_cached_files() -> Array:
	return _indexed_files_cache.duplicate(true)


func get_cached_dirs() -> Array:
	return _indexed_dirs_cache.duplicate(true)
