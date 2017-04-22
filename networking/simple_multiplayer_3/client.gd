extends Node

signal register_player(id, name)

func _ready():
	pass

remote func register_player(name):
    emit_signal("register_player", int(get_name()), name)