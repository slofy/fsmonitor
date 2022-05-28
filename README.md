# Godot Filesystem Monitor

Monitors a directory for the following changes:
- New files
- Deleted files
- Modified files
- New folders
- Deleted folders

Usage:

```gdscript
# main.gd
extends Node


var fsm: FSMonitor


func _ready():
	fsm = FSMonitor.new()
	add_child(fsm)
	
	fsm.connect("file_created", self, "_on_fsm_file_created")
	fsm.connect("file_modified", self, "_on_fsm_file_modified")
	fsm.connect("file_deleted", self, "_on_fsm_file_deleted")
	fsm.connect("directory_created", self, "_on_fsm_directory_created")
	fsm.connect("directory_deleted", self, "_on_fsm_directory_deleted")
```

See [`demo/`](/demo) for a detailed example.

## Limitations
- Renaming a file or folder will emit a `*_deleted` and `*_created` signal instead of a `*_modified` signal, as there's currently no way to track the filesystem resources themselves. FSMonitor works by keeping a cache of all known folder and file paths in the root folder you're watching.
- Similarly, cut/paste/drag & drop actions will emit deleted and created signals as well.
- Initial indexing of a folder and all of its children may be slow. Quick testing showed that for a folder with a total of ~1,300 files and folders, the initial index took around 30,000ms. Follow up scans of the directory took around 300ms. An update with thread support soon should help prevent initial indexes causing the application to freeze on large folders.

## Future Features
- Thread support for indexing
- Manually updating the caches without emitting signals
- Optionally disabling the automatic scans via a Timer node, and instead manually triggering the scans whenever required
- The ability to exclude files and folders via regex pattern matching

## License

MIT License (MIT). Please view [LICENSE](LICENSE) for more information.
