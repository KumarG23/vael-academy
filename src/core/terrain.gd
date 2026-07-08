class_name Terrain
extends RefCounted
## Namespace for terrain type identifiers used across grid/combat systems.
##
## The numeric values are persisted in ChapterDef terrain arrays and saves —
## DO NOT reorder or renumber without a migration.

enum Type {
	PLAINS = 0,
	FOREST = 1,
	MOUNTAIN = 2,
	FORT = 3,
	WALL = 4,
	WATER = 5,
	# Maps v2 (Neal 2026-07-05: color/variety/indoor battles) — append-only.
	PATH = 6,     # roads/plazas: structure and color, plains-equivalent stats
	FLOOR = 7,    # indoor ground (chapters with base_terrain = FLOOR)
	PILLAR = 8,   # standable cover, GBA-style (def+1, avoid+20)
	CARPET = 9,   # fancy indoor ground, floor-equivalent stats
	SPRING = 10,  # healing station: 15% max HP at turn start
	FLOWERS = 11, # wildflower meadow: plains stats, pure color variety
	SITE = 12,    # invisible blocker under scenery props (houses, wells):
	              # impassable, but the ground beneath the prop stays base fill
	# AW-29 (Neal: terrain buffs/debuffs, strategy) — append-only.
	EMBERS = 13,  # burning ground: passable HAZARD, chips 3 HP at turn start
	              # (never lethal), no cover — don't end your turn here
	MIRE = 14,    # sucking bog: DEBUFF — move cost 4, avoid -15 (easy to hit),
	              # def -1, so caught units get punished
}
