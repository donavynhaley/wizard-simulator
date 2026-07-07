# Wizard Simulator - Game Design Research

## Intent

Wizard Simulator should be a first-person 3D fantasy simulator with comedy, danger, and tactile magical work.
The target visual feel is low-poly, grimy, analog, and slightly uncanny in the way Lethal Company makes simple 3D spaces feel cheap, hostile, funny, and memorable.

The design should not be a generic spellcasting action game.
The stronger direction is a wizard labor game: preparing unstable spells, gathering dangerous ingredients, maintaining a tower, helping or disappointing clients, and trying to satisfy increasingly unreasonable arcane authorities.
Contract jobs are a strong possible structure, but the Lethal Company overlap is primarily visual style rather than a requirement to copy its quota/extraction format.

## Current Concept

You are a working wizard living in a large, strange wizard tower.
The tower is your home, workshop, library, laboratory, and business.
Local peasants come to you with practical magical problems, while the king or queen occasionally sends larger, more dangerous commissions.

The fantasy is not just casting spells in combat.
The fantasy is doing the daily work of being a wizard:

- Researching spells in a huge library.
- Crafting spells from discovered words, symbols, materials, and schools of magic.
- Brewing potions for clients, experiments, and field work.
- Maintaining the tower and its unstable magical rooms.
- Helping peasants with curses, monsters, sickness, bad harvests, haunted objects, and magical accidents.
- Taking royal jobs that pay well but create bigger stakes and political consequences.

The game should support multiplayer well as a long-term design goal, because a wizard workshop naturally creates role-based chaos.
However, the first version should be solo-first.
Multiplayer should be treated as a future architecture consideration, not a required MVP feature for a solo developer.

## Reference Games

### Lethal Company - Visual Style Reference

Core reference: [Lethal Company](https://en.wikipedia.org/wiki/Lethal_Company)

Primary visual patterns:

- The low-poly, retro-futurist style makes the world feel cheap, uncanny, and funny at the same time.
- Forms are simple and readable, but lighting, fog, darkness, audio, and camera treatment make spaces feel unsafe.
- Texture detail is intentionally restrained, with surfaces that feel worn, dirty, and practical rather than polished.
- Characters, props, and environments have a handmade, compressed, slightly awkward quality that becomes part of the charm.
- The UI and interaction language feel diegetic and analog instead of glossy.

Wizard Simulator visual translation:

- Use low-poly silhouettes for the tower, tools, clients, monsters, ingredients, and magical machinery.
- Keep spell effects graphic and strange rather than lush, smooth, or high fantasy.
- Favor foggy rooms, hard pools of practical light, crushed shadows, and limited texture resolution.
- Make magical equipment look like bargain-bin industrial hardware: brass meters, cheap switches, cracked lenses, taped labels, stained parchment, bad wiring, and unsafe containment jars.
- Let animation remain slightly stiff or awkward where that supports comedy and uncanniness.
- Use analog-feeling interfaces: ledgers, stamped forms, scrying mirrors, wax seals, receipt printers, arcane meters, and cursed terminals.

Secondary gameplay patterns worth considering:

- A simple quota can create risk-reward pressure, but it is not required.
- Carry limits can create physical comedy and tradeoffs if the game has retrieval or delivery work.
- Equipment purchases work best when they solve concrete field problems.
- Proximity voice and physical comedy can make failure entertaining in co-op.

Optional Wizard Simulator gameplay translation:

- If using contracts, replace scrap quota with arcane contract revenue, guild dues, rent, reputation, or debt.
- If using field jobs, replace moons with cursed locations, client estates, ruins, and wizard errands.
- If using a job terminal, replace the ship computer with a tower desk, scrying mirror, spell ledger, or cursed employer interface.
- If using retrieval, replace scrap with ingredients, artifacts, bound spirits, cursed furniture, unpaid invoices, and volatile spell components.

### R.E.P.O.

Core reference: [R.E.P.O.](https://en.wikipedia.org/wiki/R.E.P.O.)

Useful patterns:

- Fragile valuables add more drama than plain item collection.
- Physics handling creates comedy because players can ruin their own profits.
- Extraction remains simple, but the moment-to-moment handling is messy.
- Co-op chaos is strongest when the task is understandable but execution is unreliable.

Wizard Simulator translation:

- Magical items should be unstable, breakable, noisy, sentient, cursed, or reactive.
- A player carrying a bottled ghost, enchanted chandelier, dragon egg, or cursed mirror should feel physically responsible for it.
- Damaged goods should still be usable, but with reduced payment or added consequences.

### PowerWash Simulator

Core reference: [PowerWash Simulator](https://en.wikipedia.org/wiki/PowerWash_Simulator)

Useful patterns:

- The whole game can be built around one tactile verb when progress is visible and satisfying.
- Object-level progress bars and highlighting reduce frustration.
- Career jobs create structure without needing heavy story.
- Tool upgrades matter because they speed up or improve a familiar task.
- Co-op works because players can divide obvious labor.

Wizard Simulator translation:

- Wizard chores need satisfying visible transformation.
- Examples: cleanse corruption, inscribe sigils, stabilize portals, brew potions, sort cursed books, repair wards, banish infestations, polish enchanted relics, and transmute materials.
- Each task needs clear before and after states.
- Magical residue, unstable glyphs, floating dust, and corruption stains can become the equivalent of dirt.

### House Flipper

Core reference: [House Flipper](https://en.wikipedia.org/wiki/House_Flipper)

Useful patterns:

- Jobs provide money, money unlocks tools, tools unlock better jobs.
- Client requirements give direction while still leaving room for player expression.
- Upgrades reduce friction on repeated tasks.
- Renovation is satisfying because the player imposes order on a messy space.

Wizard Simulator translation:

- The tower can be a persistent home base that players repair, customize, and upgrade.
- Contracts can include client tastes and magical restrictions.
- Example clients: nobles, goblin accountants, swamp witches, haunted villages, universities, cults, and unreasonable royalty.
- Jobs can pay differently based on correctness, damage, speed, style, and collateral effects.

### Potion Craft

Core reference: [Potion Craft](https://en.wikipedia.org/wiki/Potion_Craft)

Useful patterns:

- Crafting feels good when ingredients have spatial, tactile, or procedural meaning instead of being menu recipes.
- Customers create a daily loop and a reason to make different products.
- Reputation matters because bad service changes future demand.
- Discovery is driven by experimentation.

Wizard Simulator translation:

- Spellcraft should involve physical preparation rather than only selecting spells from a list.
- Ingredients, gestures, runes, timing, spoken words, and focus tools can shape spell output.
- Customers should request outcomes, not exact recipes.
- The player should discover unstable but useful variants.

### Job Simulator

Core reference: [Job Simulator](https://en.wikipedia.org/wiki/Job_Simulator)

Useful patterns:

- Mundane task parody works because the game lets players interact with many objects.
- Comedy comes from approximating work badly, not from constant scripted jokes.
- Players enjoy doing tasks incorrectly when the simulation reacts.

Wizard Simulator translation:

- The game should let players misuse tools.
- Every important prop should have at least one funny wrong use.
- Wizard bureaucracy, forms, rituals, customer service, and workplace safety can make the fantasy premise sharper.

## Simulator Design Principles

### 1. The Job Must Be Immediately Understandable

The player should be able to describe the job in one sentence.

Examples:

- Run a barely functional wizard practice and survive the consequences of your own magic.
- Keep your wizard tower solvent by performing dangerous spellwork.
- Enter cursed sites, retrieve unstable magical assets, and get paid before they kill you.

### 2. The Moment-To-Moment Work Must Be Tactile

The game needs hands-on verbs that feel physical in 3D.

Strong verbs:

- Grab
- Pour
- Grind
- Inscribe
- Aim
- Chant
- Bind
- Drag
- Seal
- Cleanse
- Carry
- Balance
- Repair
- Contain

Weak verbs:

- Open menu
- Select recipe
- Wait for timer
- Click to complete

### 3. Progress Must Be Visible

Simulator games become sticky when players can see work becoming done.

Wizard Simulator should make progress visual:

- Corruption fades from walls.
- Runes lock into place.
- Potions change color, texture, smoke, and sound.
- Portals stabilize from noisy tearing shapes into clean circles.
- Haunted rooms calm down as objects stop shaking.
- Cursed artifacts become less aggressive as bindings tighten.

### 4. The Economy Should Create Pressure

The player needs a reason to take risk.

Possible pressure systems:

- Weekly guild dues.
- Rent owed on the tower.
- A magical licensing board inspection.
- Debt to a demon.
- A royal contract with escalating penalties.
- Reputation decay if too many clients are harmed, transformed, cursed, or ignored.

### 5. Failure Should Be Funny, Expensive, and Recoverable

The game should not only punish failure with death.
Failure should create stories.

Examples:

- A spell misfires and turns the client's furniture hostile.
- A potion works, but also gives the customer antlers.
- A cursed mirror breaks and duplicates a player.
- An unpaid spirit follows the party home.
- The guild fines the team for unsafe ritual practice.

### 6. Upgrades Should Change How Players Work

Avoid upgrades that are only percentage increases.

Better upgrades:

- Bigger ingredient satchel.
- Rune projector that previews unstable glyph paths.
- Ward hammer that pins possessed objects.
- Familiar courier that carries one small item but may panic.
- Portable containment circle.
- Better broom that cleans magical residue faster.
- Scrying mirror that reveals contract hazards.
- Tower rooms that unlock new preparation stations.

### 7. Multiplayer Should Create Role Pressure

If the game supports co-op, each player should have useful responsibilities without hard classes.

Possible roles:

- Ritual lead reads the contract and sequences the spell.
- Porter carries unstable components.
- Warden keeps threats contained.
- Alchemist prepares ingredients.
- Scout searches the site and marks hazards.
- Clerk negotiates payment and manages guild requirements.

## Proposed Core Loop

1. Wake up in the wizard tower and review the day's requests.
2. Choose between peasant jobs, tower chores, research, experiments, and royal commissions.
3. Search the library, prepare ingredients, brew potions, and craft or modify spells.
4. Perform the job in the tower, at the tower gate, in a nearby village, or at a larger royal site.
5. Use improvised magical tools while managing hazards, side effects, client demands, and limited resources.
6. Get paid, gain reputation, recover ingredients, discover knowledge, or create new problems.
7. Return to the tower to repair damage, expand rooms, catalog discoveries, and improve equipment.
8. Repeat with harder jobs, stranger clients, deeper research, and more unstable magic.

## Run Structure

### Short Loop: 5-15 Minutes

A single wizard task.
The player solves a contained magical problem with a clear objective and a few complications.

Examples:

- Remove a ghost from a manor without damaging heirlooms.
- Brew and deliver a potion before it spoils.
- Cleanse a cursed well while villagers interrupt.
- Retrieve an enchanted object from a ruin.
- Identify the correct spell from a library clue and cast it safely.
- Stabilize a tower room after an experiment goes wrong.

### Medium Loop: 30-60 Minutes

A work cycle.
The player completes several jobs, chores, experiments, or client requests before the next obligation arrives.
The player decides whether to take safe low-paying peasant work, risky royal work, or spend time improving the tower.

### Long Loop: 5-20 Hours

Tower and career progression.
The player unlocks new tower rooms, spell schools, library wings, clients, regions, job types, and deeper magical systems.

## Job Types

### Peasant Request

A local villager brings a practical magical problem.
These jobs should be smaller, weirder, and more personal than royal commissions.

Examples:

- A cow keeps levitating and will not come down.
- A field is growing teeth instead of wheat.
- A child has been duplicated by a mirror.
- A house is haunted by a previous owner's unpaid chores.
- A well whispers legal advice and the village wants it stopped.

Peasant work should teach systems, build reputation, and supply small payments or ingredients.
It should also create the game's strongest comedy because the stakes are human-scale and absurd.

### Royal Commission

The king, queen, court, or royal bureaucracy sends a larger job.
These jobs should pay better, unlock progression, and apply more pressure.

Examples:

- Cure the prince without admitting he was cursed by the royal chef.
- Cleanse a battlefield before a visiting ambassador arrives.
- Repair a portal in the castle basement.
- Investigate why the royal treasury is screaming.
- Prepare a potion for a coronation ritual with no visible side effects.

Royal work should feel more dangerous because mistakes affect reputation, access, money, and political pressure.

### Retrieval

Enter a dangerous place and bring back a magical item.
The item may resist, leak, whisper, burn, float, multiply, or attract threats.

### Cleansing

Remove magical corruption from a location.
This is the PowerWash Simulator style contract.
It needs strong visual progress and satisfying tools.

### Ritual Service

Perform a multi-step ritual under time pressure.
Players must arrange objects, draw symbols, speak incantations, and react to mistakes.

### Potion Order

Craft a potion for a client need.
The request should describe the desired result, not the recipe.

### Exorcism

Identify and remove a spirit from a person, object, or building.
Wrong actions make the haunting worse but more interesting.

### Arcane Repair

Fix magical infrastructure.
Examples include portals, wards, golems, clocks, sentient doors, weather engines, and cursed plumbing.

### Consultation

Diagnose a weird client problem.
This can lean into comedy and deduction.

## Spell Library

The library should be one of the main reasons the tower feels like a wizard tower.
It should not only be decoration.

Useful functions:

- Stores known spells, ingredients, creatures, curses, and client histories.
- Lets the player research new spell components from books, scrolls, marginalia, diagrams, and failed experiments.
- Acts as a clue system for jobs that require diagnosis.
- Expands over time with new wings, shelves, forbidden sections, indexes, and cursed books.
- Creates light friction because knowledge is physical: the player has to find, carry, read, bookmark, copy, or misread sources.

The library can turn spellcasting into investigation.
For example, a peasant says their sheep are turning invisible every full moon.
The player checks books on lunar curses, animal enchantments, and invisibility side effects, then chooses what to brew or cast.

## Spellcraft

Spells should feel crafted, not simply unlocked.
The player can discover and combine spell parts to create specific effects.

Possible spell components:

- Intent: bind, reveal, cleanse, heat, cool, grow, shrink, silence, mend, repel.
- Form: ray, circle, charm, powder, sigil, potion, spoken word, thrown object.
- Target: creature, object, room, liquid, crop, spirit, machine, door.
- Modifier: gentle, violent, temporary, permanent, cheap, unstable, quiet, fast.

This creates design space for jobs where the player has the right general magic but must adapt it.
For example, "cleanse object" may work on a cursed chair, but "cleanse room" is needed for a haunted kitchen.

## Potion Crafting

Potion crafting should be tactile and useful across the whole game.
It should support client orders, field preparation, experimentation, and mistakes.

Potion interactions:

- Grind ingredients.
- Heat, cool, stir, distill, bottle, label, and test.
- Add unstable reagents in specific orders.
- Watch color, smoke, viscosity, bubbles, smell text, and sound change as feedback.
- Use the library to infer recipes rather than always following exact instructions.

Potion outcomes should have quality bands, not only pass or fail.
A potion can be correct but weak, potent but volatile, effective but embarrassing, or profitable but morally questionable.

## Visual Direction

The target is not clean fantasy.
It should feel like bargain-bin occult work viewed through an old camera.

Guidelines:

- Low-poly silhouettes with simple, readable shapes.
- Chunky props with exaggerated proportions.
- Limited texture resolution.
- Dithered shadows, fog, and crushed darkness.
- Slightly awkward animations that read as intentional.
- Analog UI: ledgers, stamped forms, receipt printers, scrying mirrors, wax seals, brass meters, and cursed terminals.
- Warm practical lights against cold foggy darkness.
- Industrial fantasy materials: soot, brass, old wood, wax, iron, stained glass, mold, parchment, and cheap plastic magical equipment.

Avoid:

- Clean high fantasy polish.
- Overly pretty spell effects.
- Generic wizard robes and smooth glowing crystals without grime.
- Too much purple.
- UI that feels like a modern MMO.

## Tone

Wizard Simulator should sit between:

- Workplace comedy.
- Occult horror.
- Physical slapstick.
- Bureaucratic fantasy.
- Dangerous amateur magic.

The player should often think, "This is a stupid way to do magic, but it technically works."

## Design Pillars

### Wizard Work Is Physical

Magic is not just aiming projectiles.
It is carrying unstable objects, drawing crooked circles, reading cursed instructions, preparing bad ingredients, and cleaning up consequences.

### The Tower Is The Center

The tower is not a menu hub.
It is the main character of the simulation: a library, laboratory, workshop, home, storage problem, and danger source.

### Jobs Create Risk-Reward Decisions

Players should always understand why a job pays well or why it matters.
If the reward is high, the danger, complexity, distance, fragility, social pressure, or moral cost should be visible.

### Failure Creates Better Stories

The game should turn mistakes into complications before ending the run.
The funniest version of failure is one the team has to live with for five more minutes.

### Knowledge Is Gameplay

Researching the library, interpreting clues, choosing ingredients, and adapting spell components should be as important as casting.
The player should often feel clever because they found the right magical explanation, not because they clicked the strongest spell.

### Magic Should Be Legible But Unstable

Players need to learn cause and effect.
The comedy comes from unstable systems interacting, not from random nonsense.

### Multiplayer Is A Future Multiplier

The game should be designed so multiplayer would be excellent later.
Roles like researcher, brewer, caster, porter, and containment assistant should emerge naturally.
The solo MVP should avoid networking, but the systems should not assume only one person can ever interact with the tower.

## Initial MVP

The first prototype should prove the job loop, not the whole fantasy.

Recommended MVP:

- First-person controller.
- One small tower hub.
- One readable library shelf with three usable books.
- One potion station.
- One spellcraft station or spell ledger.
- One request board or tower door where peasants ask for help.
- One nearby job site, such as a cottage, well, field, or tiny chapel.
- One peasant request and one larger royal commission.
- Three tools: wand, chalk, containment jar.
- Three hazards: animated object, unstable rune, roaming spirit.
- One concrete obligation, such as rent, guild inspection, reputation target, or royal deadline.
- Basic payout, reputation, and tower upgrade screen.

Success criteria:

- The player can understand the job without tutorial text.
- The work has satisfying physical interactions.
- The player can make costly mistakes.
- The visual style already feels distinct from clean fantasy.
- The library and potion/spell preparation matter to the outcome.
- A 10-minute run produces at least one funny or tense story.

## Open Design Questions

- Is this primarily solo, co-op, or solo-first with co-op later?
- Is combat intentionally clumsy, or mostly avoided?
- Should spellcasting be gesture/ritual based, ingredient based, or tool based?
- Is the player an independent wizard, an apprentice crew, or employees of a magical company?
- Does the game have a fail-forward campaign, hard financial collapse, reputation collapse, or another pressure model?
- How scary should it be compared with how silly it is?
- How deep should the library research system be before it becomes tedious?
- Are royal jobs rare milestone events or part of the normal job list?

## Recommended Next Step

Create a full `GAME_DESIGN.md` with these sections:

- One-sentence pitch.
- Target player experience.
- Pillars.
- Core loop.
- Contract system.
- Spell and tool systems.
- Progression.
- Economy and failure.
- Visual style guide.
- MVP scope.
- Prototype milestones.
