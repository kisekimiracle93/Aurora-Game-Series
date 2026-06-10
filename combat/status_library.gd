class_name StatusLibrary
extends RefCounted
## Loads StatusData resources by id from data/statuses/<id>.tres.

const STATUS_DIR: String = "res://data/statuses/%s.tres"


static func load_status(status_id: String) -> StatusData:
	var path: String = STATUS_DIR % status_id
	if not ResourceLoader.exists(path):
		push_warning("StatusLibrary: no status resource at %s" % path)
		return null
	return load(path) as StatusData
