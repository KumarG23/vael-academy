class_name ArenaController
extends RefCounted
## AW-43: the magical Arena — Kai alone against escalating waves. Once a week,
## no one truly dies (story armour), and clearing waves both LEVELS KAI UP (real
## XP) and pays out extra credit / items that scale with how deep he gets. The
## foes are ARENA-ONLY archetypes, built here in code and never authored as unit
## files, so they can't leak into the campaign. Waves are procedural + endless —
## you push as far as you can, then retreat with your winnings.

# archetype -> class / weapon / base statline. Stats scale up each wave.
# `sprite` = the existing unit whose walk frames this archetype borrows
# (AW-48, via UnitDef.sprite_id) — arena foes are real sprites, not tokens.
const ARCHETYPES := {
	"grunt":   {"cls": "brigand", "wpn": "iron_axe", "sprite": "bandit_a", "name": "Arena Grunt", "hp": 26, "str": 6, "skl": 4, "spd": 5, "def": 4, "res": 1, "mov": 5},
	"soldier": {"cls": "soldier", "wpn": "iron_lance", "sprite": "tm_soldier_a", "name": "Arena Soldier", "hp": 30, "str": 7, "skl": 6, "spd": 6, "def": 6, "res": 2, "mov": 5},
	"brute":   {"cls": "fighter", "wpn": "iron_axe", "sprite": "bandit_c", "name": "Arena Brute", "hp": 40, "str": 9, "skl": 4, "spd": 3, "def": 8, "res": 1, "mov": 5},
	"marksman":{"cls": "archer", "wpn": "iron_bow", "sprite": "tm_scout", "name": "Arena Marksman", "hp": 24, "str": 6, "skl": 8, "spd": 7, "def": 4, "res": 3, "mov": 5},
	"beast":   {"cls": "beast", "wpn": "claw", "sprite": "nilu", "name": "Arena Direbeast", "hp": 30, "str": 8, "skl": 7, "spd": 9, "def": 4, "res": 2, "mov": 7},
	"wraith":  {"cls": "mage", "wpn": "fire", "sprite": "tm_adept", "name": "Arena Wraith", "hp": 22, "mag": 9, "skl": 6, "spd": 6, "def": 3, "res": 6, "mov": 5},
}
# what shows up, wave by wave — new, nastier archetypes unlock as you climb.
const UNLOCK := [
	["grunt"],                                # w1
	["grunt", "soldier"],                     # w2
	["soldier", "marksman"],                  # w3
	["soldier", "brute", "marksman"],         # w4
	["brute", "beast", "marksman"],           # w5
	["brute", "beast", "wraith", "soldier"],  # w6+
]


## The enemy count for a wave — grows with depth, capped by the spawn ring.
## AW-50 tuning: waves start at 3 — the old 2-foe openers died to Kai's counters
## inside a single enemy phase, so every turn LOOKED like a new round.
static func wave_count(wave: int, max_slots: int) -> int:
	return clampi(2 + wave, 1, max_slots)


## Build one arena foe of `arch`, stat-scaled for `wave` (index keeps ids unique).
static func make_enemy(arch: String, wave: int, idx: int) -> UnitDef:
	var a: Dictionary = ARCHETYPES[arch]
	var d := UnitDef.new()
	d.id = "arena_%s_w%d_%d" % [arch, wave, idx]
	d.display_name = a["name"]
	d.char_class = load("res://data/classes/%s.tres" % a["cls"])
	d.weapon = load("res://data/weapons/%s.tres" % a["wpn"])
	d.team = 1
	d.house_id = "arena"
	d.sprite_id = a["sprite"]  # AW-48: borrow real walk frames — no letter tokens
	d.ai_behavior = AIBrain.Behavior.AGGRESSOR
	var s := 1.0 + wave * 0.11   # ~11% stronger per wave
	d.max_hp = int(round(a["hp"] * s))
	d.strength = int(round(a.get("str", 0) * s))
	d.magic = int(round(a.get("mag", 0) * s))
	d.skill = int(round(a["skl"] * s))
	d.speed = int(round(a["spd"] * s))
	d.defense = int(round(a["def"] * s))
	d.resistance = int(round(a["res"] * s))
	d.movement = a["mov"]
	d.level = 1 + wave
	return d


## The spawn list for `wave` — [{def, cell}] over the available `cells` (the
## arena's edge spawn ring). Deterministic per wave.
static func wave_spawns(wave: int, cells: Array) -> Array:
	var roster: Array = UNLOCK[mini(wave - 1, UNLOCK.size() - 1)]
	var n := wave_count(wave, cells.size())
	var out: Array = []
	for i in range(n):
		var arch: String = roster[i % roster.size()]
		out.append({"def": make_enemy(arch, wave, i), "cell": cells[i % cells.size()]})
	return out


## Extra-credit + gold payout for retiring after clearing `waves_cleared` waves.
static func reward(waves_cleared: int) -> Dictionary:
	return {
		"gold": waves_cleared * 60,
		"credit": waves_cleared * 5,   # feeds the Arena grade mark (GRADING_SYSTEM.md)
		"remark": _remark(waves_cleared),
	}


static func _remark(w: int) -> String:
	if w <= 0:
		return "Downed in the opening bout — the crowd is merciful."
	if w < 3:
		return "A respectable showing on the sand."
	if w < 6:
		return "The stands are chanting your name."
	return "A legend of the arena. The runes blaze for you."
