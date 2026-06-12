class_name HDAssets
extends RefCounted
## Loaders for the 3D kits (KayKit dungeon FBX, KayKit medieval OBJ,
## Quaternius nature FBX). Every mesh gets the kit's atlas forced as its
## material so colors survive any import quirk. 1 world unit = 64 px.

const PX: float = 64.0

static var _material_cache: Dictionary = {}


static func to3d(px: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(px.x / PX, height, px.y / PX)


static func _atlas_material(atlas_path: String) -> StandardMaterial3D:
	if _material_cache.has(atlas_path):
		return _material_cache[atlas_path]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	if atlas_path != "" and ResourceLoader.exists(atlas_path):
		material.albedo_texture = load(atlas_path)
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0
	_material_cache[atlas_path] = material
	return material


## Loads an .obj (Mesh) or .fbx/.glb (PackedScene) into a ready Node3D,
## with the kit atlas overriding every surface.
static func model(path: String, atlas_path: String = "") -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	var root: Node3D
	if resource is PackedScene:
		root = (resource as PackedScene).instantiate()
	elif resource is Mesh:
		var holder: MeshInstance3D = MeshInstance3D.new()
		holder.mesh = resource
		root = holder
	else:
		return null
	if atlas_path != "":
		_apply_atlas(root, _atlas_material(atlas_path))
	return root


static func _apply_atlas(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child: Node in node.get_children():
		_apply_atlas(child, material)


static func medieval(model_name: String) -> Node3D:
	return model(
		"res://assets/kits3d/medieval/%s.obj" % model_name,
		"res://assets/kits3d/medieval/hexagons_medieval.png"
	)


static func dungeon(model_name: String) -> Node3D:
	return model(
		"res://assets/kits3d/dungeon/%s.fbx" % model_name,
		"res://assets/kits3d/dungeon/dungeon_texture.png"
	)


static func nature(model_name: String) -> Node3D:
	return model(
		"res://assets/kits3d/nature/%s.fbx" % model_name,
		"res://assets/kits3d/nature/forest_texture.png"
	)
