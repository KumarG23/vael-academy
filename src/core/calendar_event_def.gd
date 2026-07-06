class_name CalendarEventDef
extends Resource
## One week of the academy year (WO-7.1, §4 calendar). BATTLE weeks put their
## chapter on the War Room's mission board; FREE weeks are school life;
## HOLIDAY weeks are authored set-pieces (WO-7.3 stages them).

enum Kind { FREE, BATTLE, HOLIDAY }

@export var week: int = 1
@export var kind: Kind = Kind.FREE
@export var label: String = ""
## Chapter id for BATTLE weeks (resolved through the ChapterRegistry).
@export var chapter_id: String = ""
