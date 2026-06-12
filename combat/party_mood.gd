class_name PartyMood
extends RefCounted
## Reads the four meters into plain words for the in-game menu's condition
## tracker: who is confident, who is grieving, who is slipping — and where
## the party stands as a whole. Pure functions; the menu just prints them.

## WIP formula (owner-sanctioned placeholder): courage carries, conviction
## steadies, grief and the dark drag hardest.
static func member_score(resolve: float, duty: float, burden: float, darkness: float) -> float:
	return resolve + duty * 0.3 - burden * 0.7 - darkness * 0.4


## The dominant note in one pilgrim's head, worst weights first.
static func member_state(
	resolve: float, duty: float, burden: float, darkness: float, is_heir: bool
) -> String:
	if is_heir and darkness >= 60.0:
		return "slipping into the dark"
	if burden >= 70.0:
		return "buried in grief"
	if burden >= 45.0:
		return "carrying too much"
	if is_heir and darkness >= 35.0:
		return "hearing the ice"
	if resolve >= 85.0:
		return "burning with conviction" if duty >= 60.0 else "fearless"
	if resolve >= 70.0:
		return "confident"
	if resolve >= 55.0:
		return "steady"
	if resolve >= 40.0:
		return "unsure"
	if resolve >= 25.0:
		return "wavering"
	return "breaking"


## meters_by_name: {"Bastil": {"resolve": .., "duty": .., "burden": .., "darkness": ..}, ...}
static func party_state(meters_by_name: Dictionary) -> String:
	if meters_by_name.is_empty():
		return "The party is ready."
	var total: float = 0.0
	for member_name: String in meters_by_name:
		var meters: Dictionary = meters_by_name[member_name]
		total += member_score(
			float(meters.get("resolve", 60.0)), float(meters.get("duty", 50.0)),
			float(meters.get("burden", 0.0)), float(meters.get("darkness", 0.0))
		)
	var average: float = total / float(meters_by_name.size())
	if average >= 100.0:
		return "The party stands greatly resolved."
	if average >= 78.0:
		return "The party stands resolved."
	if average >= 55.0:
		return "The party is ready."
	if average >= 38.0:
		return "The party is strained."
	if average >= 22.0:
		return "The party is burdened."
	return "The party is near breaking."


## A reading color for each state family (gold > green > grey > red > violet).
static func state_color(state: String) -> Color:
	if state.contains("dark") or state.contains("ice"):
		return Color(0.72, 0.5, 0.9)
	if state.contains("grief") or state.contains("carrying") or state in ["breaking", "wavering"]:
		return Color(0.9, 0.45, 0.4)
	if state.contains("conviction") or state == "fearless":
		return Color(1.0, 0.85, 0.35)
	if state in ["confident", "steady"]:
		return Color(0.55, 0.85, 0.55)
	return Color(0.75, 0.75, 0.7)
