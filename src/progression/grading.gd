class_name Grading
extends RefCounted
## AW-54: the Academy report card math (GRADING_SYSTEM.md) — pure and testable.
## A running grade blends four MARKS (each 0–100) by weight; marks with no data
## yet read as a neutral 60 so early semesters never stare at an F. All numbers
## here are data to tune, not law (§2).

const WEIGHTS := {"coursework": 0.35, "battlefield": 0.35, "arena": 0.20, "conduct": 0.10}
const NEUTRAL := 60.0
const CONDUCT_BASE := 60.0
## Deepest arena wave that maps to a perfect Arena mark (wave × 10, capped).
const ARENA_TOP_WAVE := 10
## Rank ladder: minimum score → letter + house-flavored name.
const RANKS := [
	[90, "S", "Ascendant"], [78, "A", "Distinguished"], [64, "B", "Accomplished"],
	[50, "C", "Passing"], [0, "D", "Faltering"],
]
## Battle score tuning (per GRADING_SYSTEM.md): win base, penalties, floor.
const BATTLE_WIN_BASE := 100
const BATTLE_LOSS_SCORE := 30
const PENALTY_PER_UNIT_LOST := 12
const PENALTY_PER_OVER_PAR_ROUND := 4
const PAR_ROUNDS := 10
const BATTLE_WIN_FLOOR := 40


## Per-mark 0–100 from the raw samples; -1 (no data) stays -1 here — display and
## blending decide how to treat it (the blend uses NEUTRAL).
static func marks(samples: Dictionary) -> Dictionary:
	var quiz: Array = samples.get("quiz_scores", [])
	var battles: Array = samples.get("battle_scores", [])
	var best_wave: int = int(samples.get("arena_best_wave", 0))
	var conduct_pts: int = int(samples.get("conduct_points", 0))
	return {
		"coursework": _avg(quiz),
		"battlefield": _avg(battles),
		"arena": -1.0 if best_wave <= 0 else minf(100.0, best_wave * (100.0 / ARENA_TOP_WAVE)),
		"conduct": minf(100.0, CONDUCT_BASE + conduct_pts),
	}


## The running grade: weighted blend (missing marks read NEUTRAL) + rank + hints.
static func running(samples: Dictionary) -> Dictionary:
	var m := marks(samples)
	var score := 0.0
	for k in WEIGHTS:
		var v: float = m[k]
		score += (NEUTRAL if v < 0.0 else v) * WEIGHTS[k]
	var r := rank_for(score)
	return {"score": roundi(score), "rank": r[1], "rank_name": r[2],
		"marks": m, "hints": hints(m, samples)}


static func rank_for(score: float) -> Array:
	for r in RANKS:
		if score >= float(r[0]):
			return r
	return RANKS[-1]


## The "↑ how to raise it" line per mark — the whole point of the Grades tab.
static func hints(m: Dictionary, samples: Dictionary) -> Dictionary:
	var out := {}
	out["coursework"] = "Attend a lesson at the classroom" if m["coursework"] < 0.0 \
		else ("Already flawless" if m["coursework"] >= 99.5 else "Ace the next quiz to pull the average up")
	out["battlefield"] = "Win a graded battle" if m["battlefield"] < 0.0 \
		else ("Peerless in the field" if m["battlefield"] >= 99.5 else "Win the next battle without losing anyone")
	var best: int = int(samples.get("arena_best_wave", 0))
	out["arena"] = "Enter the weekly Trial at the spire" if best <= 0 \
		else ("The sand remembers you" if m["arena"] >= 99.5 else "Reach wave %d (best so far: %d)" % [best + 1, best])
	out["conduct"] = "Already excellent" if m["conduct"] >= 99.5 \
		else "Cook, fish, attend festivals, and grow your bonds"
	return out


## A graded battle's 0–100 score (fed to the Battlefield mark).
static func battle_score(victory: bool, units_lost: int, rounds: int) -> int:
	if not victory:
		return BATTLE_LOSS_SCORE
	var s := BATTLE_WIN_BASE - units_lost * PENALTY_PER_UNIT_LOST \
		- maxi(0, rounds - PAR_ROUNDS) * PENALTY_PER_OVER_PAR_ROUND
	return maxi(BATTLE_WIN_FLOOR, s)


static func _avg(arr: Array) -> float:
	if arr.is_empty():
		return -1.0
	var t := 0.0
	for v in arr:
		t += float(v)
	return t / arr.size()
