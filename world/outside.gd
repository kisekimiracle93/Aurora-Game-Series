extends AreaBase
## The outside area: open crystal fields between town and the dungeon.
## Step-based random encounters with the M4 roster.


func _init() -> void:
	area_name = "THE CRYSTAL FIELDS — wolves prowl the snow"
	music_track = "world"
	encounters_enabled = true
	encounter_rosters = [
		"wolves_2", "wolves_3", "stag_hunt", "wolfpack",
	] as Array[String]


func _setup_area() -> void:
	add_rect(Rect2(0, 0, 1280, 720), Color(0.55, 0.6, 0.66), -10)  # snowfield
	add_rect(Rect2(0, 330, 1280, 90), Color(0.45, 0.42, 0.38, 0.8), -9)  # trail

	# Scattered ice crystals and pines (solid).
	for crystal_pos: Vector2 in [
		Vector2(300, 160), Vector2(560, 520), Vector2(880, 200), Vector2(1080, 560),
		Vector2(180, 600), Vector2(720, 120),
	]:
		var shard: Polygon2D = Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(0, -26), Vector2(12, 8), Vector2(0, 18), Vector2(-12, 8)
		])
		shard.color = Color(0.6, 0.85, 0.95, 0.9)
		shard.position = crystal_pos
		shard.z_index = 2
		add_child(shard)
		add_wall(Rect2(crystal_pos - Vector2(12, 10), Vector2(24, 28)))
	for tree_pos: Vector2 in [Vector2(430, 90), Vector2(960, 640), Vector2(120, 300)]:
		var pine: Polygon2D = Polygon2D.new()
		pine.polygon = PackedVector2Array([
			Vector2(0, -44), Vector2(26, 18), Vector2(-26, 18)
		])
		pine.color = Color(0.12, 0.3, 0.22)
		pine.position = tree_pos
		pine.z_index = 2
		add_child(pine)
		add_wall(Rect2(tree_pos - Vector2(18, 0), Vector2(36, 18)))

	var hint: Label = Label.new()
	hint.text = "Wander the fields and the wild will find you..."
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.3, 0.3, 0.35)
	hint.position = Vector2(16, 690)
	add_child(hint)

	# West back to town; east into the crystal site.
	add_exit(Rect2(0, 300, 40, 150), "res://world/town.tscn", Vector2(1180, 370))
	add_exit(Rect2(1240, 300, 40, 150), "res://world/dungeon.tscn", Vector2(100, 360))
	var west: Label = Label.new()
	west.text = "< Aethertown"
	west.position = Vector2(50, 270)
	west.add_theme_font_size_override("font_size", 14)
	add_child(west)
	var east: Label = Label.new()
	east.text = "Crystal site >"
	east.position = Vector2(1120, 270)
	east.add_theme_font_size_override("font_size", 14)
	add_child(east)
