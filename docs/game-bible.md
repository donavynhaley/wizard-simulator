# Wizard Simulator Game Bible

This is the working structure for authoring quests (cases) and growing the game's magic systems.
It stays small on purpose.
Section 1 never changes.
Everything else grows one case at a time.

## 1. The Kernel

These rules are permanent.
Every case, mechanic, and asset must honor them.

- The world is already written.
  Everything magical is composed of the same language the player casts in: elements and runes.
  A curse, a locked door, and a mushroom are all "text" someone or something wrote.
- Casting is writing.
  Reading is Wizard Sight.
  Alchemy edits what materials are made of.
  Detective work is reading a text the player did not write.
- Power is never created, only moved.
  There is no mana.
  Every cast must source its element from somewhere: siphoned from the world, consumed from the offhand, or preserved in a scroll.
- Sight renders knowledge; it never grants it.
  The overlay only shows what the journal already knows.
  Every glyph and thread on screen was earned through a mechanic.
- The player makes the deduction; the game only confirms it.
  Evidence appears in the world first.
  The journal inks the fact afterward, as applause.
- The journal is the wizard's infinite book.
  It records facts, sketches, and hypotheses, and it is also the main menu.
- Knowledge is the only progression for Sight.
  Sight itself never upgrades; the journal does.
- Cases grow the language.
  New runes, natures, and rules are invented only when a case needs them, then recorded in the Canon Sheet.
  The kernel does not move.

## 2. The Vocabulary

The current language of the world.
Add rows only through cases, never speculatively.

### Elements

| Element | Notes |
| --- | --- |
| Fire | Siphonable, exists in game |
| Water | Siphonable, exists in game |
| Earth | Exists in element schema, no world source yet |
| Air | Exists in element schema, no world source yet |

### Runes

Runes are verbs of the same graph Sight reads: they move essence and edit links.
This six-verb core replaces the earlier bolt/font/mend/rend set; the old names survive in the repo only as stroke templates awaiting re-skinning.

| Rune | Verb | What it does in the graph |
| --- | --- | --- |
| Draw | Pull | Move essence out of a subject and into the hand |
| Pour | Push | Move essence from the hand into a subject |
| Bind | Connect | Create a link between two subjects |
| Sever | Cut | Break a link |
| Seal | Close | Hold a boundary: wards, locks, containment |
| Open | Release | Undo a boundary |

There is no runeless magic: Draw takes, Pour gives, and every traced rune is spent by its single use.
Essence rests in the off hand between verbs: Draw lands it there and frees the casting hand for the next rune; Pour sends it home to an empty vessel or pushes it out at a target.
Compound workings are sequences, not mega-runes: Draw then Pour is a transfer; Bind then Pour is action at a distance.
Healing is Pour with a matching nature; harm is forced Draw or an opposed Pour.

### The casting sentence

Every cast is a sentence performed with the body: verb, then noun, then object.

1. **Trace the verb**: the rune primes in the casting hand and waits for its single use.
2. **Draw the noun**: holding Sight, aim at a source and pull its essence into the off hand; the Draw rune is spent.
   What renders as a source depends on the journal; learned Natures expand the mana map.
3. **Trace and give**: with essence carried, Pour returns it to an empty matching vessel or pushes it out at the target; spent again.

Sight is the noun-space: sources, threads, and boundaries are aimed at through it.
Sever can only target a thread Sight renders, so casting depth is journal depth.

Feel decisions (locked 2026-07-20):

- Sight is **hold-only**: a physical act of squinting into the other world, never a persistent overlay.
  The world desaturates, sound softens, glyphs ink themselves in; releasing the key drops it all.
- Tracing runs at **~70% time**: deliberate and slightly protected, never a pause menu.
  Danger still pressures the handwriting.
- A primed rune **persists until used or dismissed** (shake it off); no timer.
  Walking around holding a verb is a feature.
- **Two hands** (locked while prototyping): the right hand speaks the verb, the left hand carries the noun.
  Every traced rune is spent by its single use; carried essence survives traces and dismissals.
- **No runeless magic**: Draw is the only way to take, Pour the only way to give back.
- The academy taught every graduate **Draw and Pour** - take and give.
  Everything else is learned from the world.

The three casting tiers are the same sentence at three levels of preparation:

| Tier | Verb | Noun |
| --- | --- | --- |
| Live | Traced on the spot | Pulled from the world through Sight |
| Reagent | Traced on the spot | Pulled from the offhand item, a carried source |
| Scroll | Pre-traced in ink | Pre-bound in the ink (elemental inks are captured nouns) |

### Casting economy

The three ways to source an element, per the kernel's sourcing rule.

All taking is done through the Draw rune; there is no runeless magic.
The tiers below describe where the noun comes from, not whether a rune is needed.

| Tier | Source | Trade |
| --- | --- | --- |
| Siphon | Draw the element from a world source (torch, well, hearth) | Free but situational - the environment is the mana bar |
| Reagent | Consume an offhand item that carries the element | Portable but spent on cast - carried power |
| Scroll | Release a working prepared at the tower | Works anywhere, strongest, but costs preparation |

An item becomes a valid reagent only once its Nature is learned.
Bench-testing a mushroom and learning it is earth-natured is what makes mushrooms earth components.
Knowledge manufactures ammunition.
Common effects should be siphonable almost anywhere; reagents gate the specific and strong, so the player is resource-pressured, never soft-locked.
The tower's element founts are progression, not starting equipment.
Each fount is inherited dormant and restored with gold and understanding; a restored fount makes its element free forever at home.

### Knowledge slots

Every subject (any object, person, place, or working the player can learn about) has up to five slots.

| Slot | What it unlocks in Sight | Typical way to earn it |
| --- | --- | --- |
| Nature | Element glyphs on the subject | Bench test (burn, dissolve, distill) |
| Name | Entry header resolves; precise targeting | Testimony, library, records |
| Links | Threads to connected subjects | Observation, sight thread, probe |
| History | Echoes of past events | Library, brewed lens, testimony |
| Working | The full rune-sentence written on it | Rune reading (only runes the player can trace) |

### Reveal mechanics

Every fact must be tagged with exactly one.

| Tag | Player verb |
| --- | --- |
| observation | Watch, inspect, or notice something in the world |
| bench_test | Test a sample at the tower (burn, dissolve, feed) |
| library | Match evidence against a book |
| testimony | Ask a person the right question |
| sight_thread | Follow a rendered thread to its end |
| rune_reading | Read a rune the player knows how to draw |
| spell | Cast something that reveals (probe, scry) |

### Sight states

How a subject renders in Wizard Sight, derived from learned facts.

| State | Condition | Render |
| --- | --- | --- |
| Unknown | No facts learned | Nothing |
| Smudge | Some fact learned, but not Nature | Illegible smear: "something is written here" |
| Partial | Nature learned | Element glyphs, plus threads for known links |
| Full | Every authored fact learned | Complete entry, all glyphs and threads |

## 3. How to Author a Case

A case is a fact-graph: nodes are facts, edges are prerequisites, and every node is tagged with the mechanic that reveals it.
Author it entirely on paper (in this format) before building anything.

A case consists of:

- **Hook**: the request or phenomenon, described the way a villager would describe it (symptoms, never causes).
- **Subjects**: the things the player can learn about.
- **Facts table**: one row per learnable fact.
- **Links**: the threads between subjects that facts can reveal.
- **Resolutions**: the endings, each requiring specific facts.

Facts table columns: `id | subject | slot | reveal | prereqs | payload | journal text`.
Payload is what the fact adds to Sight: element ids for nature facts, a link id for links facts, a rune id for working facts.

### Authoring rules

1. Every fact has exactly one reveal tag.
   A fact with no tag is lore, not gameplay.
2. If every tag in a case is `testimony`, you wrote a visual novel.
   Spread facts across at least three mechanics.
3. Every fact must be reachable (prereq chains must trace back to a fact with no prereqs) and must matter (be required by a resolution or be a prerequisite of one).
   Unreachable or dead-end facts are bugs.
4. At least two resolutions, so the facts inform a choice instead of unlocking a door.
5. The consequence of each resolution follows from what the player understood or misunderstood, never from a random roll.
6. New vocabulary (a rune, a nature, a rule like "curses stay tethered to their caster") may be introduced one or two items per case.
   Record every addition in the Canon Sheet the day it is written.
7. The hook must be solvable-feeling but wrong.
   Whoever reports the problem misreads it; the first learned fact should complicate the obvious theory.

### What a case pays

Every case should pay in at least two of these layers.

| Reward | Why it matters |
| --- | --- |
| Coin and reagents | Under the sourcing rule, reagents are ammunition; payment in materials is a power-up, not vendor trash |
| Renown and trust | Access, not stats: better clients, restricted books, villagers who will actually answer questions |
| Vocabulary | A rune, rule, or recipe added to the canon sheet; permanently changes what the player can read and cast |
| Artifacts | Resolution byproducts (the bottled curse) that are shelf trophies and future reagents at once |

### Competing attention

Flow comes from the player choosing what to ignore.
These pressures run under every case and cost little authoring:

- Smudges: every partially-known subject renders as an unread smear in Sight, a self-assigned open loop.
- Standing orders: the market cart wants potions on a rhythm; steady income between cases.
- Day and night: some testimony only by day, some workings and bench reactions only by night; time is a contested resource.
- Brews in progress: anything simmering at the tower is a come-back-later timer pulling against fieldwork.

## 4. Case Zero: The Sour Milk

The worked example and copyable template.
Scoped deliberately small: no combat, one location pair (tower + one cottage), one new prop with a rune on it.

**Hook**: Odetta's milk sours by morning.
Every morning.
Only hers.
She blames the well.

**Subjects**: `milk` (Odetta's milk), `odetta` (the client), `hedge` (the boundary hedge between her yard and the neighbor's), `charm` (a buried souring charm).

**Links**: `milk_to_hedge` (a sour thread trailing from pail toward the hedge), `hedge_to_charm` (the rot gathers under the roots).

### Facts

| id | subject | slot | reveal | prereqs | payload | journal text |
| --- | --- | --- | --- | --- | --- | --- |
| testimony_souring | milk | history | testimony | - | - | Odetta swears the milk sours only after dark, and only since the spring feast. |
| milk_nature | milk | nature | bench_test | testimony_souring | water | Burned at the bench, the sample hisses green: water-natured, and something has been drawing its sweetness out. |
| milk_link_hedge | milk | links | sight_thread | milk_nature | milk_to_hedge | A faint thread runs from the pail, under the door, toward the boundary hedge. |
| hedge_name | hedge | name | testimony | milk_link_hedge | - | Odetta names it the boundary hedge; the neighbor planted it after the feast-day quarrel. |
| hedge_link_charm | hedge | links | observation | milk_link_hedge | hedge_to_charm | Fresh-turned soil beneath the roots; something is buried there. |
| charm_nature | charm | nature | bench_test | hedge_link_charm | earth | The unearthed charm is earth-natured, dense, and holding a working like a clenched fist. |
| charm_working | charm | working | rune_reading | charm_nature | bind, draw | A Bind to the milk shed and a Draw on what it holds, crudely traced; it drinks the milk's sweetness nightly. |
| charm_history | charm | history | library | charm_nature | - | The library calls it a souring charm: spite-craft, banned in three parishes, always buried at a boundary. |

### Resolutions

| id | requires | outcome |
| --- | --- | --- |
| destroy_charm | charm_working | Smash it; the working dies loudly, and the neighbor knows it was found. |
| siphon_charm | charm_working, charm_nature | Draw the working out quietly into a flask; a bottled curse now sits on the tower shelf. |
| redirect_charm | charm_working, charm_history | Re-aim the charm's Bind into the hedge's deadwood; nobody learns anything, and the wizard now keeps a secret. |

Note how the graph enforces the loop: field (testimony) → tower (bench) → field (thread, dig) → tower (rune reading or library) → field (resolution).

## 5. What a Case Demands

A finished fact-graph is also the build list.
Read the reveal column for mechanics and the subject list for assets.

Case Zero demands, in order of dependency:

**Mechanics**

- Journal book: facts ink themselves onto pages when learned; already have the physical book system.
- Wizard Sight overlay: renders smudge, element glyph, and thread on tagged objects, driven entirely by journal state.
- Bench test (one verb): burn a carried sample over the burner and observe a colored reaction; already have burner and flask shells.
- Testimony: minimal dialogue that can gate facts; can start as a single prompt interaction.
- Readable rune object: a world prop whose rune resolves through the existing recognizer templates.
- Sample pickup: carry a sample from field to tower; already have the item/held system.

**Assets**

- Milk pail with milk (sampleable), Odetta or a stand-in door interaction, boundary hedge with diggable soil, buried charm prop with a scratched Rend rune, flask for the siphon resolution (exists).

**Explicitly not demanded** (so do not build yet): history lens, names as targeting, scrying, probe spell, more than one bench verb, any new rune.

## 6. The Vertical Slice

The slice proves the loop compounds, not just that it runs once.
One case demos a mechanic; the second case, played faster and richer because of the first, demos the game.

**Framing: the graduate successor.**
The player is a newly schooled wizard arriving to take over from the old wizard (working name: Maren) who serviced this valley and is gone.
School taught the kernel - Draw and Pour, the burn test, Sight itself - but the valley and the tower are unread.
Maren's tower is dense with his writing, and its mysteries are authored as cases like everything else.

**Scope: the tower and one farmstead.**
No village.
Odetta's farm hosts both field cases, which caps the cast at three NPCs and one location pair.
The village exists off-screen: a market cart visits for standing orders, and rumors arrive with it.
When the full village is built later, the player's Sight fills with new smudges on day one, which is the reveal we want.

Slice tower state: the Torch of Eternal Flame is the one working fount; the Endless Spring sits dormant in the cellar, an unreadable smudge planted in the first ten minutes.

Contents:

- **Case Minus One: The Locked Door** - the tutorial.
  The player arrives to a sealed tower and getting inside is the whole case.
  It teaches Sight, the journal, siphoning, and rune tracing on Maren's own ward, with no NPCs watching.
  About 10 minutes.
- **Case Zero: The Sour Milk** (section 4) - guided, near-linear, teaches read → test → resolve. About 15 minutes.
- **Case One: The Sick Farmhand** - open, same farm, multiple solve paths, reuses Case Zero vocabulary (the green hiss, the Rend rune, boundary rules). About 20 minutes.
  Its hook should entangle with the player's Case Zero resolution where possible (a redirected charm's rot has to have gone somewhere).
  Case One must require zero new code; if it does, the pipeline failed its test.
- **One ambient system** - a standing order (two healing draughts by market day) plus day/night gating, so case work and tower work compete for the same hours.

Cast: Odetta, the neighbor, one farmhand.

### Case Minus One: The Locked Door

**Hook**: the academy's letter says the tower is yours.
Maren left no key; the door is sealed, and his note on it reads "a wizard needs no key."

**Subjects**: `tower_door`, `door_lantern` (the ever-lit lantern above the door).

**Link**: `door_to_lantern` (the ward drinks from the lantern's flame).

| id | subject | slot | reveal | prereqs | payload | journal text |
| --- | --- | --- | --- | --- | --- | --- |
| marens_note | tower_door | history | observation | - | - | Maren sealed the tower himself; his note insists a wizard needs no key. |
| door_ward_source | tower_door | links | sight_thread | marens_note | door_to_lantern | A thread of flame runs from the lock to the lantern above; the ward drinks from it. |
| lantern_nature | door_lantern | nature | observation | door_ward_source | fire | The lantern burns without oil or wick: fire-natured, a fount in miniature. |
| door_working | tower_door | working | rune_reading | door_ward_source | seal | A Seal rune holds the door, fed by the lantern, patient as its maker. |

Resolutions:

| id | requires | outcome |
| --- | --- | --- |
| starve_the_ward | lantern_nature | Trace Draw and drain the lantern dry; the ward dies and the door swings open, but the tower now greets the valley dark. |
| answer_the_rune | door_working | Trace the Seal rune back at the door; the ward recognizes a wizard's hand and stands aside, lantern still lit. |

The two resolutions are the two kinds of knowledge in the game: Draw, which school already taught, and Seal, learned by reading the maker's own hand.
Either choice plants the consequence principle before the first villager appears.

## 7. Canon Sheet

The living registry.
Every case that introduces vocabulary or a rule adds a line here, same day.

### Rules established

| Rule | Introduced by |
| --- | --- |
| Sight renders only journal knowledge | Kernel |
| Power is never created, only moved (siphon, reagent, or scroll) | Kernel |
| An item's learned Nature makes it a valid reagent | Kernel |
| Runes are verbs on the world-graph; compound workings are sequences of verbs | Kernel |
| There is no runeless magic; every traced rune is spent by its single use | Kernel |
| Essence rests in the off hand between verbs; Pour alone gives it back | Kernel |
| A matching empty vessel accepts poured essence; foreign essence is refused | Case Minus One |
| The academy teaches every graduate Draw and Pour | Case Minus One |
| Tower mysteries are authored as cases, never bespoke puzzle minigames | Case Minus One |
| Element founts start dormant; restoration costs gold and understanding | Case Minus One |
| A ward starves if its element source is siphoned away | Case Minus One |
| A working aimed at a distant target leaves a visible thread | Case Zero |
| Boundary magic is buried at the boundary it governs | Case Zero |
| Burning a sample reveals its nature by flame color | Case Zero |

### Flame colors (bench test)

| Reaction | Meaning | Introduced by |
| --- | --- | --- |
| Green hiss | A Draw is leaching the sample's essence | Case Zero |

### Registry

- Elements: fire, water, earth, air.
- Runes: draw, pour, bind, sever, seal, open (legacy bolt/font/mend/rend stroke templates await re-skinning).
- Cases: locked_door (Case Minus One), sour_milk (Case Zero).
