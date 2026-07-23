# Cleanup Audit - 2026-07-23

Baseline: branch `prototype/verb-casting-sentence` at checkpoint `49075d9` (awakened-objects WIP committed first so cleanup diffs stay separable).
Method: mechanical scans (orphans, broken refs, typing, prints, input actions) plus seven parallel code reviews covering all 118 scripts, 53 scenes, tools, and tests, cross-checked against `docs/project-organization.md` and the Godot 4.3+ review checklist.
Findings are grouped into approval buckets A-G, ranked by value and risk.
Nothing below has been changed yet; each line is `file:line - issue - fix`.

## Snapshot

- 118 GDScript files, ~16.4k lines, 53 scenes, 20 resources; no autoloads; Jolt physics; one shader global (`wizard_sight`).
- Tests: 15 of 20 integration suites pass headless. All 5 failures are stale tests, not gameplay regressions (see bucket B).
- Overall health is high for a prototype: typed GDScript nearly everywhere, past-tense signals, cached node refs (zero `get_node` in any `_process`), `queue_free` discipline, no TODO markers, one debug print in game code, and good why-comments (Wayland capture, render priorities, WAV loop workaround).
- The strongest assets to preserve: the `SpellCast` begin/cast/resolve template + `SpellEffectBinding` data-driven spells, the `LinkEffect`/`LinkForge` duck-typed extensibility seam, single shared `magical_flame.tscn` behind every fire visual, and the narrow player facade (`interact`/`focus_prompt`/`set_control_enabled`/`WizardHud.toast`).

## A. Real bugs (fix first)

Gameplay-visible first, then latent lifecycle/perf bugs.

- A1 `game/spellcraft/casting/casting_controller.gd:167,621-633` - re-pressing cast during the fire animation interrupts the clip, `animation_finished` never fires, so the essence is consumed but no projectile spawns and the orb sticks in the palm - resolve/clear the pending cast before replaying, or resolve inside `fire_hurl()` and make the clip cosmetic - risk:high.
- A2 `game/spellcraft/casting/casting_controller.gd:257,307` - `Engine.time_scale = 0.7` and disabled look are only restored by `_exit_sketching()`; leaving the tree mid-sketch (scene change, death, test teardown) sticks them globally - restore in `_exit_tree()` when sketching - risk:med.
- A3 `game/spellcraft/links/magical_link.gd:186-208` - anchor/source accessors only null-check; a freed bound prop leaves a dangling ref and `_process` error-spams every frame (the `is_instance_valid` guard exists at :735 but is inconsistent) - add one validity-guard helper used by all accessors - risk:med.
- A4 `game/spellcraft/links/magical_link.gd:467,494,521,587,544` - hit/miss/hum/pulse/quill WAVs and the label font are `load()`ed synchronously on first use, i.e. a disk hitch on the exact rhythm-strike frame - convert the const path arrays to `preload` streams - risk:med.
- A5 `game/spellcraft/elements/element_source.gd:203-217,245-249` - `consume()` re-captures light energy mid-restore (1.5x over-bloom window), permanently brightening the lamp each fast siphon/feed cycle, and the consume light tween is untracked so two tweens fight - capture base energy once outside animations and track/kill the light tween - risk:med.
- A6 `game/player/sight/sight_controller.gd:178` + `journal_menu.gd:142-143` - `deactivate()` never resets `SightFade`, and JournalMenu freezes sight processing, so opening the journal mid-Sight leaves the `wizard_sight` global and all mesh overlays frozen for the whole session - push `_sight_fade.set_amount(0.0)` in `deactivate()` - risk:med.
- A7 `game/player/sight/sight_fade.gd:28,83-86` - static `_instance` never cleared and overlays never restored on teardown; `ElementSource._apply_container_exemption()` then calls `SightFade.refresh()` against a freed instance - add `_exit_tree()` that restores overlays, zeroes the global, and nulls `_instance` - risk:med.
- A8 `game/alchemy/flask.gd:18` - `_ready()` ignores the exported `_is_stationed`; the 4 shelf flasks in `flask_filled_storage_shelf.tscn` load as live unfrozen RigidBodies that can be jostled but never break - apply `_set_physics_active(false)` in `_ready()` when stationed - risk:med.
- A9 `game/scribing/station/rune_scribing_station.gd:261` + `scribe_canvas.gd:143-152` - `_begin_scribing()` resets session recognition but the canvas keeps `recognized_categories`, so after Esc-cancel and re-entry the UI shows locked runes while the session returns none; sealing silently loses them - reset both or persist both - risk:med.
- A10 `game/scribing/station/rune_scribing_station.gd:112,353` + `scribe_canvas.gd:43-48` - the 1024x768 scribe SubViewport is `UPDATE_ALWAYS` from scene load forever and the canvas redraws every frame even when nobody scribes - mirror BookPageRenderer's `UPDATE_DISABLED`-when-idle pattern and gate `set_process` - risk:med.
- A11 `game/books/presentation/book_visual.gd:367-382,475-483,699-764` - every tween tick of a page turn or book open rebuilds ArrayMeshes (with `generate_normals()`) for the turning page and both stacks - rebuild stacks only when thickness crosses an epsilon, or move fold/curl into a vertex shader - risk:med.
- A12 `game/books/presentation/book_page_renderer.gd:102-105` - `set_bookmarks()` unconditionally overwrites the render mode with `UPDATE_ONCE`, freezing an active rune-playback page - delete the override lines - risk:low.
- A13 `game/world/levels/wizard_tower.gd:17-20` (also `tower_architecture.gd:20-23`, `tower_door.gd:58-59`) - node wiring validated only by `assert` (stripped in release) and `find_child("*")` first-descendant casts that depend on glb import order - use typed `find_children` plus `push_error` hard-fail - risk:med.
- A14 `game/player/components/wizard_camera_effects.gd:27-29` - `_process` stomps the camera transform every frame even at zero trauma; the hand-flinch tween in `element_hand_controller.gd:287-290` only survives due to engine tween/process ordering - stop processing at zero trauma and route camera kicks through this component - risk:med.
- A15 `game/spellcraft/elements/siphon_stream.gd:53-62` - endpoint callables are only `is_null()`-checked; a freed bound object errors and the typed assign crashes - `if not _from_point.is_valid(): queue_free()` - risk:low.
- A16 `game/spellcraft/casting/casting_controller.gd:627` - `await get_tree().create_timer()` resumes on a possibly-freed self - use a node-owned tween interval that dies with the node - risk:low.
- A17 `game/player/components/element_hand_controller.gd:399-402` - `_toast_later` lambda calls `is_inside_tree()` on a possibly-freed captured self - prepend `is_instance_valid(self)` - risk:low.
- A18 `game/player/journal/journal_menu.gd:62,69` - `_camera` from `get_node_or_null` dereferenced unguarded in `_ready` - guard like `_player` - risk:low.
- A19 `game/books/presentation/book_visual.gd:152-157,828` - `apply_profile()` and `_configure_lighting_response()` dereference optional node refs unguarded while everything else guards - validate required nodes once in `_ready()` with `push_error` - risk:low.
- A20 `tools/capture/capture_homestead.gd:27` - `get_node_or_null(^"WizardHUD")` case mismatch (node is `WizardHud`), so captures include the HUD (the known survey HUD-flash gotcha); also `capture_left_carry_view.gd:31-32` derefs `arms` unguarded - use `player.hud.visible = false` and null-check - risk:low.

## B. Test suite back to green

The 5 failing suites are stale, and the lack of a run-all entry point is why nobody noticed.

- B1 Add `tests/run_all.sh`: loop `godot --headless --path . -s tests/integration/<t>` serially, record exit codes, print a summary, exit nonzero on any failure (`mouse_look_test` self-skips headless, no exclusion list needed).
- B2 `tests/integration/tower_door_test.gd` - predates the arcane-lock ward (door now refuses to open while the Bind is starved); superseded by the passing `door_lock_test.gd` - delete it, or feed the ward in setup and keep only the swing/collision checks door_lock does not cover.
- B3 `tests/integration/stair_step_test.gd:26-28`, `stair_descent_test.gd:17-19` - hardcoded stair coordinates predate the tower offset from the 2026-07-21 scene split - derive the spiral center from `find_child("central_spiral_stair").global_position`.
- B4 `tests/integration/wizard_tower_reveal_test.gd:127-157,166-178` - same root cause (hardcoded hidden-stair and exterior positions) - compute from named architecture nodes.
- B5 `tests/integration/homestead_environment_test.gd:62-108,116-128` - baked glb `extras` expectations and a hardcoded door-block ray no longer match the regenerated `wizard_homestead_environment.glb` - first confirm the checked-in glb is intentional (not a content regression), then re-bake expectations via `tools/authoring/generate_wizard_homestead.py`; drop the door section (owned by `door_lock_test`).
- B6 Ward-feed door-open flow is asserted in 3 places (`door_lock_test`, `homestead_environment_test`, `capture_wizard_tower.gd`) - keep the assertion only in `door_lock_test`.

## C. Verified dead code (delete)

Every item below was grepped repo-wide including `.tscn` `[connection]` blocks, uid references, and dynamic-load patterns.
Git history preserves everything.

Files to delete outright:

- C1 `shared/presentation/visual_layers.gd` (+`.uid`) - `VisualLayers` has zero references anywhere.
- C2 `game/spellcraft/links/sinks/plant_sink.gd` (+`.uid`) - no scene, resource, test, or `kind = &"plant"` anchor exists; note `IrrigateEffect` is unreachable content until a plant anchor ships.
- C3 `game/scribing/station/scribe_arm.tscn` - orphaned 259KB scene whose script `scribe_arm.gd` was deleted (errors on editor scans); the rig is reconstructible from the Wizardus glb.
- C4 `tools/verification/inspect_tower_tree.gd.uid` - sidecar of a deleted script.
- C5 `game/alchemy/ingredients/held_water.tscn`, `held_water.gd` (+`.uid`), `held_fire.tscn` - dead custody path; palm visuals actually come from `Element.held_scene` (`element.gd:21`) instantiated by `element_hand_controller.gd:299-302`; no string-built paths exist. `held_fire.gd` survives only as the type of burner's never-assigned var (see C10).
- C6 `game/spellcraft/casting/spells/bolt_cast.tscn`, `spell_projectile.tscn`, `spell_projectile.gd` (+`.uid`) - orphaned generic-bolt chain; `bolt_cast.gd` itself is live (fireball/stone_shard use it) and stays; `SpellProjectile` also duplicates `HurlProjectile` with a weaker tunneling-prone hit test.
- C7 `game/spellcraft/casting/spells/ground_aoe_cast.tscn`, `ground_aoe_cast.gd`, `ground_reticle.gd`, `ground_reticle.tscn` (+uids) - entire ground-AoE chain referenced by nothing; with it remove the vestigial aim-preview contract `spell_cast.gd:30-31,46` and the unreachable `_spell_cast.update_aim()` call at `casting_controller.gd:350-353`.
- C8 `game/alchemy/reagent.gd` - never instantiated; `flask.item_in_flask` is never set so `cook()` is unreachable.

Dead members, signals, and config:

- C9 Dead signals (emitted, zero listeners): `casting_controller.gd:23,26` `rune_recognized`/`spell_cast`; `hurl_projectile.gd:4` `hit`; `fire_explosion.gd:4` `exploded`; `magical_link.gd:43-44` `powered_changed`/`analyzed`; `heat_sink.gd:9` `heat_changed`; `element_hand_controller.gd:8-11` all four; `sight_controller.gd:15,20` `sight_changed`/`link_analyzed`; `tower_door.gd:4-5` `opened`/`closed` - delete each, or wire a real consumer where one is planned (E8 wires `basement_revealed` instead of deleting it).
- C10 Dormant custody cluster - `burner.gd:4-21` (`_try_cook_placed_flask`, unassigned `placed_flask`/`placed_fire`, unread `is_burner_on`, unread placement exports), `storage_shelf.gd:6` `item` export, `book.gd:10-13,67,86` custody signals (`book_taken` handler at `rune_scribing_station.gd:149` is unreachable so placement is one-shot) plus `get_reading_hand_grips()`/`get_held_hint()` - either strip now or mark each with one `# TODO(custody-rework)` line so future audits skip them; do not leave undocumented.
- C11 Dead functions: `health_component.gd:25-29` `heal()`; `wizard_locomotion.gd:30,57-61` discarded `physics_step` return computation; `sketch_ribbon.gd:82,93` `set_ink_color`/`set_tip_color`; `shape_recognizer.gd:37` `template_count()`; `magical_link.gd:277-278` `attunement_phase()`; `link_anchor.gd:70-71` `is_powered()`; `link_forge.gd:31-33,49-50` `register()`/`can_forge()`; `rune_definition.gd:18-23` `get_templates()`; `book_spread_data.gd:8-17` both getters (they mutate the Resource inside a getter); `flask.gd:47` `should_drop_straight_down()`.
- C12 Dead config/data: `rune_definition.gd:7` `mastery_required`; `rune_scribing_station.gd:27` `ink_width`; the `"empty"` marker key written at `sight_controller.gd:525` and read by nothing; `project.godot` input action `check_beard_inventory` (bound to B, used nowhere).

Unreferenced but probably intentional content - confirm before touching:

- C13 `game/world/props/wall_torch.tscn` (edited in the WIP yet placed nowhere), `game/books/props/book_shelf.tscn`, `game/world/props/furniture/{barrel,golden_chalice,wooden_mug}.tscn` - authored props awaiting placement; keep unless you know otherwise.

## D. Duplication to consolidate

- D1 Viewmodel rig paths x3: `element_hand_controller.gd:70-79`, `casting_controller.gd:119-139`, `journal_menu.gd:62-73` each hardcode `Viewmodel/WizardArms/arms/Skeleton3D/...` via `get_node_or_null`, so a rig rename silently disables palm effects/anchors - expose typed `camera`, `left_hand_anchor`, `right_hand_anchor` accessors on `WizardPlayer` and consume everywhere, warning when missing.
- D2 Orb-tint trio x4 (`hurl_projectile.gd:23-35`, `spell_palm_effect.gd:31-55`, `arcane_burst.gd:37-49`, plus the deleted `spell_projectile`) - one shared tintable helper targeted by `Element.apply_to`'s duck contract.
- D3 Stroke math x4: deep-copy of `Array[PackedVector2Array]` (`scribing_session.gd:58`, `scribe_canvas.gd:228`, `rune_template.gd:25`, `rune_recognizer.gd:265`), AABB x2, polyline length x3, and `rune_template_view.gd:125-131` duplicating `_draw_strokes` verbatim - one static `stroke_math.gd` helper in `game/scribing/runes/`.
- D4 Camera-feel duplication: hand-rolled FOV kick/lean tweens in `element_hand_controller.gd:283-290` and `sight_controller.gd:338-357`, each caching its own base FOV - centralize on `WizardCameraEffects` (pairs with A14).
- D5 Flicker math: `mood_light.gd:14-17` reimplements `magical_flame.gd:62-66`'s dual-sine flicker with a different idiom; MoodLight also clobbers authored `light_energy` in `_ready` - shared flicker helper in `shared/vfx`, default `base_energy` from the authored value.
- D6 `heat_effect.gd` vs `irrigate_effect.gd` - near line-for-line duplicates (identical `_element_id` helper) - hoist `_element_id` into `LinkEffect` and collapse into one configurable elemental-sink effect.
- D7 Strand geometry: `magical_link.gd:793-853,894-895` and `siphon_stream.gd:77-100,115-116` duplicate the bezier + camera-billboarded ribbon build - extract `shared/vfx/strand_geometry.gd`.
- D8 One-shot blast pattern: `fire_explosion.gd:54-60` and `air_gust.gd:31-61` keep `_physics_process` ticking forever after their single blast frame and share a near-identical falloff block - `set_physics_process(false)` after applying plus a shared radial-impulse helper.
- D9 World-parent resolution duplicated (`casting_controller.gd:694-697`, `hurl_projectile.gd:101-103`) - pass the world in or share a helper.
- D10 Player bootstrap snippet triplicated (`sight_controller.gd:65-68`, `casting_controller.gd:113-116`, `journal_menu.gd:58-66`); journal_menu additionally bypasses the facade with `get_parent().get_node_or_null("CastingController")` - standardize on owner-cast plus the typed facade accessors.
- D11 Test scaffolding: three divergent pass/fail conventions across 20 tests, `_aim_player_at` x4, `_press_cast` x3, floor-builders x4, synthetic-input senders x2, `_wait_for_page_turn` x2, rune fixture builders duplicated ~60 lines (`interaction_test.gd:236-294` vs `rune_recognizer_test.gd:81-160`) - one `tests/support/integration_test.gd` base plus `tests/fixtures/rune_fixtures.gd`.
- D12 Capture boilerplate repeated in all 10 `tools/capture/*.gd` (viewport rig, settle loop, save_png, exit codes; two error-chain styles) - `tools/capture/capture_harness.gd`, standardize on `_first_error`.
- D13 `tools/inspection/inspect_assets.gd:31-51` vs `inspect_glb.gd:41-54` duplicate `_merged_aabb` - loop the Kenney paths through `inspect_glb.gd` and delete the other, or share the helper.
- D14 AudioStreamPlayer3D one-shot boilerplate x5 across `magical_link.gd` and `tower_door.gd` - tiny shared helper when convenient.
- D15 `link_effect.gd:53-65` `source_of`/`sink_of` duplicate `magical_link.gd:170-183` fount selection - one owner delegates to the other.
- D16 Flame-prop scene block (MagicalFlame + FireSource + exports) copy-pasted across the four flame props - optional base `flame_prop.tscn` if a fifth prop appears.

## E. Contracts and boundaries

- E1 Sight shader contract has no owner: spellcraft writes instance uniforms (`essence_*` from `element_source.gd`, `breath_*` from `awakened_presence.gd`) that only `shadow_puppet.gdshader` declares; swapping `FADE_SHADER` to `ghost_glass.gdshader` (documented as a one-line treatment swap) silently kills vessel rim-burn and awakened breath because `set_instance_shader_parameter` no-ops - document the required uniform set in both treatment shaders, and use `ElementSource.GROUP`-style constants instead of re-declared group literals in `sight_fade.gd`'s EXCLUDE_GROUPS - risk:high if unaddressed.
- E2 `SightFade.refresh()` back-call from `element_source.gd:109` couples spellcraft to player internals - make refresh group/signal-driven (pairs with A7).
- E3 Sight and casting peek each other's state to arbitrate `cast`/`cast_focus`/`sight` (`sight_controller.gd:100,126-144,168-173` reads the casting state enum and calls `consume_held_rune()`; casting reads `_player.sight.active`) - smallest step: a `held_verb() -> StringName` accessor so the enum stays private, plus one comment block stating who owns which action when.
- E4 `docs/project-organization.md` gaps: `game/spellcraft/` ownership is never mentioned (the doc still says "create game/spells/ later"), and the no-autoload idiom exists in four variants (group locator, lazy static, static `_instance`, static registry) with the rationale buried in a `journal_facts.gd` comment - add a spellcraft ownership section and a "no autoloads: here is the pattern to copy" paragraph.
- E5 Unresolved authored link anchors fail silently (`magical_link.gd:130-141` `get_node_or_null` never validated; `tower_architecture.tscn` reaches across sibling scenes' internals) - `push_warning` when an authored anchor path resolves null.
- E6 `rune_scribing_station.gd:14-15,91,222-247` - hard-preloads the recognizer yet talks to it via stringly `call("recognize")`/`result.get(...)` reflection, discarding the existing `RuneRecognizer`/`RuneMatchResult` types - type the fields and the `rune_recognized` signal param.
- E7 `tower_door.gd:45-66` constructs `AwakenedPresence.new()` in code, hardcodes the `&"SpellCast"` bus, and runtime-`load()`s spellcraft's `siphon_rip.wav` - author the presence as a scene node and `preload` the sound (matches flask's pattern).
- E8 `wizard_tower.gd:28` polls `is_basement_revealed()` every physics frame while `tower_architecture.gd:4` emits a never-connected `basement_revealed` - connect the signal, delete the poll.
- E9 Two rune systems coexist by design (casting's `ShapeRecognizer`/`RuneGlyphs` constants vs scribing's `RuneRecognizer`/`.tres` definitions), but the new path leans on the old one's type: `journal_menu.gd:540` chains player -> casting -> scribing -> books via `RuneTemplate` - no merge now; record the retirement plan (RuneTemplate + stroke playback move to `shared/` before scribing can be retired).
- E10 `book.gd:214-236` handles reading navigation in `_input` with `set_input_as_handled`, pre-empting UI (`ui_cancel` can beat the journal) - move to `_unhandled_input` or comment the deliberate priority.
- E11 Sight marker pipeline is the widest untyped interface (~12 ad-hoc Dictionary keys built fresh every frame across `sight_controller.gd:501-584` -> `wizard_hud.gd` -> `siphon_overlay.gd`) - fine for now; promote to a small typed MarkerData or shared StringName key constants once the marker set stabilizes.

## F. Oversized-file splits (do opportunistically)

Behavior-neutral but large diffs; recommended only when you next touch each file, per the small-steps dev loop.
Proposed seams follow what the code already shows:

- F1 `book_visual.gd` (1017) - (a) pure mesh/vertex math -> `BookPageGeometry` RefCounted, (b) materials/lighting factories -> `BookSurfaceMaterials`, (c) state/poses/tweens/audio/UV picking stays (~400).
- F2 `magical_link.gd` (895) - keep link model/power/sever (~200); split minigame judgment -> `link_attunement.gd`, ImmediateMesh strand/knot/gate drawing -> `link_strand_renderer.gd`, audio -> `link_attunement_audio.gd`, Label3D ink reveal -> `link_inscription.gd`; compose as runtime-built children so `LinkForge.forge`'s `MagicalLink.new()` path keeps working.
- F3 `casting_controller.gd` (733) - template IO/recognizer setup -> `rune_template_store.gd`; arm-rig driving -> a `CastingArm` sibling component; controller keeps state machine, strokes, input, spawning.
- F4 `sight_controller.gd` (599) - marker projection/aim -> `sight_targeting.gd`; Bind/Sever/attunement verbs -> `sight_link_actions.gd`; pull/push hold -> `sight_siphon_hold.gd`.
- F5 `journal_menu.gd` (542) - summon choreography -> `journal_summon_rig.gd`; journal content construction -> `journal_content.gd` or authored BookData in `content/`.
- F6 `rune_scribing_station.gd` (487) - viewport/canvas/surface creation + ray-to-UV picking -> a `ScribeSurface` component.
- F7 `element_hand_controller.gd` (476) - held-essence presentation -> `held_essence_visual.gd` child; journal-arm bridge functions -> the viewmodel layer.
- Note: `book.gd` (418) is a cohesive state machine and fine as-is.

## G. Style sweep (one mechanical commit)

- G1 Explicit types on inferred exports/members across `magical_link.gd`, `element_source.gd`, `element.gd`, `link_anchor.gd`, `arcane_lock_effect.gd`, `heat_sink.gd`, `awakened_presence.gd`, `casting_controller.gd`, `sketch_ribbon.gd`, `bolt_cast.gd`, `arcane_burst.gd`, `spell_palm_effect.gd`; type `_stroke_point_arrays()` and recognizer `strokes` as `Array[PackedVector2Array]`; `journal_facts.gd:43` return `Array[StringName]`; `wizard_hud.gd:105` and `rune_scribing_station.gd:452,467` untyped locals.
- G2 StringName consistency: standardize `&"action"` literals in `casting_controller.gd` (:153 vs :167 etc.), `book.gd:227,271-277`, `rune_scribing_station.gd:157-166`, `player_interactor.gd:47`.
- G3 Shadowing renames: `water_jet.gd:5`/`air_gust.gd:4` `range`; `hurl_projectile.gd:75` `position`; `ground_aoe_cast.gd:74` `basis` (moot if C7 deletes it); `magical_link.gd:742` local `SEGMENTS`, `:638` `show`; `rune_template_view.gd` local `scale`.
- G4 `class_name` gaps: `rune_scribing_station.gd` (tests poke it untyped), `wizard_arms_visual.gd`, `tools/authoring/rune_template_recorder.gd` (then drop the test's `call("...")` stringly access).
- G5 Declaration order: `class_name` before `extends` in `flask.gd`, `item.gd`, `open_book_placement.gd`; rename `enum CASTING_STATE` -> `CastingState`; `_`-prefix `sketching_state_time_accumulator`/`sketching_cursor_pos`.
- G6 `journal_menu.gd:116-125` hardcoded `KEY_1/2/3/TAB` - add proper input actions.
- G7 `casting_controller.gd:505` `print(report)` recognizer dump - gate behind `OS.is_debug_build()` or an export flag.
- G8 Small perf/idiom: `sketch_ribbon.gd:62` `set_process(Engine.is_editor_hint())`; `flask.gd:51` toggle `set_physics_process` with state; `magical_link.gd:686-715` `set_process(false)` when fully faded and clear surfaces once on transition, `:668-679` drop the always-false `no_depth_test` config loop; `player_controller.gd:25-26` cache `%Interactor`; `rune_scribing_station.gd:208` `maxi()`; `sight_controller.gd:260` name the `99999.0` carry-thread const.
- G9 Tests/tools polish: `stair_descent_test.gd:53`/`composition_test.gd:29` `free()` -> `queue_free()` + settle; blank-line convention in `spellcraft_lab_sight_test.gd:154`, `stair_descent_test.gd:59`, `stair_step_test.gd:73`; rename `tests/fixtures/scenes/scribing_playground.tscn` -> `mouse_look_playground.tscn` (root is "SpellcraftPlayground", only mouse_look uses it).
- G10 `sight_fade.gd:26` static `sight_amount` written but unread (promised to signifier readers) - keep only while that plan is live.

## False alarms (no action)

- `res://assets/third_party/polypizza/Wizardus` - scan artifact from a space in "Wizardus Maximus.glb"; the asset exists and is credited.
- `content/books/new_book.tres` - book_writer's default save destination, not a broken load (optionally point it at `user://`).
- `mouse_look_test` passed in this run (display available); it self-skips cleanly when truly headless.

## Recommended order

1. Pass 1: A (bugs) + B (tests green, runner first so every later pass is verifiable) + C1-C12 (dead code) + the doc updates E1/E4.
2. Pass 2: D1-D10 consolidations + remaining E items.
3. Pass 3: F splits opportunistically as each file next gets touched.
4. Pass 4: G style sweep last, so mechanical churn does not collide with the real diffs.

Each pass lands as small commits with `tests/run_all.sh` green (except known-stale suites until B lands).
