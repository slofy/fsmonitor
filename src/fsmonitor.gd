extends Node
class_name FSMonitor


signal file_created(file_obj)
signal file_deleted(file_obj)
signal file_modified(file_obj)

signal directory_created(dir_obj)
signal directory_deleted(dir_obj)

signal on_error(message)


var _directory: String = ""
var _indexed_files_cache: Array = []
var _indexed_dirs_cache: Array = []

var _timer: Timer
var _delay: float = 5.0

var _thread: Thread
var _mutex: Mutex
var _semaphore: Semaphore
var _should_exit: bool = false
var _thread_working: bool = false

var _abort_recursive_index: bool = false


func _ready() -> void:
	_timer = Timer.new()
	_timer.connect("timeout", self, "_on_timer_timeout")
	add_child(_timer)

	_thread = Thread.new()
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()

	_thread.start(self, "_thread_func")


func abort_recursive() -> void:
	_abort_recursive_index = true


func watch(path: String, delay: float = 5.0) -> void:
	_mutex.lock()
	var thread_working = _thread_working
	_mutex.unlock()
	if thread_working:
		print("[WATCH] - thread is working, we must abort it first")
		abort_recursive()
	
	_mutex.lock()
	_directory = path
	_mutex.unlock()
	_delay = delay
	_timer.wait_time = _delay
	_timer.paused = true
	
#	_indexed_files_cache.clear()
#	_indexed_dirs_cache.clear()
	
	_semaphore.post()

	_timer.paused = false
	_timer.start(_delay)


func _on_timer_timeout() -> void:
	if not _directory:
		return
		
	# _map_dir_contents(_directory)

	# Might need to lock here too?
	if _thread_working:
		print("TIMER::TIMEOUT thread is still working")
		return
	
	_semaphore.post()
	print("TIMER::TIMEOUT semaphore:post")


func _map_dir_contents(dir: String) -> void:
	_validate_caches()
	_index_dir_recursive(dir)


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
			call_deferred("emit_signal", "file_modified", file_obj.duplicate())
	
	var d: Directory = Directory.new()
	var dirs_to_delete = []
	for dir_obj in _indexed_dirs_cache:
		var absolute_path = dir_obj["absolute_path"]
		
		if not d.dir_exists(absolute_path):
			dirs_to_delete.append(dir_obj)
	
	for file_obj in files_to_delete:
		_indexed_files_cache.erase(file_obj)
		call_deferred("emit_signal", "file_deleted", file_obj.duplicate())

	for dir_obj in dirs_to_delete:
		_indexed_dirs_cache.erase(dir_obj)
		call_deferred("emit_signal", "directory_deleted", dir_obj.duplicate())


func _index_dir_recursive(dir: String) -> void:
	if _abort_recursive_index:
		print("ABORTING RECURSIVE INDEX")
		return
	
	var directory_stream: Directory = Directory.new()
	if directory_stream.open(dir) != OK:
		call_deferred("emit_signal", "on_error", "Error opening directory [%s]" % dir)
		return
	
	directory_stream.list_dir_begin(true)
	
	var next = directory_stream.get_next()
	while next != "":
		_mutex.lock()
		var should_exit = _should_exit
		_mutex.unlock()
		if should_exit:
			break

		var file: File = File.new()
		var new_path = dir.plus_file(next)
		var tmp_obj = {
			"name": next,
			"absolute_path": new_path,
			"modified_at": file.get_modified_time(new_path)
		}
		if directory_stream.current_is_dir():
			if not _resource_is_cached(new_path, _indexed_dirs_cache):
				_mutex.lock()
				_indexed_dirs_cache.append(tmp_obj)
				_mutex.unlock()
				call_deferred("emit_signal", "directory_created", tmp_obj.duplicate())
			
			_index_dir_recursive(new_path)
		else:
			if not _resource_is_cached(new_path, _indexed_files_cache):
				_mutex.lock()
				_indexed_files_cache.append(tmp_obj)
				_mutex.unlock()
				call_deferred("emit_signal", "file_created", tmp_obj.duplicate())
		
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


func _thread_func() -> void:
	while true:
		_semaphore.wait()

		print("POSTED")

		_mutex.lock()
		var should_exit = _should_exit
		var dir = _directory
		var thread_working = _thread_working
		_mutex.unlock()

		if should_exit:
			break

		# Maybe emit an error for invalid dir path?
		if dir == "" || thread_working:
			print("skipping thread func cuz thread still working")
			return
		
		_mutex.lock()
		_abort_recursive_index = false
		_thread_working = true
		_indexed_files_cache.clear()
		_indexed_dirs_cache.clear()
		_mutex.unlock()
		
		_map_dir_contents(dir)

		_mutex.lock()
		_thread_working = false
		_mutex.unlock()


func _exit_tree() -> void:
	_mutex.lock()
	_should_exit = true
	_mutex.unlock()

	_semaphore.post()

	_thread.wait_to_finish()
