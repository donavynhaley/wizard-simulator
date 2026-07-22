# Case: The Bitter Vintage

A backlog case authored in the game-bible.md section 3 format.
Not part of the vertical slice; it exists to pressure-test the pipeline and to bank the design.
Vocabulary it introduces (the gall quality, the smoke reading, the tithe rule) stays provisional until the case enters production, then moves to the canon sheet.

**Author and motive** (rule 8): Maren, the old wizard - benign neglect.
He built the tithe-stone and emptied it every first frost; he is gone and nobody knew the chore existed.

## Hook

Bram the vintner's whole batch has turned bitter in the barrel.
He blames the new oak barrels he bought this spring, and half-suspects his rival across the fence, who has not stopped smiling since the ruin.
The season was fair and the grapes looked perfect.

## Subjects

`wine` (this year's batch), `barrels` (the new oak), `vines` (the old rows), `tithe_stone` (a buried wizard-cut vessel), `rival` (the neighboring grower), `rival_charm` (a charm on his fence stakes).

## Links

- `vines_to_stone`: faint threads from every old row converging underground at the field's corner marker.
- `charm_to_rival_vines`: the fence charm's thread runs into the rival's OWN rows.

## Facts

| id | subject | slot | reveal | prereqs | payload | journal text |
| --- | --- | --- | --- | --- | --- | --- |
| testimony_bitter | wine | history | testimony | - | - | Bram swears the wine turned in the barrel; the new oak gets his blame, the rival his darker guesses. |
| wine_nature | wine | nature | bench_test | testimony_bitter | water, gall | Burned, the sample gives oily black smoke: the wine is thick with gall, and nothing this year drew it off. |
| barrels_clean | barrels | nature | bench_test | testimony_bitter | - | The oak shavings burn clean and sweet. The barrels are honest. |
| rival_grudge | rival | name | testimony | testimony_bitter | - | The rival crows over Bram's ruin and hides nothing. Loud, spiteful, and proud of his own vines. |
| charm_working | rival_charm | working | rune_reading | rival_grudge | bind, seal | A Bind on his own stakes held by a Seal: a blessing fixed to his own rows. Petty, legal, and innocent of Bram's wine. |
| vine_nature | vines | nature | bench_test | wine_nature | earth, gall | A root cutting runs earth-natured, sap heavy with gall. The bitterness rides in from the field, not the cellar. |
| vine_threads | vines | links | sight_thread | vine_nature | vines_to_stone | Threads from every old row converge underground at the corner marker. Something has been drinking from these vines. |
| stone_unearthed | tithe_stone | name | observation | vine_threads | - | Beneath the marker: a sealed stone vessel, wizard-cut, older than Bram's tenure on this land. |
| stone_working | tithe_stone | working | rune_reading | stone_unearthed | bind, seal | A sustained Bind held by a Seal: the vessel tithes gall from the vines year after year. |
| stone_full | tithe_stone | nature | observation | stone_working | gall | In Sight the vessel's glyph blazes full to the brim. It can drink no more, and so it drinks nothing. |
| tithe_ledger | tithe_stone | history | library | stone_unearthed | - | Maren's ledger: "Emptied the vintner's tithe-stone at first frost, as every year." There is no entry since he left. |

## Resolutions

| id | requires | outcome |
| --- | --- | --- |
| empty_the_tithe | stone_working, stone_full | Use Sight to move the stored gall into a flask and re-Seal the stone; the tithe resumes and this vintage sweetens late. You now own the first-frost chore - and a bottle of gall. |
| sever_the_tithe | stone_working, vine_threads | Sever the converging threads; the vines keep their gall forever. The wine turns dark and rustic - some will love it, Bram must relearn his craft, and no one tends a tithe again. |
| sweeten_the_batch | wine_nature | Brew a clarifying draught for this vintage only. Bram pays gladly; the stone still sits full underground, and next season is a consequence case. |

Diligence texture (rule 9): accusing the rival before reading `charm_working` costs Village Trust even though he is loathsome; the exoneration facts are what make the accusation land or misfire.

## What the case pays

Coin from Bram; the bottled gall (a bitter reagent: fool's ink base, clarifying-draught antagonist); the tithe as a recurring standing obligation if emptied (steady small pay, calendar pressure); the canon rule that sustained workings fill their vessels.

## What this case demands

Already demanded by the vertical slice (game-bible.md section 6): journal facts and Sight states, bench test verb, testimony gating, sight threads, rune reading of world workings, sample carrying.
New demands unique to this case:

- **Sever behavior**: the glyph recognizes today, but cutting an aimed thread does nothing yet.
- **Quality tags**: gall is the first non-element nature; fact payloads and flame readings must accept qualities alongside the four elements.
- **Many-to-one threads**: the converging rows-to-stone visual (thread rendering is a slice demand; the convergence is this case's flourish).
- Vineyard set, two NPCs (Bram, the rival), the tithe-stone prop, and Maren's ledger as a library book.
