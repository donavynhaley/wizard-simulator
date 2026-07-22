class_name JournalFacts
extends RefCounted

## The knowledge spine (game-bible.md: the journal drives what Sight renders).
## A fact is a StringName id from a case's fact table. Mechanics call learn()
## when a reveal completes; anything gated on knowledge asks knows() or listens
## for fact_learned.
##
## A static singleton rather than an autoload so headless -s test harnesses
## (which never register autoloads) resolve it exactly like the game does.
## Deliberately minimal: prereqs, slots, and journal page text stay authored in
## case content - this is only the set of earned fact ids and its signal.

signal fact_learned(id: StringName)

static var _singleton: JournalFacts

var _facts: Dictionary[StringName, bool] = {}


static func record() -> JournalFacts:
	if _singleton == null:
		_singleton = JournalFacts.new()
	return _singleton


static func learn(id: StringName) -> void:
	if id == &"" or record()._facts.has(id):
		return
	record()._facts[id] = true
	record().fact_learned.emit(id)


static func knows(id: StringName) -> bool:
	return record()._facts.has(id)


## Empty ids gate nothing - convenience for optional requires_fact exports.
static func satisfied(id: StringName) -> bool:
	return id == &"" or record()._facts.has(id)


static func learned_facts() -> Array:
	return record()._facts.keys()


## Forget everything - save-load and test harness hook.
static func reset() -> void:
	record()._facts.clear()
