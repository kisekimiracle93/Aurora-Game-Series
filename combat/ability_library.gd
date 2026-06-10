class_name AbilityLibrary
extends RefCounted
## Loads AbilityData resources by id from data/abilities/<id>.tres.

const ABILITY_DIR: String = "res://data/abilities/%s.tres"


static func load_ability(ability_id: String) -> AbilityData:
	var path: String = ABILITY_DIR % ability_id
	if not ResourceLoader.exists(path):
		push_warning("AbilityLibrary: no ability resource at %s" % path)
		return null
	return load(path) as AbilityData


static func load_many(ability_ids: Array[String]) -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for ability_id: String in ability_ids:
		var ability: AbilityData = load_ability(ability_id)
		if ability != null:
			result.append(ability)
	return result
