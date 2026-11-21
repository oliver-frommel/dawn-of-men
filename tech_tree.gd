class_name TechTree
extends RefCounted

const BRANCH_NAMES := [
	"WATER & FORAGE",
	"TRAILS & CRAFT",
	"SHELTER & HEARTH"
]

const SKILLS := [
	{
		"id": "plant_lore",
		"name": "Plant Lore",
		"branch": 0,
		"tier": 0,
		"cost": 12,
		"requires": [],
		"landmark": "",
		"min_turn": 0,
		"summary": "+4 food when foraging woodlands or wetlands in the wet season.",
		"chronicle": "SKILL LEARNED  /  Plant Lore. Wet-season woodlands and wetlands yield richer roots and shoots (+4 food)."
	},
	{
		"id": "food_drying",
		"name": "Food Drying",
		"branch": 0,
		"tier": 1,
		"cost": 18,
		"requires": ["plant_lore"],
		"landmark": "",
		"min_turn": 0,
		"summary": "+3 food when foraging inland away from permanent water in the dry season.",
		"chronicle": "SKILL LEARNED  /  Food Drying. Sun-cured stores stretch dry-season foraging away from water (+3 food)."
	},
	{
		"id": "carry_water",
		"name": "Carry Water",
		"branch": 0,
		"tier": 2,
		"cost": 24,
		"requires": ["food_drying"],
		"landmark": "Spring-Fed Riverbank",
		"min_turn": 0,
		"summary": "Entering the dry season inland costs 8 food instead of 10.",
		"chronicle": "SKILL LEARNED  /  Carry Water. Gourds and skins carry spring water inland (dry inland upkeep 8 food)."
	},
	{
		"id": "trail_reading",
		"name": "Trail Reading",
		"branch": 1,
		"tier": 0,
		"cost": 12,
		"requires": [],
		"landmark": "",
		"min_turn": 0,
		"summary": "Scout radius grows from 4 to 5 tiles, and seasonal travel range grows by +2 tiles.",
		"chronicle": "SKILL LEARNED  /  Trail Reading. Game paths and ridgelines extend your scouting and travel range."
	},
	{
		"id": "stone_flaking",
		"name": "Stone Flaking",
		"branch": 1,
		"tier": 1,
		"cost": 18,
		"requires": ["trail_reading"],
		"landmark": "Obsidian Outcrop",
		"min_turn": 0,
		"summary": "+4 food when foraging savanna, dryland, and volcanic terrain in either season.",
		"chronicle": "SKILL LEARNED  /  Stone Flaking. Sharp volcanic edges unlock savanna, dryland, and volcanic foraging (+4 food)."
	},
	{
		"id": "hide_working",
		"name": "Hide Working",
		"branch": 1,
		"tier": 2,
		"cost": 24,
		"requires": ["stone_flaking"],
		"landmark": "",
		"min_turn": 24,
		"summary": "Unlock hide wraps. Gain +2 cohesion after upkeep when entering the dry season inland.",
		"chronicle": "SKILL LEARNED  /  Hide Working. Worked hides shelter travelers inland (+2 cohesion entering dry season inland)."
	},
	{
		"id": "windbreaks",
		"name": "Windbreaks",
		"branch": 2,
		"tier": 0,
		"cost": 12,
		"requires": [],
		"landmark": "",
		"min_turn": 0,
		"summary": "At highland tiles and the Sheltered Cliff, low-food cohesion penalty drops from −3 to −1.",
		"chronicle": "SKILL LEARNED  /  Windbreaks. Stacked brush and stone shelter high camps against lean seasons."
	},
	{
		"id": "hearth_keeping",
		"name": "Hearth Keeping",
		"branch": 2,
		"tier": 1,
		"cost": 20,
		"requires": ["windbreaks"],
		"landmark": "",
		"min_turn": 22,
		"summary": "Practicing at the Sheltered Cliff costs 4 food instead of 8.",
		"chronicle": "SKILL LEARNED  /  Hearth Keeping. A tended fire at the Sheltered Cliff halves practice food cost."
	},
	{
		"id": "ember_carrying",
		"name": "Ember Carrying",
		"branch": 2,
		"tier": 2,
		"cost": 24,
		"requires": ["hearth_keeping"],
		"landmark": "",
		"min_turn": 24,
		"summary": "Practicing anywhere costs at most 6 food (still 4 at the Sheltered Cliff).",
		"chronicle": "SKILL LEARNED  /  Ember Carrying. Live coals travel in bark bundles, lowering practice food cost everywhere."
	}
]


static func get_skill(skill_id: String) -> Dictionary:
	for skill in SKILLS:
		if skill["id"] == skill_id:
			return skill
	return {}


static func unmet_requirements(
	skill: Dictionary,
	learned_skills: Dictionary,
	discovered_landmark_names: Dictionary,
	turn: int
) -> Array[String]:
	var missing: Array[String] = []
	for req_id in skill["requires"]:
		if not learned_skills.has(req_id):
			var req_skill := get_skill(str(req_id))
			missing.append("Requires %s" % str(req_skill.get("name", req_id)))
	var landmark_name: String = skill["landmark"]
	if not landmark_name.is_empty() and not discovered_landmark_names.has(landmark_name):
		missing.append("Discover %s" % landmark_name)
	var min_turn: int = int(skill["min_turn"])
	if turn < min_turn:
		var ka := maxi(0, 3200 - min_turn * 100)
		var era := "%.1f Ma" % (float(ka) / 1000.0) if ka >= 1000 else "%d ka" % ka
		missing.append("Turn %d (%s)" % [min_turn, era])
	return missing


static func can_learn(
	skill: Dictionary,
	learned_skills: Dictionary,
	discovered_landmark_names: Dictionary,
	turn: int,
	knowledge: int,
	action_blocker: String
) -> String:
	if learned_skills.has(skill["id"]):
		return "Already learned."
	if not action_blocker.is_empty():
		return action_blocker
	var missing := unmet_requirements(skill, learned_skills, discovered_landmark_names, turn)
	if not missing.is_empty():
		return " · ".join(missing)
	var cost: int = int(skill["cost"])
	if knowledge < cost:
		return "Requires %d knowledge." % cost
	return ""
