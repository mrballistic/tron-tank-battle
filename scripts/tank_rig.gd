extends Node3D

@export var turret_assembly: StringName

func _ready() -> void:
	# Both source models group the barrel and trim beneath a rigid turret node.
	# Preserve the imported geometry's rest pose when attaching it to the game pivot.
	var assembly := $Artwork.find_child(turret_assembly, true, false) as Node3D
	assembly.reparent($TurretPivot, true)
