extends KinematicBody2D

const MOTION_SPEED = 90.0

signal ready_to_start(id)

slave var slave_pos = Vector2()
slave var slave_motion = Vector2()

export var stunned = false

# Use sync because it will be called everywhere
sync func setup_bomb(name, pos, by_who):
	var bomb = preload("res://bomb.tscn").instance()
	bomb.set_name(name) # Ensure unique name for the bomb
	bomb.set_position(pos)
	bomb.owner = by_who
	# No need to set network mode to bomb, will be owned by master by default
	get_node("../..").add_child(bomb)

var current_anim = ""
var prev_bombing = false
var bomb_index = 0

func _fixed_process(delta):
	var motion = Vector2()

	if (get_network_remote() == get_tree().get_network_unique_id()):
		if (Input.is_action_pressed("move_left")):
			motion += Vector2(-1, 0)
		if (Input.is_action_pressed("move_right")):
			motion += Vector2(1, 0)
		if (Input.is_action_pressed("move_up")):
			motion += Vector2(0, -1)
		if (Input.is_action_pressed("move_down")):
			motion += Vector2(0, 1)

		var bombing = Input.is_action_pressed("set_bomb")

		if (stunned):
			bombing = false
			motion = Vector2()

		if (bombing and not prev_bombing):
			var bomb_name = get_name() + str(bomb_index)
			var bomb_pos = get_position()
			rpc("setup_bomb", bomb_name, bomb_pos, get_tree().get_network_unique_id())

		prev_bombing = bombing
		motion *= delta

		rset("slave_motion", motion)
		rset("slave_pos", get_position())
	else:
		set_position(slave_pos)
		motion = slave_motion

	var new_anim = "standing"
	if (motion.y < 0):
		new_anim = "walk_up"
	elif (motion.y > 0):
		new_anim = "walk_down"
	elif (motion.x < 0):
		new_anim = "walk_left"
	elif (motion.x > 0):
		new_anim = "walk_right"

	if (stunned):
		new_anim = "stunned"

	if (new_anim != current_anim):
		current_anim = new_anim
		get_node("anim").play(current_anim)

	# FIXME: Use move_and_slide
	var remainder = move(motion*MOTION_SPEED)

	if (is_colliding()):
		# Slide through walls
		move(get_collision_normal().slide(remainder.normalized()))

	if (get_network_remote() != get_tree().get_network_unique_id()):
		slave_pos = get_position() # To avoid jitter

slave func stun():
	stunned = true

master func exploded(by_who):
	if (stunned):
		return
	rpc("stun") # Stun slaves
	stun() # Stun master - could use sync to do both at once

func set_player_name(name):
	get_node("label").set_text(name)

func ready_to_start(id):
    emit_signal("ready_to_start", id)

func _ready():
	stunned = false
	slave_pos = get_position()
	set_fixed_process(true)
