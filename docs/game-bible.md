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
| Fire | Movable through Sight, exists in game |
| Water | Movable through Sight, exists in game |
| Earth | Exists in element schema, no world source yet |
| Air | Exists in element schema, no world source yet |

### Runes

Runes are verbs of the same graph Sight reads: they weaponize essence and edit links.
This five-verb core replaces the earlier draw/pour and bolt/font/mend/rend sets.

| Rune | Verb | Glyph | What it does in the graph |
| --- | --- | --- | --- |
| Hurl | Strike | Outward spear | Weaponize carried essence; the element determines the attack |
| Bind | Connect | Figure-eight (the knot) | Create a link between two subjects |
| Sever | Cut | Lightning slash (drawn violently) | Break a link |
| Seal | Close | Closed ring (the ritual circle) | Hold a boundary: wards, locks, containment |
| Open | Release | Broken ring, loose end hooked inward (the gap is the door) | Undo a boundary |

Every glyph is one stroke, and the motion matches the verb's emotion: a cut is slashed, a seal is drawn calm.
The pairs teach each other: Open is a Seal left unclosed, its loose end hooked inward like a handle, and Sever slashes through the knot Bind ties.
The hook is what keeps a lazy or under-drawn circle from reading as either ring; without it the pair was a subset and only global strictness could tell them apart.

Wizard Sight handles elemental essence directly; grabbing and placing are manipulation rather than casting.
Essence rests in the left hand, leaving the right hand free to trace a verb.
Every traced rune is spent by its single use.
Compound workings are sequences, not mega-runes.

### The casting sentence

Every cast is a sentence performed with the body: noun, then verb, then object.

1. **Gather the noun**: holding Sight, aim at a source and move its essence into the left hand.
   What renders as a source depends on the journal; learned Natures expand the mana map.
2. **Trace the verb**: the rune primes in the right hand and waits for its single use.
3. **Aim and act**: release Sight and use the verb on a target.
   Hurl consumes the carried element and gives each element a different offensive expression.

While Sight is active, the same action places carried essence into a matching empty source.
Sight and rune casting are mutually exclusive modes: Sight must be lowered before the casting hand can rise, and Sight cannot activate while a rune is charging, being traced, or held.

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
- **Element handling is not spellcasting**: Sight can move known essence between the world and the left hand without spending a rune.
- The academy taught every graduate **Sight and Hurl** - find the noun, then make it dangerous.
  Everything else is learned from the world.

Recognition feel (2026-07-23):

- A trace commits to the closest verb when it is decisive, not when it is pretty.
  The five-verb vocabulary is closed, so ambiguity between two verbs is the only honest refusal, and the refusal names them both.
- The trace score no longer gates the cast; it is the spell's stability tier (steady / wavering / unstable).
  A sloppy Hurl still hurls - slower, softer, wobbling in flight, its palm light guttering.
- The ribbon and the sketch hum warm with recognition confidence mid-trace, so a failing shape is corrected, not discovered at the lift.
- The practice slate records a decisive trace as a personal exemplar (player data, user://).
  The tower learns this wizard's hand alongside the canon glyphs; personal exemplars only add leniency, never replace the canon.
  At the slate the intent is declared, so the margin is waived for the awaited verb (the quality floor still holds): a verb the hand cannot yet draw decisively can still be taught.

The three casting tiers are the same sentence at three levels of preparation:

| Tier | Verb | Noun |
| --- | --- | --- |
| Live | Traced on the spot | Gathered from the world through Sight |
| Reagent | Traced on the spot | Gathered from a carried source |
| Scroll | Pre-traced in ink | Pre-bound in the ink (elemental inks are captured nouns) |

### Casting economy

The three ways to source an element, per the kernel's sourcing rule.

Sight moves a known elemental noun into the left hand.
The tiers below describe where that noun comes from.

| Tier | Source | Trade |
| --- | --- | --- |
| World | Gather the element from a world source (torch, well, hearth) | Free but situational - the environment is the mana bar |
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
8. Every working has an author, and every author has a motive.
   Write both into the case notes even when no fact reveals them; the world must always be able to answer "who did this, and why".
   Motives need not be malice: neglect, love, habit, and commerce write workings too.
9. Every false lead must be testable to a clean result.
   An exoneration is a real fact the journal inks, and resolutions may care about diligence: an accusation backed by exoneration facts lands differently than a hasty one.

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
| charm_working | charm | working | rune_reading | charm_nature | bind, seal | A Bind to the milk shed held by a crooked Seal; it drinks the milk's sweetness nightly. |
| charm_history | charm | history | library | charm_nature | - | The library calls it a souring charm: spite-craft, banned in three parishes, always buried at a boundary. |

### Resolutions

| id | requires | outcome |
| --- | --- | --- |
| destroy_charm | charm_working | Smash it; the working dies loudly, and the neighbor knows it was found. |
| siphon_charm | charm_working, charm_nature | Use Sight to move the stored working quietly into a flask; a bottled curse now sits on the tower shelf. |
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
School taught the kernel - Sight and Hurl, the burn test, and safe handling - but the valley and the tower are unread.
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

**Subjects**: `tower_door`, `door_lantern` (the cold lantern above the door), `path_torch` (Maren's standing torch by the approach, still burning).

**Link**: `door_to_lantern` (a Bind ties the lock to the lantern's vessel; fed, it stands the door aside).

| id | subject | slot | reveal | prereqs | payload | journal text |
| --- | --- | --- | --- | --- | --- | --- |
| marens_note | tower_door | history | observation | - | - | Maren sealed the tower himself; his note insists a wizard needs no key. |
| door_ward_source | tower_door | links | sight_thread | marens_note | door_to_lantern | A thread runs from the lock to the cold lantern above; the Bind is starved, and it holds the door until the vessel is fed. |
| lantern_nature | door_lantern | nature | observation | door_ward_source | fire | The lantern is an empty vessel, fire-natured: a fount in miniature waiting for flame. |
| door_working | tower_door | working | rune_reading | door_ward_source | bind | A Bind rune ties the door to the lantern, patient as its maker; fed, it stands aside. |

Resolutions:

| id | requires | outcome |
| --- | --- | --- |
| feed_the_ward | lantern_nature | Use Sight to move fire from Maren's path torch into the lantern; the Bind drinks, the door swings open, and the tower's light returns to the valley. |
| answer_the_rune | door_working | Trace the Bind rune back at the door; it recognizes a wizard's hand and stands aside, lantern still cold. |

The two resolutions are the two kinds of knowledge in the game: elemental manipulation through Sight, which school already taught, and Bind, learned by reading the maker's own hand.
Either choice plants the consequence principle before the first villager appears.

## 7. Canon Sheet

The living registry.
Every case that introduces vocabulary or a rule adds a line here, same day.

### Rules established

| Rule | Introduced by |
| --- | --- |
| Sight renders only journal knowledge | Kernel |
| Power is never created, only moved (world source, reagent, or scroll) | Kernel |
| An item's learned Nature makes it a valid reagent | Kernel |
| Runes are verbs on the world-graph; compound workings are sequences of verbs | Kernel |
| Sight manipulation moves essence without a rune; every traced rune is still spent by its single use | Kernel |
| Essence rests in the left hand until placed or consumed by a verb | Kernel |
| A matching empty vessel accepts placed essence; foreign essence is refused | Case Minus One |
| A seal left unclosed is an opening - close your circles, apprentice | Kernel |
| The academy teaches every graduate Sight and Hurl | Case Minus One |
| Tower mysteries are authored as cases, never bespoke puzzle minigames | Case Minus One |
| Element founts start dormant; restoration costs gold and understanding | Case Minus One |
| A starved Bind holds fast until its bound vessel is fed | Case Minus One |
| A working aimed at a distant target leaves a visible thread | Case Zero |
| Boundary magic is buried at the boundary it governs | Case Zero |
| Burning a sample reveals its nature by flame color | Case Zero |

### Flame colors (bench test)

| Reaction | Meaning | Introduced by |
| --- | --- | --- |
| Green hiss | A bound working is leaching the sample's essence | Case Zero |

### Registry

- Elements: fire, water, earth, air.
- Runes: hurl, bind, sever, seal, open.
  Seal's ring uses the recorded hand-drawn circles; the other four use synthetic fallback glyphs until hand exemplars are recorded (recorded always wins).
  Legacy bolt/font/mend/rend stroke templates retired.
- Cases: locked_door (Case Minus One), sour_milk (Case Zero).


## Donavyn Notes
Spellcasting can come in many forms
- Runic magic use the ancient runes to manipulate the world around you energy and matter is not created but reworked
- Focuse casting is using the energy stores in a magical focus to channel 

Elements
- Fire
- Water
- Air
- Earth
Alchemy Problem Space
- Speed 
- Healing
-  
Spellcraft Problem Space
Knowledge problem space
- Learning alchemy 
Quests
- Royal decree from the king to supply the crown with certain potions and scrolls
- An adventurer party comes through asking for aid on their quest. They can seek a scroll, a potion, or knowledge.

Events
- upon casting first dark magic spell one of the spell hunters shows up to your door to questions you

Sources
- Possible music https://www.patreon.com/cw/retroplayerone
- https://www.youtube.com/watch?v=Ybo-hcLcu2c
