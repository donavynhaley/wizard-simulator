# Wizard Simulator

## No string matching for identity or behaviour

Do not branch on stringly-typed tags.
If code asks "what kind of thing is this?", the answer is its **type**, checked by the engine - not a `StringName` compared against a literal.

- Match on class: `anchor.target() is Door`, `sink.target() is HeatSink`. Never `anchor.kind == &"door"`.
- Match resources by identity: `FIRE.matches(element)` against a `preload`ed `.tres`, never `element.id == &"fire"`.
- Call typed methods: `var patch := sink.target() as HeatSink; patch.set_hot(active)`.
  Never `target.has_method(&"set_hot")` + `target.call(&"set_hot", active)`.
- Make a thing eligible for a system by giving it the **component that implements the behaviour**.
  The component is both the mark and the implementation, so there is no tag that can contradict the object it labels.

**Why:** a misspelled string fails silently forever (`&"doar"` just never matches, no error);
a misspelled class name fails to compile and points at the line.
A parallel tag can also lie - nothing stops an anchor on a `Door` being tagged `&"ground"` - while a type cannot.

**Strong reasons to keep a string** (these are fine): human-facing display text and labels;
persisted save/journal keys and `fact_id`s that must survive refactors;
Godot's own APIs where the engine demands a name (signals, groups, input actions, animation and shader parameter names).
Prefer `&"..."` StringNames and, where a fixed set exists, `const` declarations over scattered literals.

When you find existing string matching in code you are already editing, migrate it.

## GodotPrompter

This is a Godot project with GodotPrompter skills available.
Before implementing any game system, check for a matching `godot-prompter:*` skill and invoke it.
This applies to all agents, subagents, and sessions working in this repository.

Key skills include `player-controller`, `state-machine`, `event-bus`, `scene-organization`, `component-system`, `resource-pattern`, `godot-ui`, `hud-system`, `ai-navigation`, `camera-system`, `audio-system`, `save-load`, `inventory-system`, and `godot-testing`.

For the full skill list, invoke `godot-prompter:using-godot-prompter`.
