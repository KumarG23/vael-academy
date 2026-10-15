class_name ActiveDefensePresentation
extends IllustratedCombatPresentation


func _make_juice() -> IllustratedCombatJuice:
	return ActiveDefenseJuice.new()
