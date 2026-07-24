# Wizard Simulator - Game Design Document

> **Status (2026-07-20).**
> This document is the long-range vision and systems backlog.
> The authoritative core loop, casting economy, case-authoring format, and vertical slice live in [game-bible.md](game-bible.md).
> Where the two disagree, the bible wins.
> Systems described here that are not in the bible are future material, to be pulled in one case at a time.

## High Concept

Live as a wizard in your tower.
You are newly graduated, sent to fill the shoes of the old wizard who serviced this valley and is gone.
His tower is locked, his workings are written on everything, and the villagers remember how he did things.
Read the hidden writing of the world, diagnose what ails the valley, craft spells and potions, and perform your workings where people can see them.
Grow stronger and more renowned as you do.
The village watches your tower rise.

## Design Pillars

**Pillar 1: The World Is Written.**
Everything magical is text in the same language the player casts in: elements and runes.
Wizard Sight reads it, casting writes it, alchemy edits it.
Knowledge is the progression system; the journal is the character sheet.
(See the bible's kernel for the binding rules.)

**Pillar 2: Style Pays.**
Solving a quest earns coin.
Solving it with flair earns renown.
Every system should offer a cheap path and a flashy path, and the flashy path should feed your name.
(See Gilded Ink, multi-resolution cases, storefront presentation, trophy decor.)

**Pillar 3: The Tower Makes, The Valley Casts.**
The tower is where spells are made and knowledge is confirmed; the valley is where the wizard happens.
Crafting a fireball is not the fantasy.
Standing on a hill throwing one in front of a cheering village is.
Most cases require your presence, your reading, and your casting, not just your product.

## Visual Direction

Art direction is under active exploration on the dark-fantasy branches (Dread Delusion magenta, gothic texturing, warm candlelit); none is locked yet.
The earlier retro pixel/dither pass was rejected in favor of cinematic atmosphere.
The Atari 2600 palette at `assets/reference/palettes/` is a legacy reference, no longer a mandate.
Book page paper keeps `#fce08c` as its standard background color.

## Core Gameplay Loop

The loop is case-driven; the full authoring model is bible section 3.

1. **Monitor** the valley from the tower (window, scrying orb, quest board) while brews simmer and standing orders queue.
2. **Accept** a case from a villager or a decree from the king (decrees have hard deadlines).
3. **Investigate** in the field: Wizard Sight, testimony, samples, threads.
4. **Confirm** at the tower: bench tests, library work, rune reading; the journal inks what you prove.
5. **Prepare**: scribe scrolls, brew potions, stock reagents for the working the case demands.
6. **Resolve** on-site, witnessed, choosing between resolutions the facts have unlocked.
7. **Earn** coin, reagents, renown, vocabulary, and artifacts; the village visibly grows and the king demands more.

Two reputation tracks run in parallel and sometimes conflict:

- **Village Trust** - earned by helping the common folk.
  Unlocks trade, reagent access, standing orders, and village growth.
- **Royal Favor** - earned by completing decrees.
  Unlocks rare inks, artifacts, gold-leaf payments, and protection from the tax collector.

Some cases force a choice between the two.
Picking sides is the drama engine of the game.

---

# Pillar Systems 1: Spellcasting and Spellcraft

## The Casting Economy

There is no mana.
Every cast sources its element per the bible's sourcing rule: siphoned from the world, consumed from an offhand reagent, or preserved in a scroll.

- **Live casting** is the baseline and already in game: siphon an element from a source, trace the rune in the air, release.
  Free but situational; the environment is the mana bar.
- **Reagent casting**: an item whose Nature the player has learned can be held in the offhand and consumed as the element source.
  Portable power; knowledge manufactures ammunition.
- **Scrolls are prepared magic**, the premium tier.
  A scroll binds a completed working in advance: multi-rune sentences, inks, and seals that live casting cannot carry.
  Scrolls hold charges and are consumed; artifacts that store spells still consume scrolls, so the scroll economy is never bypassed.

## Scroll Crafting Steps

1. **Source the element** at the tower founts and bring it to the spellcraft table.
2. **Scribe runes onto the scroll**: the hand-drawing minigame, a series of runes in a valid order.
   Beginners use standard spell ink; other inks change the spell's behavior.
3. **Apply a seal**: determines how and when the spell triggers.
   Default is cast-on-use.
4. **Cast, shelve, or alter**: use the scroll (burns a charge), stash it, or take it to an artifact for further alteration.

### Rune Mastery (anti-tedium ramp)

Hand-scribing rune #400 is tedium, not immersion.
Scribe a rune cleanly enough times and you unlock **Practiced Hand** for that rune: an auto-scribe at standard quality.
Manual scribing always remains available and grants a quality bonus (potency, extra charge chance, renown multiplier on use).
Automate the solved problem, reward the craftsman.
Mastering a rune also masters reading it: a rune you can trace is a rune you can recognize written in the world.

### Knowledge, Not Recipes

The library never hands over complete recipes; it gives fragments that narrow the theory space, per the bible's fact model.
Experimentation fills the gaps.
Failed scribes never produce nothing; they produce a **misfire** with a funny or minor effect, plus a library note hinting at what went wrong.
Discovery should feel like scholarship, not menu reading.

## Elements and the Founts

The tower was built to hold an infinite fount of each element:

- **Earth** - the Barrel of Infinite Dirt
- **Water** - the Endless Spring
- **Fire** - the Torch of Eternal Flame
- **Air** - the Conch of Aerlevsedi (air-LEV-seh-dee)

The founts are progression, not starting equipment.
The player inherits them dormant and restores each with gold and understanding: read the fount's Working (a tower case), then pay the price.
A restored fount makes its element free forever at home, which makes the founts the throne-tier gold sink and a visible measure of the tower's recovery.
In the field there are never founts: siphon what the environment offers, spend reagents, or bring scrolls.
Scarcity lives in reagents, inks, and time, and it relaxes at home one restored fount at a time.

## Rune Vocabulary

The rune core is the five-verb grammar defined in the bible: **Hurl, Bind, Sever, Seal, Open**.
Runes are verbs on the world-graph that Sight reads; compound workings are sequences of verbs, and offensive elemental casting requires Hurl.
Wizard Sight directly moves known essence between a source and the wizard's left hand.

The form/effect/modifier vocabulary below is legacy, kept as a design quarry.
Most of it re-derives inside the verb grammar rather than surviving as runes: Ward is Seal, Tether is Bind, and Bolt is Hurl carrying fire or earth.
Delivery and shaping ideas (Nova, Fork, Chain, Seek, Echo, Quicken) likely return as scroll-tier inscription modifiers, not standalone runes.

### Legacy Form Runes

- **Nova**: detonates in a radius around the caster or the impact point.
  Turns a Bolt into a Fireball on landing.
- **Ward**: raises a barrier.
  Element flavors it: Earth = stone wall, Fire = burning shield, Water = wall that douses and slows.
- **Tether**: links two points.
  The Portal/teleport backbone.
- **Mote**: spawns a tiny autonomous elemental servant that seeks and applies the Effect.
  A fire mote is a will-o-wisp that chases enemies.

### Legacy Effect Runes

- **Grasp**: root, hold, or physically grab objects at range.
- **Lift / Fall**: vertical control.
  Lift = Jump; Air+Ward+Fall = Slow Fall.
- **Reveal**: light, detection, scrying.

### Legacy Modifier Runes

- **Greater**: bigger, stronger, costs more.
- **Fork**: splits into 2 to 3 weaker copies.
- **Chain**: effect jumps to nearby valid targets.
- **Seek**: adds homing.
- **Echo**: casts twice with a short delay off one charge.
- **Quicken**: faster cast and projectile, shorter range as the tradeoff.
- **Bind**: the effect lingers on whatever it hit instead of firing once.

## Inks

All non-standard inks are alchemy products; this is the bridge between the two crafting systems.

- **Standard ink**: bought cheap, works fine, earns nothing extra.
- **Blood ink**: spell costs a chunk of your own health, hits much harder.
  Brewed from your own blood at the still.
- **Rime ink**: staples a chill/slow rider onto any spell, even a Mend.
  Brewed from winter reagents.
- **Quicksilver ink**: everything cast from that scroll is faster but shorter-lived.
- **Gilded ink**: purely cosmetic power.
  Makes the spell flashier and earns more renown from the same result.
  Brewed from gold leaf, which the king pays in.
  Cheap ink solves the quest; gilded ink builds your name.
  This ink IS the Style Pays pillar.
- **Fool's ink**: unstable, small chance to misfire in a funny way.
  Brewed from failed-batch sludge; pairs with pipeweed haze for comedic runs.
- **Elemental inks**: ink brewed from a raw element.
  Fire ink on a fire spell overcharges it, but any opposing element in the runes fizzles.

## Seals (how a scroll triggers)

- **Contingency**: binds to *you*, auto-fires on a condition.
  "On falling" casts Slow Fall; "on low health" pops a Ward.
  The insurance category; makes a wizard feel prepared rather than reactive.
- **Trap/Ward**: binds to a location or object, fires on proximity or disturbance.
  Turns any offensive scroll into a placed mine.
- **Word seal**: dormant until a spoken trigger word.
  Hand the scroll to an NPC or plant it, and it fires when *they* say the word.
- **Sympathetic seal**: fires when an attuned target does something.
  Attune a scrying scroll to the king's rival; it resolves the moment he leaves his keep.
- **Sundial seal**: fires at a specific world-time (dawn, dusk, a named calendar date).
  Built for decrees: "make it rain by the harvest festival" means sealing the scroll to bloom at that moment.
- **Counter seal**: dormant until it detects an incoming spell or attack, then reflects or negates.
  A magical parry.

## Further Alterations (done through artifacts)

The spell is already sealed; alterations are about delivery, storage, and combos, not the effect itself.

- **Bind two scrolls**: fuse them so one cast fires both.
- **Fold into a paper familiar**: the scroll becomes an origami bird or beetle that flies to a target and delivers the spell.
  Requires the Aviary.
- **Set a fuse**: change the Seal after the fact to a timer or proximity trigger.
- **Overcharge**: adds a charge or boosts power, with a chance to detonate in your hand.
- **Etch onto a spell-card**: miniaturize the scroll to fit in beard storage.
- **Attune to a person or place**: locks a Seek/Reveal spell onto a specific target.
- **Split charges**: break a 3-charge scroll into three 1-charge scrolls to sell or hand out.
  Economy hook; feeds the storefront.

---

# Pillar Systems 2: Alchemy

Alchemy is the scarcity economy, the ink factory, and half of the detective kit.
Where spellcrafting is precision and knowledge, alchemy is timing and process.
It should feel like cooking under pressure, not another drawing minigame.

## The Bench Is Also an Instrument

The same stations that brew potions run the bible's **bench tests**: burning, dissolving, and distilling samples to reveal their Nature.
A revealed Nature fills a journal slot, upgrades Wizard Sight, and licenses the material as a casting reagent.
Alchemy is how the wizard interrogates matter.

## The Brewing Process

1. **Prep**: chop, grind, or crush reagents.
2. **Heat**: feed the burner with the Torch of Eternal Flame.
3. **Stir**: stir patterns and timing during the boil.
4. **Pull**: take it off the flame at the right moment.
   Early = weak, late = sludge.

### Frankies Alchemy Design Musings

Alchemy basics

Process ingredients into either powders or liguids you add in varying mixtures for desired effect.

Example 2 parts ginseng powder with 1 parts water makes a simple healing potion.
Example 3 parts kraken juice with 1 part water and 1 part any herb powder makes basic ink.

Books and villagers, (and maybe quests) will tell you the steps neccessary to proccess the various ingredients and how the ratios to mix them at.

If taken off to soon or too late you will not get the full amount of reageant you could yield.

There may or may not be various steps to process one reagent to it's final form. You can also mix potions and inks with the intermediate reagents for more possibilites.

Process Possibilites:
Boil - Combine water element and ingredient in pot. Letting it boil for too short or too long of a time will yield less.
Crush - place ingredient or ingredients in mortar and pestle and crush. Crush too few or too many times will yield less.
Chop - Place ingredient on cutting board and cut into various pieces. The recipe will call for a specific amount and deviation will yield less.

Animal Parts / Herbs / Liguids / Elements

Animal parts:
Kraken sack (Kraken Juice) - Boil the until it squeals. Yields Kraken Juice. One sack makes 9 parts of juice if done correctly.
Leg of goat (Goat meat and Goat bones) - Chop to get goat meat and goat leg bones. Yields four parts if done correctly.
Goat meat (Mana of Goat) - Chop goat meat into five pieces. The water in the pot will turn brown when done. Yields Mana of Goat. Makes 4 parts if done correctly.
Goat bones (Goat Marrow Powder) - Crush with mortar and pestle to get goat marrow powder. Crush five times to get full amount. Yields 3 parts goat marrow powder if done correctly.

Herbs:
Basil (Chopped basil) - Chop into various amounts depending on recipe.
Mint (Mint Powder) - Crush six times with mortar and pestle to get full amount. Yields 3 parts mint powder if done correctly.

Liguids:
Milk (Milk essence) - Boil until it reduces to a fourth. Makes four parts milk essence if done correctly.
Beer

Elements:
Fire
Water - Use to boil in pot.
Earth
Air
Etc

## Reagents (the scarcity loop)

Tower founts are infinite; reagents are not.
Under the sourcing rule reagents are also ammunition, which makes every source below a power source:

- **Village trade**: villagers sell herbs and materials.
  Prices and stock depend on Village Trust.
- **Case rewards**: rare reagents come from completed cases; payment in materials is a power-up, not vendor trash.
- **The Greenhouse**: a tower floor that grows staple herbs on a real-time cycle.
- **Distilled spells**: catch your own fire mote in a jar and distill it into concentrated fire essence.
  Spells become reagents; the loop closes in both directions.
- **The king's payments**: gold leaf (for gilded ink) and rare royal reagents come only from decrees.
- **Case artifacts**: resolution byproducts (a bottled curse) are shelf trophies and reagents at once.

## Products

- **Inks**: every non-standard ink.
  Alchemy is mandatory for high-end spellcraft.
- **Potions**: healing, buffs, utility.
  The village's bread and butter.
- **Essences**: concentrated elements used as premium reagents or overcharge fuel.
- **Lenses and tinctures**: brews that extend Wizard Sight (a hindsight tincture that reveals History echoes); future material, introduced by cases.

## Systems

- **Standing orders**: the village apothecary wants 3 healing potions a week.
  Recurring passive income against case spikes; the wizard as town pharmacist.
- **Taste-testing**: unknown brew? Drink it.
  Random effect table, some hilarious (haze, floating, voice change).
  An identification artifact removes the guesswork later.
- **Failed batches**: produce sludge.
  Sludge is greenhouse fertilizer or the base for fool's ink.
  Failure always feeds something.
- **Aging**: potions stored in the Cellar improve over in-game time.
  Hooks into the calendar; a potion laid down in spring is stronger by harvest.

---

# Pillar Systems 3: Cases (Quests)

Every quest is a **case**: a fact-graph of things the player can learn, authored in the bible's section 3 format.
Villagers describe symptoms, never causes, and the reporter always misreads the problem.
The detective loop (Sight, testimony, samples, bench, library, rune reading) is the quest content.

## Case Sources

- **Village cases**: posted on the board, delivered by visiting villagers, or spotted through the tower window and scrying orb.
  Flexible deadlines, build Village Trust.
- **Royal decrees**: arrive by courier with a wax seal and a hard deadline.
  Build Royal Favor.
  Ignoring one is refusing the king.

## Case Types: Turn-In vs Fieldwork (the 25/75 rule)

- **Turn-in work (~25%)**: brew potions, sell split-charge scrolls, fill standing orders.
  The economy layer; product changes hands at the storefront or by courier.
- **Fieldwork cases (~75%)**: the board does not say "bring me a water scroll."
  It says "the mill is on fire," "something is taking sheep from the eastern pasture," "the milk sours every night."
  You investigate, prepare, and resolve on-site, witnessed by villagers.

Witnessing is the mechanic that makes Style Pays real: gilded renown only counts when someone sees the cast.
A gilded fireball detonated alone in the woods earns base renown; the same cast in front of the harvest crowd earns the multiplier.

## Multi-Resolution Design, Graded on Style

Every case ends in resolutions unlocked by facts, at least two per case, and payout scales with elegance and flash.
Example, the future Drought case:

- Cast a rain spell from the tower top (functional)
- Place a Water+Font+Mend spring in the fields (elegant, permanent)
- Brew and distribute cloud-seed potions (alchemy route)
- Tether a portal from the Endless Spring to the village well (galaxy-brain, huge renown)

Gilded ink multiplies the renown of any route.
The consequence of each resolution follows from what the player understood or misunderstood, never from a random roll.

## Deadlines and Failure

Failure has teeth or deadlines are fake.

- **Failed decree**: the tax collector arrives.
  He seizes coin, or an artifact, or padlocks a tower floor until you pay.
  Repeat failures escalate.
- **Failed village cases**: reagent prices rise, the board thins, villagers stop selling to you.
  Alchemy starves.
- **The Rival Wizard**: takes cases you ignore or fail and collects the renown you did not.
  He builds his own tower on the far hill; you can watch it grow.
  Urgency without putting a timer on everything.

## Conflict Cases

Periodically the two reputation tracks collide.
The king decrees the spring be diverted to his war camp; the village needs it for harvest.
There is no solution that satisfies both.
These choices shape which unlocks you see and how NPCs treat you.

## Consequence Cases

Your resolutions create new cases.
The redirected souring charm rotted the hedge; the portal to the well let something *through*.
The world reacts to your choices and generates content from them; each resolution in a case file should note what it might seed.

## Delivery Requirements

Cases should pull specific crafting features so every system gets exercised:

- A word seal handed to a nervous NPC who must say the trigger at the right moment
- A paper familiar flown across the valley to a target you cannot reach
- An attunement to a target you have never seen, forcing scrying orb use first
- A sundial seal timed to a festival, forcing calendar awareness

## Calendar and Seasons

The sundial seal implies a clock; make it core.
Four seasons with:

- Seasonal cases (harvest, midwinter festival, spring floods)
- Seasonal reagents (rime ink only brews in winter, or costs triple otherwise)
- Decree deadlines tied to named dates
- Potion aging measured against it
- Day/night gating within each day: some testimony only by day, some workings and bench reactions only by night

## Village Growth

The village is the progression bar, visible from the tower window.
Solve irrigation and the fields expand; fund the mill and a new building appears.
Growth unlocks new case tiers, new shops, new reagents, and bigger standing orders.
Every new building and villager arrives as an unread smudge in Sight, so growth also grows the mystery surface.

---

# Pillar Systems 4: Tower Customization

Functional rooms first, decor second.
Every room is a progression unlock wearing a cosmetic hat.

## The Inherited Tower

The tower belonged to the old wizard, and under Pillar 1 it is dense with his writing: warded doors, charms in the walls, dormant founts, half-finished workings, margin notes.
Its mysteries are authored as cases through the same pipeline as the valley (bible section 3); a locked room is a fact-graph, never a bespoke puzzle minigame.
Upgrades are discrete states - dormant to restored, locked to open, plain to improved - not freeform construction.
The old wizard is a content generator, not just backstory: his unfinished business seeds field cases, his mistakes become consequence cases the player inherits, and the villagers measure the player against his memory.

## The Tower Grows

The tower gains floors at renown milestones.
The village watches it rise; the rival's tower rises in answer.
Renown made physical, visible from anywhere on the map.

## Functional Rooms

- **Library** (tiers): gates rune knowledge and research fragments.
  Upgrading the library is upgrading your spell ceiling and your case-solving ceiling.
- **Alchemy Lab**: brewing stations and the bench-test instruments.
  Upgrades add burners, better stills, batch size, and new test verbs.
- **Cellar**: enables potion aging.
  Deeper cellar, longer aging, stronger results.
- **Greenhouse**: grows staple reagents on the calendar cycle.
- **Observatory**: extends scrying orb range and unlocks sympathetic seals at distance.
- **Aviary**: houses paper familiars; required for the fold alteration; upgrades add range and capacity.
- **Entry Hall / Storefront**: villagers walk up and buy potions and split-charge scrolls off your display shelves.
  Layout and presentation affect sales.
  Presentation pays, same pillar as gilded ink.

## Artifact Adjacency

Placement is a light puzzle, not pure decoration:

- Scrying orb by a window sees further
- Spellbook near the library recharges faster
- Grandfather clock in the hall makes sundial seals more precise
- Torch near the lab improves burner control

## Organization as Gameplay

- Scroll shelves with labels, ingredient jars, sorted or chaotic; your call
- The beard is a hotbar: etch spell-cards, store them in the beard, quick-draw in the field
- A messy tower where you cannot find the fireball scroll during a decree deadline is emergent comedy, and cleaning up is its own quiet satisfaction

## Trophies

Styled case completions earn decor you cannot buy: the village gifts a statue, the king sends a banner, the rival sends a passive-aggressive fruit basket.
Resolution artifacts (the bottled curse) shelve alongside them.
Cosmetics as proof of deeds.

## Tower Defense (rare, scripted)

Fail the king badly enough and knights arrive.
Botch the wrong case and something crawls out of the consequence.
One or two scripted sieges, not a tower-defense subsystem.
This is where counter seals, ward traps, and contingencies get a home turf to prove themselves.

---

# Pillar Systems 5: The Valley (Fieldwork)

The world outside the tower.
This is where most crafted spells and most learned facts earn their existence.
The valley answers "why did I craft this" for every rune, seal, and alteration, and "why did I learn this" for every journal entry.

## Traversal With Texture

The map has verticality and obstacles so utility spells stop being orphans:

- The herb that only grows on the cliff ledge (Jump up, Slow Fall down)
- The cave reagent across a chasm (Tether/Portal)
- The dark shrine that must be scouted before attuning (Reveal)
- The boulder blocking the harvest road (Grasp, or Earth+Bolt if you feel dramatic)
- The updraft canyon crossed by riding your own Air Font

**Reagent gathering requires casting.**
The best alchemy reagents sit in places only a competent caster can reach, which welds the scarcity loop to spellcasting.
Crafting feeds casting feeds crafting.

## Reading the Valley

Wizard Sight runs everywhere.
Old workings, boundary marks, ward stones, and cursed objects are world-text: readable with earned knowledge, siphonable, counterable, and sometimes forgeable.
Every partially-known thing renders as a smudge, so the valley itself generates open loops as the player walks it.

## Light Combat (environmental-puzzle flavored)

Not a combat game, but the valley has hostile targets so Rend, Ward, Mote, Counter seal, and the Battlemage staff have a reason to exist: wolves near the pasture, a bandit camp on the trade road, and whatever crawled out of your last consequence case.
Consequence cases are the combat content spawner; the thing that came through the portal is next week's field problem.

## Seals Are Field Equipment

Several seal types only make sense deployed in the world, and cases should demand it:

- **Trap seals**: walk out and place them where the wolves come through
- **Word seals**: stand next to the nervous farmer while he says the trigger word wrong twice
- **Sundial decrees**: be at the festival when your rain spell blooms in front of the whole village
- **Sympathetic seals**: scout and attune the target on-site first

## Domestic Casting (the valley's indoor twin)

The tower itself is a place where a wizard lives magically, and every chore is an excuse to cast:

- Fire Font under the cauldron instead of the torch for a brewing bonus
- Water motes tending the greenhouse
- Grasp to fetch scrolls from high shelves
- Portals between floors

Cheap content, and the cozy-sim heart of the game.

---

# Spells (starter examples)

Legacy recipes in the old grammar, to be re-expressed as verb sentences.

- **Jump** (Air+Bolt+Lift, self): jump super far
- **Slow Fall** (Air+Ward+Fall): slow your descent; classic contingency seal target
- **Portal** (Air+Tether): place two portals for quick travel
- **Fireball** (Fire+Bolt+Nova+Rend): the classic; a fire bolt that explodes on impact or at max distance

# Artifacts

Artifacts are acquired and placed in the tower, each with powerful effects.
Placement matters (see Adjacency).

- **Transmutation Mirror**: change how you look
- **Scrying Orb**: scry on key locations to learn information; range extended by the Observatory
- **Spellbook** (late-game): holds exactly ONE scroll.
  Casting from it consumes charges as normal but the book auto-rebinds a fresh copy on a long cooldown proportional to spell power.
  The scroll economy stays intact; the book buys convenience, not infinity.
- **Grandfather Clock of Perpetual Time Telling**: tells the time; improves sundial seal precision when placed in the hall
- **Battlemage Staff**: a combat hotbar holding up to 10 scrolls.
  Scrolls in the staff are still consumed on cast.
  Fast access, not free casts.
- **Spell Scroll Power Level Visor**: reads scroll power (max level scrolls read over 9000)
- **Identification Alembic**: identifies unknown brews so you can stop taste-testing (or keep taste-testing, coward)

# Fun Ideas (kept, now wired in)

- **Pipeweed**: smoke it, get a hazy screen effect.
  Pairs with fool's ink for comedic runs.
- **Beard storage**: the spell-card hotbar.
  Etch, stash, quick-draw.
- **Portal doors**: two portals in the base for fast traversal.
  Also the galaxy-brain solution to at least one village case.
- **Homunculus Bottle**: contains an artificial human life.

---

# Vertical Slice

The slice is defined in [game-bible.md](game-bible.md) section 6: the tower plus one farmstead, three NPCs, Case Minus One (The Locked Door) as the tutorial - getting into your own tower - then Case Zero (The Sour Milk) guided, Case One (The Sick Farmhand) open with zero new code, and one ambient standing-order system under day/night pressure.

The earlier drought-quest slice is retired as a slice; the Drought remains a flagship future case (see Multi-Resolution Design) for when the full village exists.

The moment to iterate on before anything else: reading a smudge in the field, proving it at the bench, watching the journal ink itself, and resolving the case in front of a witness.
If that loop does not feel good, no amount of seals and beard storage saves it.
That loop IS the game.
