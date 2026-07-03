class_name Promotion
extends RefCounted
## Promotion rules (§3): at level 10+, a promotion item changes a unit to its
## promoted class, grants flat stat bonuses, and resets its level to 1 (the cap
## stays 20, so it can grow again). Pure eligibility/bonus logic; the Unit applies
## the result to itself.

const MIN_LEVEL := 10


## Can a unit of `char_class` at `level` promote? (Item possession is checked
## separately by the inventory.)
static func is_eligible(char_class: ClassDef, level: int) -> bool:
	return char_class != null and char_class.can_promote() and level >= MIN_LEVEL
