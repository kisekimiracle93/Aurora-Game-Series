class_name AbilitiesComponent
extends Node
## The combatant's unlocked abilities (AbilityData resources).

var _abilities: Array[AbilityData] = []


func add_ability(ability: AbilityData) -> void:
	if ability != null and find_by_id(ability.id) == null:
		_abilities.append(ability)


func get_all() -> Array[AbilityData]:
	return _abilities


func find_by_id(ability_id: String) -> AbilityData:
	for ability: AbilityData in _abilities:
		if ability.id == ability_id:
			return ability
	return null


## Skills/spells shown in the Skill submenu (everything but the basic attack/guard).
func get_skills() -> Array[AbilityData]:
	var skills: Array[AbilityData] = []
	for ability: AbilityData in _abilities:
		if ability.ability_type == "spell" or ability.ability_type == "support":
			skills.append(ability)
	return skills


func get_echoes() -> Array[AbilityData]:
	var echoes: Array[AbilityData] = []
	for ability: AbilityData in _abilities:
		if ability.ability_type == "echo":
			echoes.append(ability)
	return echoes
