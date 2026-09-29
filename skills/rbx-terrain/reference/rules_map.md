# User verdicts -> kit default / suite check

Every line of feedback.md, in order. D = kit default (happens without the recipe asking), C = check in
`scripts/tests/run_all.sh` (or K.check on every build), R = review-only (cannot be a number; why given).
Newest verdict wins; superseded lines say by what.

| Round | Rule | How it is enforced |
|---|---|---|
| R1 | purely terrain, props keep pads | D K.protect pads; C K.check "props grounded" on every build. Lab sites never contain parts (lab rule), so no lab test |
| R1 | stay inside human boundaries | D K.mask locks Basalt/Rock/air-under/water/steep; C K.check "unmasked columns changed: 0" |
| R1 | no loops | R: the kit has no loop piece; a recipe could still draw a closed lane. movement.md "Never" |
| R1 | bulk edits <= 2048 | D eachTile slabs <= 2048 studs, <= 4,194,304 voxels |
| R2 | no skulls | R: removed from recipes.md; the SDF primitives stay (bores, bridges need them) |
| R2 | no thin tube arches | R: removed from recipes.md; K.archBridge (land bridge) replaces it; C test bridge |
| R2 | bowls are depressions, raised rings unreachable | D K.ring widens w so the rim is <= 20; C tests ring, bowl |
| R2 | pieces rise out of slopes with a path in | R: layout. Test bore/caves show the pattern (route leads into the portal) |
| R2 | seams at cliff foot smoothed | D blur never averages locked cells, guard border cones; C test cliff seam/blend |
| R2 | more up-down, flat is failure | D hill field + rolling defaults; C test hillfield flat <= 8, relief >= 13.6 |
| R2 | trees placed by analysis | D K.placeTrees (flat spots 60-85 apart); R in the lab (no parts allowed at far sites) |
| R3 | chunky masses | C test hillfield hill h p50 30-50, relief >= 13.6 |
| R3 | paths >= 2x | C test paths lane width >= 96 |
| R3 | no web of thin lines, no short noise | D rolling shortest octave 110 studs; R: layout count of pieces |
| R3 | long blends | D pad blend scales with height, lane/ramp banks widen with drop, mask feather; C edge blend <= 25 every test |
| Lesson | metrics pass on rejected builds | R: process. Render (scripts/render) and user sign-off on one piece first |
| R4 | size from the ball | C bores clear >= 48 (tests bore, caves, bridge), lanes >= 96 |
| R4 | zero seam into untouched ground | C edge seam 0 on every test |
| R4 | a lot in one area | C test hillfield >= 5 hills in 600 x 600 core; R: overall composition |
| R5 | no sheer walls in free roam | D climb guard 22; C steep patches (>= 4 cells > 25 deg) = 0 outside declared faces |
| R5 | bridge = land ridge with underpass | superseded by R13 bridges: K.archBridge solid deck; C test bridge |
| R5 | huge = wide, h <= 80, flank <= 20 | D K.mound WARN > 20.5; C test mound |
| R5 | Basalt only in bores, open ground grass | D rock paint only >= 35 deg; C K.check blade materials >= 70 (Slate counts since R14; pay share printed), test cliff (< 25 deg cells rock <= 2%) |
| R5 | no table-tops, no ledges | D K.table errors without allowBanned; C test pad |
| R5 | exits gentle, nothing steep at rims | D bowl lip moved to 1.1r; C test bowl every exit <= 25 |
| R5 | 5+ bowls, features every ~250 | R: layout; the hill field covers the "every ~250" part |
| R6 | no hole/spike lattice on steep faces | D normal-distance write; C test cliff walk-up holes 0, test paths crest 2nd difference <= 1 |
| R6 | Basalt lining jagged | superseded by R7 (Rock/Mud/Ground mix) |
| R6 | no creases | D rolling damps multiply, smax union, guard envelopes + 4 blur/clamp passes; C analyzer crease detector (slope break over 8 studs minus half over 16: smooth curvature ~0, a crease of a deg scores a/2), 0 crease patches in the core of mound, bowl, ring, pad, rolling, hillfield, paint, trough. Remaining creases sit where a piece reaches into the edge feather (border cone clamp) and on wall-ride quarter-pipes (declared steep) |
| R6 | no specks | D despeck (lone cells take the 8-neighbour majority); C test paint specks 0 |
| R6 | bowls easier to leave | D K.bowl WARN planned wall > 13.8 (build adds 1.0-1.4); C test bowl walls <= 15 |
| R7 | every approach <= 25 incl. notch sides | D climb guard (dive portals are not exempt any more); C tests mound, hillfield, bore steepOpen 0, cliff TOPS |
| R7 + R5 | portal = true arch, notch sides <= 25, no sheer walls | partial. The arch itself passes (widths within 8 of a true arch). The approach cannot satisfy both rules in a heightfield: rising ~60 studs to roof height needs a steep headwall (dive `portalKeep = true`: 2 of 32 host-hill approaches at 27-31 deg next to the headwall) or a 22 deg ramp that the bore trenches with vertical walls (default: 108-stud open trench, walls up to 55 before the roof starts). Measured in test bore (INFO line). User call; cliff caves (test caves) avoid it because the cliff face is the headwall |
| R7 | true arches | D K.slot arch; C test bore arch widths within 8 studs of a true arch |
| R7 | lining mix Rock/Mud/Ground | D K.lining; C test bore each >= 10% |
| R8 | no bulk rebuilds, chunk by chunk | D chunk mode; C tests chunk, bridge (seam 0.00, pass 2 = 0 columns, restore exact) |
| R9 | h 10-22 | superseded by R10 (30-50) |
| R9 | mound field + lit shading | superseded by R13/R14 (sun paint) |
| R10 | bigger hills and dips | C test hillfield h 30-50; test bowl depth |
| R10 | no loop road | R: layout |
| R10 | deliberate 1:1 layout | R: layout (plan first) |
| R10 | props allowed in big test | n/a (props) |
| R11 | never Cobblestone | D no rule paints it; C test paint banned 0 |
| R12 | never Pavement, stone = Rock + Basalt | D rock paint K.stone; C tests cliff, paint |
| R12 | cliffs span the full edge | D K.cliff tapers only its ends; C test cliff coverage |
| R12 | bowls r 170-230, depth r/6.5, dark floor, Limestone lip | C test bowl size; paint via K.bowl floorMat/rimMat (recipe) |
| R13 | no polka dots | D sun paint default, no per-mound crest paint; C test paint order |
| R13 | more hills, bowl-like, smooth | C test hillfield |
| R13 | caves join through deep dips | C test caves (dip >= 30, clear >= 48) |
| R13 | finish every requested piece | R: process |
| R14 | 4-tone sun highlight | D sun default (sunHi 0.12, Slate lit, Limestone brightest); C test paint order + Limestone 10-20% |
| R14 | faster output | process: fast loop + `run.sh plan` (no writes); suite 21 suites in ~250 s |
