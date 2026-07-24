class_name Burner
extends Node3D

## Alchemy burner. Dormant until the held-item custody rework lands.
## Intended flow: place a flask on the burner, place eternal flame beneath it,
## the flask cooks; while the flame is off the flask can be added or removed.

## Authored placement points, wired in alchemy_lab.tscn, for the custody rework.
@export var flask_placement: Node3D = null
@export var fire_placement: Node3D = null
