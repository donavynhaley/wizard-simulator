# Wizard Simulator - Game Design Document

## High Concept

Live as a wizard in your tower.
Craft spells and potions, complete tasks for the local villagers and decrees from the king, and grow stronger and more renowned as you do.
The village watches your tower rise.

**Design Pillar: Style Pays.**
Solving a quest earns coin.
Solving it with flair earns renown.
Every system should offer a cheap path and a flashy path, and the flashy path should feed your name.
See Gilded Ink, multi-solution quests, storefront presentation, and trophy decor.

## Core Gameplay Loop

1. **Monitor** the village and kingdom from your tower through a window, scrying orb, or quest board.
2. **Accept** quests from villagers or decrees from the king.
3. **Research** in the library, then **craft** the spell or brew the potion the task demands.
4. **Deliver** the solution your way.
5. **Earn** renown and coin.
6. Repeat, with the village visibly growing and the king demanding more.

Decrees have hard deadlines.
Cheap and functional solutions work.
Gilded and dramatic solutions build your name.
Renown grows the tower and unlocks deeper crafting.
Coin buys reagents, inks, and furnishings.

Two reputation tracks run in parallel and sometimes conflict:

- **Village Trust** - earned by helping the common folk.
- **Royal Favor** - earned by completing decrees.

Village Trust unlocks trade, reagent access, standing orders, and village growth.
Royal Favor unlocks rare inks, artifacts, gold-leaf payments, and protection from the tax collector.

Some quests force a choice between the two.
Picking sides is the drama engine of the game.

## Pillar 1: Spell Crafting

A completed spell exists only on a spell scroll, and holding a scroll is the only way to cast it.
A scroll can have multiple charges, and once they are all used it disappears.
Scrolls are consumable.
Full stop.
Artifacts that store spells still consume scrolls, so the scroll economy is never bypassed.

### Crafting Steps

The core of crafting comes from knowledge.
The library teaches the wizard how to craft spells.
To craft, bring each ingredient to the crafting table.

1. **Choose an element**: Fire, Earth, Air, or Water.
2. **Carve runes into the scroll**: a hand-drawing minigame where the wizard scribes a series of runes in a valid order.
3. **Apply a seal**: an optional step that determines how and when the spell triggers.
4. **Cast, shelve, or alter**: use the scroll, stash it on the shelf, or take it to an artifact for further alteration.

Each element is available in raw form from a source in the tower.
The player magically grabs one element at a time and brings it to the spellcraft table.
Beginners use standard spell ink.
Other inks change the spell's behavior.
The default seal is cast-on-use.
Using the scroll burns a charge.

### Rune Mastery

Hand-scribing rune number 400 is tedium, not immersion.
Scribe a rune cleanly enough times and you unlock **Practiced Hand** for that rune.
Practiced Hand is an auto-scribe at standard quality.
Manual scribing always remains available and grants a quality bonus.
Quality bonuses can include potency, an extra-charge chance, or a renown multiplier on use.
Automate the solved problem, reward the craftsman.

### Recipe Discovery

The library never hands over complete recipes.
It gives **fragments**.
Examples include "A Nova rune must follow a Form rune" and "Rime ink rejects Fire."
Experimentation fills the gaps.
Failed scribes never produce nothing.
They produce a **misfire** with a funny or minor effect, plus a library note hinting at what went wrong.
Discovery should feel like scholarship, not menu reading.

### Elements

- **Earth** - the Barrel of Infinite Dirt
- **Water** - the Endless Spring
- **Fire** - the Torch of Eternal Flame
- **Air** - the Conch of Aerlevsedi

Aerlevsedi is pronounced air-LEV-seh-dee.
Elements are infinite.
Scarcity lives in inks, reagents, and time, not raw elements.

### Form Runes

- **Bolt**: fires a projectile.
- **Nova**: detonates in a radius around the caster or the impact point.
- **Ward**: raises a barrier.
- **Font**: creates a lingering field on the ground.
- **Tether**: links two points.
- **Mote**: spawns a tiny autonomous elemental servant that seeks and applies the effect.

Fire plus Bolt creates a firebolt.
Water plus Bolt creates an ice lance.
Earth plus Bolt creates a hurled rock.
Air plus Bolt creates a lance of wind that knocks back.
Nova turns a Bolt into a Fireball on landing.
Earth Ward creates a stone wall.
Fire Ward creates a burning shield that damages attackers.
Water Ward creates a wall that douses or slows.
Fire Font creates burning tiles.
Water Font creates a healing spring.
Earth Font creates quicksand that roots.
Air Font creates an updraft you can ride.
Tether is the Portal and teleport backbone.
A fire mote is a will-o-wisp that chases enemies.

### Effect Runes

- **Rend**: damage.
- **Mend**: heal or repair.
- **Grasp**: root, hold, or physically grab objects at range.
- **Lift / Fall**: vertical control.
- **Reveal**: light, detection, or scrying.

Rend is the default hostile verb.
Water plus Font plus Mend creates the healing spring the village quest wants.
Lift creates Jump.
Air plus Ward plus Fall creates Slow Fall.

### Modifier Runes

- **Greater**: bigger, stronger, and costs more.
- **Fork**: splits into 2 to 3 weaker copies.
- **Chain**: effect jumps to nearby valid targets.
- **Seek**: adds homing.
- **Echo**: casts twice with a short delay off one charge.
- **Quicken**: faster cast and faster projectile, with shorter range as the tradeoff.
- **Bind**: the effect lingers on whatever it hit instead of firing once.

Greater is the plain "more power" dial.

### Inks

All non-standard inks are alchemy products.
This is the bridge between spellcrafting and alchemy.

- **Standard ink**: bought cheap, works fine, earns nothing extra.
- **Blood ink**: costs a chunk of your own health and hits much harder.
- **Rime ink**: staples a chill or slow rider onto any spell, even a Mend.
- **Quicksilver ink**: makes everything cast from that scroll faster but shorter-lived.
- **Gilded ink**: purely cosmetic power.
- **Fool's ink**: unstable, with a small chance to misfire in a funny way.
- **Elemental inks**: inks brewed from raw elements.

Blood ink is brewed from your own blood at the still.
Rime ink is brewed from winter reagents.
Gilded ink makes the spell flashier and earns more renown from the same result.
Gilded ink is brewed from gold leaf, which the king pays in.
Cheap ink solves the quest.
Gilded ink builds your name.
This ink is the core loop.
Fool's ink is brewed from failed-batch sludge.
Fool's ink pairs with pipeweed haze for comedic runs.
Fire ink on a fire spell overcharges it, but any opposing element in the runes fizzles.

### Seals

- **Contingency**: binds to you and auto-fires on a condition.
- **Trap/Ward**: binds to a location or object and fires on proximity or disturbance.
- **Word seal**: stays dormant until a spoken trigger word.
- **Sympathetic seal**: fires when an attuned target does something.
- **Sundial seal**: fires at a specific world time.
- **Counter seal**: stays dormant until it detects an incoming spell or attack, then reflects or negates.

Contingency is the insurance category.
"On falling" casts Slow Fall.
"On low health" pops a Ward.
This makes a wizard feel prepared rather than reactive.
Trap/Ward turns any offensive scroll into a placed mine.
With Word seal, you can hand the scroll to an NPC or plant it, and it fires when they say the word.
Word seal is strong for quest scripting.
Sympathetic seal wires into the Scrying Orb and the attune alteration.
You can attune a scrying scroll to the king's rival, and it resolves the moment he leaves his keep.
Sundial seal can fire at dawn, dusk, or a named calendar date.
It is built for decrees.
"Make it rain by the harvest festival" means sealing a Water plus Font plus Mend scroll to bloom at that moment.
This gives the deadline system real teeth.
Counter seal is a magical parry.

### Further Alterations

Further alterations are done through artifacts.
The spell is already sealed.
Alterations are about delivery, storage, and combos, not the effect itself.

- **Bind two scrolls**: fuse them so one cast fires both.
- **Fold into a paper familiar**: the scroll becomes an origami bird or beetle that flies to a target and delivers the spell.
- **Set a fuse**: change the seal after the fact to a timer or proximity trigger.
- **Overcharge**: adds a charge or boosts power, with a chance to detonate in your hand.
- **Etch onto a spell-card**: miniaturize the scroll to fit in beard storage.
- **Attune to a person or place**: locks a Seek or Reveal spell onto a specific target.
- **Split charges**: break a 3-charge scroll into three 1-charge scrolls to sell or hand out.

Bind two scrolls supports combinations like Portal-out plus Fireball, or a Ward that drops the instant a Bolt lands.
Fold into a paper familiar is the ranged delivery drone.
It requires the Aviary.
Overcharge creates tension for the greedy.
Etching onto a spell-card gives beard storage a real gameplay reason to exist.
"Watch the eastern lord" means attuning a scrying scroll to him.
Split charges feeds the storefront economy.

## Pillar 2: Alchemy

Alchemy is the scarcity economy and the ink factory.
Where spellcrafting is precision and knowledge, alchemy is timing and process.
It should feel like cooking under pressure, not another drawing minigame.

### The Brewing Process

1. **Prep**: chop, grind, or crush reagents.
2. **Heat**: feed the burner with the Torch of Eternal Flame.
3. **Stir**: stir patterns and timing during the boil.
4. **Pull**: take it off the flame at the right moment.

Prep quality affects potency.
Heat control matters.
Scorch a brew and it degrades.
Early pulls are weak.
Late pulls become sludge.

### Reagents

Elements are infinite.
Reagents are not.

Sources:

- **Village trade**: villagers sell herbs and materials.
- **Quest rewards**: rare reagents come from completed tasks.
- **The Greenhouse**: a tower floor that grows staple herbs on a real-time cycle.
- **Distilled spells**: catch your own fire mote in a jar and distill it into concentrated fire essence.
- **The king's payments**: gold leaf and rare royal reagents come only from decrees.

Village prices and stock depend on Village Trust.
Spells become reagents.
The loop closes in both directions.
Gold leaf feeds Gilded ink.

### Products

- **Inks**: every non-standard ink.
- **Potions**: healing, buffs, and utility.
- **Essences**: concentrated elements used as premium reagents or overcharge fuel.

Alchemy is mandatory for high-end spellcraft.
Potions are the village's bread and butter.

### Systems

- **Standing orders**: the village apothecary wants 3 healing potions a week.
- **Taste-testing**: unknown brew means you can drink it.
- **Failed batches**: produce sludge.
- **Aging**: potions stored in the Cellar improve over in-game time.

Standing orders create recurring passive income against quest spikes.
They make the wizard feel like the town pharmacist.
Taste-testing uses a random effect table.
Some results are hilarious, such as haze, floating, or voice change.
An identification artifact removes the guesswork later.
Failed-batch sludge is greenhouse fertilizer or the base for Fool's ink.
Failure always feeds something.
Potion aging hooks into the calendar.
A potion laid down in spring is stronger by harvest.

## Pillar 3: Task Completion

### Quest Sources

- **Village quests**: posted on the board, delivered by visiting villagers, or spotted through the tower window or scrying orb.
- **Royal decrees**: arrive by courier with a wax seal and a hard deadline.

Village quests have flexible deadlines and build Village Trust.
Royal decrees build Royal Favor.
Ignoring a royal decree is refusing the king.

### Multi-Solution Design

Every quest should have at least two valid solutions, and payout scales with elegance and flash.

Example: the Drought Quest.

- Cast a rain spell from the tower top.
- Place a Water plus Font plus Mend spring in the fields.
- Brew and distribute cloud-seed potions.
- Tether a portal from the Endless Spring to the village well.

Casting rain is functional.
Placing a spring is elegant and permanent.
Cloud-seed potions are the alchemy route.
The portal solution is galaxy-brain and earns huge renown.
Gilded ink multiplies the renown of any route.
This is where Style Pays actually plays out.

### Deadlines and Failure

Failure has teeth or deadlines are fake.

- **Failed decree**: the tax collector arrives.
- **Failed village quest**: reagent prices rise, the quest board thins, and villagers stop selling to you.
- **The Rival Wizard**: takes quests you ignore or fail and collects the renown you did not.

The tax collector can seize coin, seize an artifact, or padlock a tower floor until you pay.
Repeat failures escalate.
Failed village quests starve alchemy.
The Rival Wizard builds his own tower on the far hill.
You can watch it grow.
This creates urgency without putting a timer on everything.

### Conflict Quests

Periodically the two reputation tracks collide.
The king decrees the spring be diverted to his war camp.
The village needs it for harvest.
There is no solution that satisfies both.
These choices shape which unlocks you see and how NPCs treat you.

### Consequence Quests

Your solutions create new problems.
The fire font that cleared the wolf den also torched the orchard.
That creates a new quest.
The portal to the well let something through.
That creates a new quest.
The world reacts to your choices and generates content from them.

### Delivery Requirements

Quests should pull specific crafting features so every system gets exercised.

- A word seal handed to a nervous NPC who must say the trigger at the right moment.
- A paper familiar flown across the valley to a target you cannot reach.
- An attunement to a target you have never seen, forcing scrying orb use first.
- A sundial seal timed to a festival, forcing calendar awareness.

### Calendar and Seasons

The sundial seal implies a clock.
Make it core.

Four seasons should include:

- Seasonal quests, such as harvest, midwinter festival, and spring floods.
- Seasonal reagents, such as Rime ink only brewing in winter or costing triple otherwise.
- Decree deadlines tied to named dates.
- Potion aging measured against the calendar.

### Village Growth

The village is the progression bar, visible from the tower window.
Solve irrigation and the fields expand.
Fund the mill and a new building appears.
Growth unlocks new quest tiers, new shops, new reagents, and bigger standing orders.
Helping the village literally builds the world you look at every day.

## Pillar 4: Tower Customization

Functional rooms first, decor second.
Every room is a progression unlock wearing a cosmetic hat.

### The Tower Grows

The tower gains floors at renown milestones.
The village watches it rise.
The rival's tower rises in answer.
Renown is made physical and visible from anywhere on the map.

### Functional Rooms

- **Library**: gates rune knowledge and recipe fragments.
- **Alchemy Lab**: provides brewing stations.
- **Cellar**: enables potion aging.
- **Greenhouse**: grows staple reagents on the calendar cycle.
- **Observatory**: extends scrying orb range and unlocks sympathetic seals at distance.
- **Aviary**: houses paper familiars.
- **Entry Hall / Storefront**: lets villagers walk up and buy potions and split-charge scrolls off your display shelves.

Upgrading the library upgrades your spell ceiling.
Alchemy Lab upgrades add burners, better stills, and batch size.
A deeper cellar allows longer aging and stronger results.
The Aviary is required for the fold alteration.
Aviary upgrades add range and capacity.
Storefront layout and presentation affect sales.
Presentation pays, using the same pillar as Gilded ink.

### Artifact Adjacency

Placement is a light puzzle, not pure decoration.

- Scrying orb by a window sees further.
- Spellbook near the library recharges faster.
- Grandfather clock in the hall makes sundial seals more precise.
- Torch near the lab improves burner control.

### Organization as Gameplay

Scroll shelves, ingredient jars, and labels can be sorted or chaotic.
The beard is a hotbar.
Etch spell-cards, store them in the beard, and quick-draw in the field.
A messy tower where you cannot find the fireball scroll during a decree deadline is emergent comedy.
Cleaning up is its own quiet satisfaction.

### Trophies

Styled quest completions earn decor you cannot buy.
The village gifts a statue.
The king sends a banner.
The rival sends a passive-aggressive fruit basket.
Cosmetics are proof of deeds.

### Tower Defense

Tower defense should be rare and scripted.
Fail the king badly enough and knights arrive.
Botch the wrong quest and something crawls out of the consequence.
Use one or two scripted sieges, not a tower-defense subsystem.
This is where counter seals, ward traps, and contingencies get a home turf to prove themselves.

## Spells

Starter examples:

- **Jump**: Air plus Bolt plus Lift, self.
- **Slow Fall**: Air plus Ward plus Fall.
- **Portal**: Air plus Tether.
- **Fireball**: Fire plus Bolt plus Nova plus Rend.

Jump lets the wizard jump super far.
Slow Fall is a classic contingency seal target.
Portal places two portals for quick travel.
Fireball is the classic fire bolt that explodes on impact or at max distance.

## Artifacts

Artifacts are acquired and placed in the tower.
Each artifact has powerful effects.
Placement matters through adjacency.

- **Transmutation Mirror**: change how you look.
- **Scrying Orb**: scry on key locations to learn information.
- **Spellbook**: holds exactly one scroll.
- **Grandfather Clock of Perpetual Time Telling**: tells the time.
- **Battlemage Staff**: a combat hotbar holding up to 10 scrolls.
- **Spell Scroll Power Level Visor**: reads scroll power.
- **Identification Alembic**: identifies unknown brews so you can stop taste-testing.

The Scrying Orb range is extended by the Observatory.
The Spellbook is late-game.
Casting from the Spellbook consumes charges as normal, but the book auto-rebinds a fresh copy on a long cooldown proportional to spell power.
The scroll economy stays intact.
The book buys convenience, not infinity.
The Grandfather Clock improves sundial seal precision when placed in the hall.
Scrolls in the Battlemage Staff are still consumed on cast.
The staff offers fast access, not free casts.
Max-level scrolls read over 9000 on the visor.
You can keep taste-testing even after getting the Identification Alembic if you want the chaos.

## Fun Ideas

- **Pipeweed**: smoke it and get a hazy screen effect.
- **Beard storage**: the spell-card hotbar.
- **Portal doors**: two portals in the base for fast traversal.

Pipeweed pairs with Fool's ink for comedic runs.
Beard storage supports etching, stashing, and quick-drawing.
Portal doors are also the galaxy-brain solution to at least one village quest.

## Vertical Slice Scope

Prove the loop is fun before building the full combinatorial space.

The slice:

- **One element**: Water.
- **Two form runes**: Bolt and Font.
- **Two effect runes**: Rend and Mend.
- **Two inks**: Standard and Gilded.
- **One seal**: cast-on-use only.
- **One alchemy recipe**: healing potion.
- **Three quests**: one village fetch or brew, one multi-solution drought quest, and one timed decree.
- **One tower floor**: crafting table, library shelf, brewing station, and storefront window.

Gilded ink must be in the slice because the pillar must be in the slice.
The healing potion feeds a standing order.

The loop to validate:

1. Quest arrives.
2. Research fragment appears in the library.
3. Player scribes a scroll.
4. Player chooses cheap or Gilded.
5. Player solves the quest.
6. Renown ticks upward.
7. One village field visibly improves.

If that loop is fun with four runes and two inks, the rest of the doc is content.
If it is not, no amount of seals and beard storage saves it.
