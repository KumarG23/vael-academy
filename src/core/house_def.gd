class_name HouseDef
extends Resource
## A house's full identity (§4): colors, banner, UI theme tint, and the House
## Camaraderie passive values. All house-driven theming and the passive read from
## this resource, so swapping the active house re-themes the game with no code
## changes (WO-3.4 acceptance).

@export var id: String = ""
@export var display_name: String = ""
@export var banner_animal: String = ""
## Primary house color — unit team ring, turn banner, HP-bar fill.
@export var primary_color: Color = Color.WHITE
## Secondary color — menu/panel accents and edges.
@export var secondary_color: Color = Color(0.85, 0.78, 0.45)
## Banner/crest art (AW-5). Null until painted.
@export var banner_icon: Texture2D
## Subtle full-screen tint hook for house-flavored backdrops.
@export var theme_tint: Color = Color(1, 1, 1, 1)

@export_group("House Camaraderie (§4)")
## +hit/+avoid when within `camaraderie_range` tiles of a housemate.
@export var camaraderie_hit: int = 5
@export var camaraderie_avoid: int = 5
@export var camaraderie_range: int = 2
