class_name SaveStore
extends RefCounted
const VERSION = 1
var path: String
func _init(location: String = "user://frontier.save"):
	path = location
func write(data: Dictionary) -> Error:
	var payload := JSON.stringify(data)
	var envelope := JSON.stringify({"version": VERSION, "sha256": payload.sha256_text(), "payload": payload})
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(envelope)
	file.flush()
	file.close()
	if _read_one(path).size() > 0:
		var backup_error := DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK: return backup_error
	return DirAccess.rename_absolute(path + ".tmp", path)
func _read_one(location: String) -> Dictionary:
	if not FileAccess.file_exists(location): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(location)) != OK: return {}
	var raw = parser.data
	if not raw is Dictionary or raw.get("version") != VERSION: return {}
	var payload = raw.get("payload", "")
	if not payload is String or payload.sha256_text() != raw.get("sha256"): return {}
	if parser.parse(payload) != OK: return {}
	var data = parser.data
	if not data is Dictionary: return {}
	if not data.get("seed") is float and not data.get("seed") is int: return {}
	if not data.get("edits") is Dictionary or not data.get("inventory") is Array: return {}
	var inventory := Inventory.new()
	if not inventory.restore(data.inventory): return {}
	var pos = data.get("position")
	if not pos is Array or pos.size() != 2: return {}
	for v in pos:
		if not (v is float or v is int) or not is_finite(float(v)): return {}
	for k in data.edits:
		var parts = str(k).split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return {}
		var id = data.edits[k]
		if not (id is float or id is int) or id < 0 or id > 4 or id != int(id): return {}
	return data
func read() -> Dictionary:
	var data := _read_one(path)
	return _read_one(path + ".bak") if data.is_empty() else data
