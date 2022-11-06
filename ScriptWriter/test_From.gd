#/1
extends Node


var frames := 0
var other := "LIKES"

#/3
func _ready():
	print("%s ARE COOL TOO" % other)

#/2
func physics_process(delta):
	frames += 1
	if frames == 10:
		frames = 0
		subscribe()

#/1
func subscribe() -> void:
	print("SUBSCRIBE!")

