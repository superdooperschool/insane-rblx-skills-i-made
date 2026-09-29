#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"; S="$DIR/.."
R="node $HOME/.claude/skills/rbx/rbx.mjs"; SA=${STUDIO:+--studio $STUDIO}
OUT=${LABOUT:-./lab_out}; mkdir -p "$OUT"
kr() { { echo "local RUN_MODE, CHUNK_INDEX, VARIANT = '$1', $2, '$VARIANT'"; cat "$S/kit.lua" "$DIR/lab.lua"; cat; } | $R lua - $SA; }
REC=${1:-$DIR/t_chunk.lua}; SITE=${2:-7}; NAME=$(basename "$REC" .lua)
BSIZE=$(grep -oE 'LAB.box\([0-9]+, "[a-z]+", [0-9]+\)' "$REC" | head -1 | grep -oE '[0-9]+\)$' | tr -d ')'); BSIZE=${BSIZE:-900}
fail=0
echo "LAB.prep($SITE) return 'prepped'" | kr lab 0 | tail -1
t0=$(date +%s%N)
kr build 0 < "$REC" > "$OUT/${NAME}_whole.txt"; t1=$(date +%s%N)
grep -E '^(PASS|FAIL|climb|WARN)' "$OUT/${NAME}_whole.txt" | cut -c1-160 | sed 's/^/  whole: /'
read -r cx cz < <(echo "local c = LAB.site($SITE) return string.format('%d %d', c.X, c.Z)" | kr lab 0 | tail -1)
STUDIO=$STUDIO bash "$S/analyze/grab.sh" "$OUT/${NAME}_whole.grab" $((cx-508)) $((cz-508)) $((cx+508)) $((cz+508)) 4 >/dev/null
r=$(echo "local G = K.grid(LAB.box($SITE, '${NAME#t_}', $BSIZE)) K.restore(G) local d, t = K.compareBaseline(G) return (#d == 0 and 'PASS' or 'FAIL') .. ' restore round trip: ' .. #d .. '/' .. t .. ' tiles differ from baseline'" | kr lab 0 | tail -1); echo "$r"; [[ $r == PASS* ]] || fail=1
echo "$(kr chunk 0 < "$REC" | tail -1)"
t2=$(date +%s%N)
for i in 1 2 3 4; do kr chunk $i < "$REC" > "$OUT/${NAME}_$i.txt"; grep -E '^(PASS|FAIL|chunk|phases)' "$OUT/${NAME}_$i.txt" | cut -c1-200 | sed "s/^/  c$i: /"; done
t3=$(date +%s%N)
kr check 0 < "$REC" | grep -E '^(PASS|FAIL)' | sed 's/^/  after chunks: /' | tee "$OUT/${NAME}_check.txt"; grep -q '^  after chunks: FAIL' "$OUT/${NAME}_check.txt" && fail=1
STUDIO=$STUDIO bash "$S/analyze/grab.sh" "$OUT/${NAME}_split.grab" $((cx-508)) $((cz-508)) $((cx+508)) $((cz+508)) 4 >/dev/null
node "$DIR/cmp.mjs" "$OUT/${NAME}_whole.grab" "$OUT/${NAME}_split.grab" $cx $cz | tee "$OUT/${NAME}_seam.txt"; grep -q '^PASS' "$OUT/${NAME}_seam.txt" || fail=1
if [ -n "$GRADE" ]; then cp "$OUT/${NAME}_split.grab" "$OUT/${NAME#t_}.grab"; node "$S/analyze/analyze.mjs" "$OUT/${NAME#t_}.grab" "${NAME#t_}" > "$OUT/${NAME#t_}.txt"; node "$DIR/grade.mjs" "${NAME#t_}" "$OUT" $cx $cz | tee "$OUT/${NAME}_grade.txt"; grep -q '^FAIL' "$OUT/${NAME}_grade.txt" && fail=1; fi
idem=0; for i in 1 2 3 4; do kr chunk $i < "$REC" > "$OUT/${NAME}_again_$i.txt"; n=$(grep -oE "columns rewritten: [0-9]+" "$OUT/${NAME}_again_$i.txt" | grep -oE "[0-9]+$"); idem=$((idem + ${n:-999})); done
[ $idem -eq 0 ] && echo "PASS chunk idempotence: second pass rewrote 0 heightfield columns ($(grep -ohE '\+[0-9]+ under 3D' "$OUT"/${NAME}_again_*.txt | grep -oE '[0-9]+' | paste -sd+ | bc 2>/dev/null || grep -ohE '\+[0-9]+ under 3D' "$OUT"/${NAME}_again_*.txt | tr '
' ' ')re-applied under 3D pieces)" || { echo "FAIL chunk idempotence: second pass rewrote $idem heightfield columns"; fail=1; }
STUDIO=$STUDIO bash "$S/analyze/grab.sh" "$OUT/${NAME}_again.grab" $((cx-508)) $((cz-508)) $((cx+508)) $((cz+508)) 4 >/dev/null
node "$DIR/cmp.mjs" "$OUT/${NAME}_split.grab" "$OUT/${NAME}_again.grab" $cx $cz 0.05 | sed 's/chunk seam: whole vs 4 chunks/chunk idempotence surface: pass 1 vs pass 2/' | tee "$OUT/${NAME}_idem.txt"; grep -q '^PASS' "$OUT/${NAME}_idem.txt" || fail=1
echo "timing whole build $(( (t1 - t0) / 1000000 )) ms, 4 chunks $(( (t3 - t2) / 1000000 )) ms (incl. rbx round trips)"
echo "return (LAB.erase($SITE))" | kr lab 0 | tail -1
exit $fail
