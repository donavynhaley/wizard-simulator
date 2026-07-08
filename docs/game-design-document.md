# Wizard Simulator - Game Design Document

## High Concept

Live as a wizard in your tower. Craft spells and potions, complete tasks for the local villagers and decrees from the king, and grow stronger and more renowned as you do. The village watches your tower rise.

**Design Pillar 1: Style Pays.** Solving a quest earns coin. Solving it with flair earns renown. Every system should offer a cheap path and a flashy path, and the flashy path should feed your name. (See Gilded Ink, multi-solution quests, storefront presentation, trophy decor.)

**Design Pillar 2: The Tower Makes, The Valley Casts.** The tower is where spells are made; the valley is where the wizard happens. Crafting a fireball is not the fantasy. Standing on a hill throwing one in front of a cheering village is. Most quests require your presence and your casting, not just your product.
 
## Core Gameplay Loop

1. **Monitor** the village and kingdom from your tower (window, scrying orb, quest board).
2. **Accept** quests from villagers or decrees from the king (decrees have hard deadlines).
3. **Research** in the library, then **craft** the spell or brew the potion the task demands.
4. **Go out and cast.** Most quests are fieldwork: grab scrolls, stuff the beard, head into the valley, and solve the problem on-site with villagers watching. Cheap and functional, or gilded and dramatic.
5. **Earn** renown and coin. Renown grows the tower and unlocks deeper crafting. Coin buys reagents, inks, and furnishings.
6. Repeat, with the village visibly growing and the king demanding more.

Two reputation tracks run in parallel and sometimes conflict:

- **Village Trust** - earned by helping the common folk. Unlocks trade, reagent access, standing orders, and village growth.
- **Royal Favor** - earned by completing decrees. Unlocks rare inks, artifacts, gold-leaf payments, and protection from the tax collector.

Some quests force a choice between the two. Picking sides is the drama engine of the game.

---

# Pillar 1: Spell Crafting

A completed spell exists only on a spell scroll, and holding a scroll is the only way to cast it. A scroll can have multiple charges, and once they are all used it disappears. Scrolls are consumable. Full stop. Artifacts that store spells still consume scrolls (see Artifacts) so the scroll economy is never bypassed.

## Crafting Steps

The core of crafting comes from knowledge. The library teaches the wizard how to craft spells. To craft, bring each ingredient to the crafting table:

1. **Choose an element**: Fire, Earth, Air, or Water. Each is available in raw form from a source in the tower. The player magically grabs one element at a time and brings it to the spellcraft table.
2. **Carve runes into the scroll**: a hand-drawing minigame where the wizard scribes a series of runes in a valid order. Beginners use standard spell ink; other inks change the spell's behavior.
3. **Apply a seal** : determines how and when the spell triggers. Default is cast-on-use.
4. **Cast, shelve, or alter**: use the scroll (burns a charge), stash it on the shelf, or take it to an artifact for further alteration.

### Rune Mastery (anti-tedium ramp)

Hand-scribing rune #400 is tedium, not immersion. Scribe a rune cleanly enough times and you unlock **Practiced Hand** for that rune: an auto-scribe at standard quality. Manual scribing always remains available and grants a quality bonus (potency, extra charge chance, renown multiplier on use). Automate the solved problem, reward the craftsman.

### Recipe Discovery

The library never hands over complete recipes. It gives **fragments**: "A Nova rune must follow a Form rune," "Rime ink rejects Fire." Experimentation fills the gaps. Failed scribes never produce nothing; they produce a **misfire** with a funny or minor effect, plus a library note hinting at what went wrong. Discovery should feel like scholarship, not menu reading.

## Elements

- **Earth** - the Barrel of Infinite Dirt
- **Water** - the Endless Spring
- **Fire** - the Torch of Eternal Flame
- **Air** - the Conch of Aerlevsedi (air-LEV-seh-dee)

Elements are infinite. Scarcity lives in inks, reagents, and time, not raw elements.

## Form Runes

- **Bolt**: fires a projectile. Fire+Bolt = firebolt, Water+Bolt = ice lance, Earth+Bolt = hurled rock, Air+Bolt = a lance of wind that knocks back.
- **Nova**: detonates in a radius around the caster or the impact point. Turns a Bolt into a Fireball on landing.
- **Ward**: raises a barrier. Element flavors it. Earth = stone wall, Fire = burning shield that damages attackers, Water = wall that douses/slows.
- **Font**: a lingering field on the ground. Fire = burning tiles, Water = healing spring, Earth = quicksand that roots, Air = an updraft you can ride.
- **Tether**: links two points. The Portal/teleport backbone.
- **Mote**: spawns a tiny autonomous elemental servant that seeks and applies the Effect. A fire mote is a will-o-wisp that chases enemies.

## Effect Runes

- **Rend**: damage. The default hostile verb.
- **Mend**: heal or repair. Water+Font+Mend = the healing spring the village quest wants.
- **Grasp**: root, hold, or physically grab objects at range.
- **Lift / Fall**: vertical control. Lift = Jump. Air+Ward+Fall = Slow Fall.
- **Reveal**: light, detection, scrying.

## Modifier Runes

- **Greater**: bigger, stronger, costs more. The plain "more power" dial.
- **Fork**: splits into 2 to 3 weaker copies.
- **Chain**: effect jumps to nearby valid targets.
- **Seek**: adds homing.
- **Echo**: casts twice with a short delay off one charge.
- **Quicken**: faster cast and faster projectile, shorter range as the tradeoff.
- **Bind** (as modifier): the effect lingers on whatever it hit instead of firing once.

## Inks

All non-standard inks are alchemy products (see Pillar 2). This is the bridge between the two crafting systems.

- **Standard ink**: bought cheap, works fine, earns nothing extra.
- **Blood ink**: spell costs a chunk of your own health, hits much harder. Brewed from your own blood at the still.
- **Rime ink**: staples a chill/slow rider onto any spell, even a Mend. Brewed from winter reagents.
- **Quicksilver ink**: everything cast from that scroll is faster but shorter-lived.
- **Gilded ink**: purely cosmetic power. Makes the spell flashier and earns more renown from the same result. Brewed from gold leaf, which the king pays in. Cheap ink solves the quest; gilded ink builds your name. This ink IS the core loop.
- **Fool's ink**: unstable, small chance to misfire in a funny way. Brewed from failed-batch sludge. Pairs with pipeweed haze for comedic runs.
- **Elemental inks**: ink brewed from a raw element. Fire ink on a fire spell overcharges it, but any opposing element in the runes fizzles.

## Seals (how the spell triggers)

- **Contingency**: binds to *you*, auto-fires on a condition. "On falling" casts Slow Fall. "On low health" pops a Ward. The insurance category; makes a wizard feel prepared rather than reactive.
- **Trap/Ward**: binds to a location or object, fires on proximity or disturbance. Turns any offensive scroll into a placed mine.
- **Word seal**: dormant until a spoken trigger word. Hand the scroll to an NPC or plant it, and it fires when *they* say the word. Great for quest scripting.
- **Sympathetic seal**: fires when an attuned target does something. Attune a scrying scroll to the king's rival; it resolves the moment he leaves his keep. Wires into the Scrying Orb and the attune alteration.
- **Sundial seal**: fires at a specific world-time (dawn, dusk, a named calendar date). Built for decrees: "make it rain by the harvest festival" means sealing a Water/Font/Mend scroll to bloom at that moment. Gives the deadline system real teeth.
- **Counter seal**: dormant until it detects an incoming spell or attack, then reflects or negates. A magical parry.

## Further Alterations (done through artifacts)

The spell is already sealed. Alterations are about delivery, storage, and combos, not the effect itself:

- **Bind two scrolls**: fuse them so one cast fires both. Portal-out plus Fireball, or a Ward that drops the instant a Bolt lands.
- **Fold into a paper familiar**: the scroll becomes an origami bird or beetle that flies to a target and delivers the spell. The ranged delivery drone. Requires the Aviary (see Tower).
- **Set a fuse**: change the Seal after the fact to a timer or proximity trigger.
- **Overcharge**: adds a charge or boosts power, with a chance to detonate in your hand. Tension for the greedy.
- **Etch onto a spell-card**: miniaturize the scroll to fit in beard storage. Gives beard storage a real gameplay reason to exist.
- **Attune to a person or place**: locks a Seek/Reveal spell onto a specific target. "Watch the eastern lord" means attuning a scrying scroll to him.
- **Split charges**: break a 3-charge scroll into three 1-charge scrolls to sell or hand out. Economy hook; feeds the storefront.

---

# Pillar 2: Alchemy

Alchemy is the scarcity economy and the ink factory. Where spellcrafting is precision and knowledge, alchemy is timing and process. It should feel like cooking under pressure, not another drawing minigame.

## The Brewing Process

1. **Prep**: chop, grind, or crush reagents. Prep quality affects potency.
2. **Heat**: the burner is fed by the Torch of Eternal Flame (cross-system tie). Heat control matters; scorch a brew and it degrades.
3. **Stir**: stir patterns and timing during the boil.
4. **Pull**: take it off the flame at the right moment. Early = weak, late = sludge.

## Reagents (the scarcity loop)

Elements are infinite; reagents are not. Sources:

- **Village trade**: villagers sell herbs and materials. Prices and stock depend on Village Trust.
- **Quest rewards**: rare reagents come from completed tasks.
- **The Greenhouse**: a tower floor that grows staple herbs on a real-time cycle.
- **Distilled spells**: catch your own fire mote in a jar and distill it into concentrated fire essence. Spells become reagents; the loop closes in both directions.
- **The king's payments**: gold leaf (for gilded ink) and rare royal reagents come only from decrees.

## Products

- **Inks**: every non-standard ink. Alchemy is mandatory for high-end spellcraft.
- **Potions**: healing, buffs, utility. The village's bread and butter.
- **Essences**: concentrated elements used as premium reagents or overcharge fuel.

## Systems

- **Standing orders**: the village apothecary wants 3 healing potions a week. Recurring passive income against quest spikes. The wizard as town pharmacist.
- **Taste-testing**: unknown brew? Drink it. Random effect table, some hilarious (haze, floating, voice change). An identification artifact removes the guesswork later.
- **Failed batches**: produce sludge. Sludge is greenhouse fertilizer or the base for fool's ink. Failure always feeds something.
- **Aging**: potions stored in the Cellar improve over in-game time. Hooks into the calendar; a potion laid down in spring is stronger by harvest.

---

# Pillar 3: Task Completion

## Quest Sources

- **Village quests**: posted on the board, delivered by visiting villagers, or spotted through the tower window / scrying orb. Flexible deadlines, build Village Trust.
- **Royal decrees**: arrive by courier with a wax seal and a hard deadline. Build Royal Favor. Ignoring one is refusing the king.

## Quest Types: Turn-In vs Fieldwork (the 25/75 rule)

- **Turn-in quests (~25%)**: brew potions, sell split-charge scrolls, fill standing orders. The economy layer. Product changes hands at the storefront or by courier.
- **Fieldwork quests (~75%)**: the quest board does not say "bring me a water scroll." It says "the mill is on fire," "something is taking sheep from the eastern pasture," "the old bridge collapsed and the harvest carts cannot cross." You grab scrolls, stuff the beard, and go. The solution is cast by you, on-site, witnessed by villagers.

Witnessing is the mechanic that makes Style Pays real: gilded ink renown only counts when someone sees the cast. A gilded fireball detonated alone in the woods earns base renown. The same cast in front of the harvest crowd earns the multiplier.

## Multi-Solution Design, Graded on Style

Every quest should have at least two valid solutions, and payout scales with elegance and flash. Example, the Drought Quest:

- Cast a rain spell from the tower top (functional)
- Place a Water+Font+Mend spring in the fields (elegant, permanent)
- Brew and distribute cloud-seed potions (alchemy route)
- Tether a portal from the Endless Spring to the village well (galaxy-brain, huge renown)

Gilded ink multiplies the renown of any route. This is where Style Pays actually plays out.

## Deadlines and Failure

Failure has teeth or deadlines are fake.

- **Failed decree**: the tax collector arrives. He seizes coin, or an artifact, or padlocks a tower floor until you pay. Repeat failures escalate.
- **Failed village quests**: reagent prices rise, the quest board thins, villagers stop selling to you. Alchemy starves.
- **The Rival Wizard**: takes quests you ignore or fail and collects the renown you did not. He builds his own tower on the far hill. You can watch it grow. Urgency without putting a timer on everything.

## Conflict Quests

Periodically the two tracks collide. The king decrees the spring be diverted to his war camp; the village needs it for harvest. There is no solution that satisfies both. These choices shape which unlocks you see and how NPCs treat you.

## Consequence Quests

Your solutions create new problems. The fire font that cleared the wolf den also torched the orchard: new quest. The portal to the well let something *through*: new quest. The world reacts to your choices and generates content from them.

## Delivery Requirements

Quests should pull specific crafting features so every system gets exercised:

- A word seal handed to a nervous NPC who must say the trigger at the right moment
- A paper familiar flown across the valley to a target you cannot reach
- An attunement to a target you have never seen, forcing scrying orb use first
- A sundial seal timed to a festival, forcing calendar awareness

## Calendar and Seasons

The sundial seal implies a clock; make it core. Four seasons with:

- Seasonal quests (harvest, midwinter festival, spring floods)
- Seasonal reagents (rime ink only brews in winter, or costs triple otherwise)
- Decree deadlines tied to named dates
- Potion aging measured against it

## Village Growth

The village is the progression bar, visible from the tower window. Solve irrigation and the fields expand. Fund the mill and a new building appears. Growth unlocks new quest tiers, new shops, new reagents, and bigger standing orders. Helping the village literally builds the world you look at every day.

---

# Pillar 4: Tower Customization

Functional rooms first, decor second. Every room is a progression unlock wearing a cosmetic hat.

## The Tower Grows

The tower gains floors at renown milestones. The village watches it rise; the rival's tower rises in answer. Renown made physical, visible from anywhere on the map.

## Functional Rooms

- **Library** (tiers): gates rune knowledge and recipe fragments. Upgrading the library is upgrading your spell ceiling.
- **Alchemy Lab**: brewing stations. Upgrades add burners, better stills, batch size.
- **Cellar**: enables potion aging. Deeper cellar, longer aging, stronger results.
- **Greenhouse**: grows staple reagents on the calendar cycle.
- **Observatory**: extends scrying orb range and unlocks sympathetic seals at distance.
- **Aviary**: houses paper familiars; required for the fold alteration, upgrades add range and capacity.
- **Entry Hall / Storefront**: villagers walk up and buy potions and split-charge scrolls off your display shelves. Layout and presentation affect sales. Presentation pays, same pillar as gilded ink.

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

Styled quest completions earn decor you cannot buy: the village gifts a statue, the king sends a banner, the rival sends a passive-aggressive fruit basket. Cosmetics as proof of deeds.

## Tower Defense (rare, scripted)

Fail the king badly enough and knights arrive. Botch the wrong quest and something crawls out of the consequence. One or two scripted sieges, not a tower-defense subsystem. This is where counter seals, ward traps, and contingencies get a home turf to prove themselves.

---

# Pillar 5: The Valley (Fieldwork)

The world outside the tower. This is where 90% of crafted spells earn their existence. The valley answers the question "why did I craft this" for every rune, seal, and alteration in the game.

## Traversal With Texture

The map has verticality and obstacles so utility spells stop being orphans:

- The herb that only grows on the cliff ledge (Jump up, Slow Fall down)
- The cave reagent across a chasm (Tether/Portal)
- The dark shrine that must be scouted before attuning (Reveal)
- The boulder blocking the harvest road (Grasp, or Earth+Bolt if you feel dramatic)
- The updraft canyon crossed by riding your own Air Font

**Reagent gathering requires casting.** The best alchemy reagents sit in places only a competent caster can reach, which welds the scarcity loop to spellcasting. Crafting feeds casting feeds crafting.

## Light Combat (environmental-puzzle flavored)

Not a combat game, but the valley has hostile targets so Rend, Ward, Mote, Counter seal, and the Battlemage staff have a reason to exist: wolves near the pasture, a bandit camp on the trade road, and whatever crawled out of your last consequence quest. Consequence quests are the combat content spawner; the thing that came through the portal is next week's field problem.

## Seals Are Field Equipment

Several seal types only make sense deployed in the world, and quests should demand it:

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

- **Jump** (Air+Bolt+Lift, self): jump super far
- **Slow Fall** (Air+Ward+Fall): slow your descent; classic contingency seal target
- **Portal** (Air+Tether): place two portals for quick travel; the tower-traversal fun idea, formalized
- **Fireball** (Fire+Bolt+Nova+Rend): the classic; a fire bolt that explodes on impact or at max distance

# Artifacts

Artifacts are acquired and placed in the tower, each with powerful effects. Placement matters (see Adjacency).

- **Transmutation Mirror**: change how you look
- **Scrying Orb**: scry on key locations to learn information; range extended by the Observatory
- **Spellbook** (late-game): holds exactly ONE scroll. Casting from it consumes charges as normal but the book auto-rebinds a fresh copy on a long cooldown proportional to spell power. The scroll economy stays intact; the book buys convenience, not infinity.
- **Grandfather Clock of Perpetual Time Telling**: tells the time; improves sundial seal precision when placed in the hall
- **Battlemage Staff**: a combat hotbar holding up to 10 scrolls. Scrolls in the staff are still consumed on cast. Fast access, not free casts.
- **Spell Scroll Power Level Visor**: reads scroll power (max level scrolls read over 9000)
- **Identification Alembic**: identifies unknown brews so you can stop taste-testing (or keep taste-testing, coward)

# Fun Ideas (kept, now wired in)

- **Pipeweed**: smoke it, get a hazy screen effect. Pairs with fool's ink for comedic runs.
- **Beard storage**: the spell-card hotbar. Etch, stash, quick-draw.
- **Portal doors**: two portals in the base for fast traversal. Also the galaxy-brain solution to at least one village quest.
- **Homunculus Bottle**: contains an artificaial human life. 

---

# Vertical Slice Scope

Prove the loop is fun before building the full combinatorial space. The slice:

- **One element**: Water
- **Two form runes**: Bolt, Font
- **Two effect runes**: Rend, Mend
- **Two inks**: Standard, Gilded (the pillar must be in the slice)
- **One seal**: cast-on-use only
- **One alchemy recipe**: healing potion (feeds a standing order), standard scroll ink (fills the spellcraft table with ink)
- **Three quests**: one turn-in brew (standing order), one FIELD quest (the drought, solved on-site with villagers watching), one timed decree
- **One tower floor**: crafting table, library shelf, brewing station, storefront window
- **One small field area**: the walk from tower to the drought-stricken fields, with a single cliff-ledge reagent requiring a Jump/Slow Fall cast to reach
- **The loop to validate**: quest arrives, research fragment in library, scribe scroll, choose cheap vs gilded, walk out, cast the Water Font in front of the gathered village, watch renown tick and the field visibly green up

The moment to iterate on before anything else: casting a gilded Water Font in front of a cheering crowd. If that beat does not feel good, no amount of seals and beard storage saves it. That moment IS the game.
