#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"; S="$DIR/.."
R="node $HOME/.claude/skills/rbx/rbx.mjs"; SA=${STUDIO:+--studio $STUDIO}
OUT=${LABOUT:-./lab_out}; mkdir -p "$OUT"
REC=${1:-$DIR/t_freeroam.lua}; SITE=${2:-16}; NAME=$(basename "$REC" .lua)
kr() { { echo "local RUN_MODE, CHUNK_INDEX, VARIANT = '$1', $2, ''"; cat "$S/kit.lua" "$DIR/lab.lua"; cat; } | $R lua - $SA "${@:3}"; }
fail=0
echo "LAB.prep($SITE) return 'prepped'" | kr lab 0 | tail -1
for i in 1 2 3 4; do kr plan $i --out "$OUT/${NAME}_plan_$i.grab" < "$REC" > /dev/null; grep -q '^#grab' "$OUT/${NAME}_plan_$i.grab" || { echo "FAIL plan $i: no grab"; head -c 300 "$OUT/${NAME}_plan_$i.grab"; fail=1; }; done
node "$S/analyze/merge.mjs" "$OUT/${NAME}_plan.grab" "$OUT"/${NAME}_plan_[1-4].grab
sites=$(echo "local o = {} return tostring(LAB.solid($SITE))" | kr lab 0 | tail -1)
kr chunk 0 < "$REC" | tail -1
for i in 1 2 3 4; do kr chunk $i < "$REC" > /dev/null; done
read -r X0 Z0 NX NZ ST < <(head -1 "$OUT/${NAME}_plan.grab" | cut -d' ' -f2-)
STUDIO=$STUDIO bash "$S/analyze/grab.sh" "$OUT/${NAME}_built.grab" $X0 $Z0 $((X0 + (NX - 1) * ST)) $((Z0 + (NZ - 1) * ST)) $ST > /dev/null
node "$DIR/cmp.mjs" "$OUT/${NAME}_plan.grab" "$OUT/${NAME}_built.grab" 0 0 2.5 45 | sed 's/chunk seam: whole vs 4 chunks/plan vs built surface/' | tee "$OUT/${NAME}_plancmp.txt"; grep -q '^PASS' "$OUT/${NAME}_plancmp.txt" || fail=1
node "$S/analyze/analyze.mjs" "$OUT/${NAME}_plan.grab" plan > "$OUT/${NAME}_plan.txt"; node "$S/analyze/analyze.mjs" "$OUT/${NAME}_built.grab" built > "$OUT/${NAME}_built.txt"
node "$S/analyze/analyze.mjs" --compare "$OUT/${NAME}_plan.json" "$OUT/${NAME}_built.json"
V='^  (PASS|FAIL) (hills with|bowls with|basin walls|steep patches|ground reachable|flat|relief|highlight|banned)[^:]*'
diff <(grep -oE "$V" "$OUT/${NAME}_plan.txt") <(grep -oE "$V" "$OUT/${NAME}_built.txt") > /dev/null && echo "PASS plan verdict = built verdict on shape and climb targets (creases and isolated cells depend on voxel mesh noise, reported only)" || { echo "FAIL plan verdict differs from built:"; diff <(grep -E "$V" "$OUT/${NAME}_plan.txt") <(grep -E "$V" "$OUT/${NAME}_built.txt"); fail=1; }
grep -E '^  (PASS|FAIL) (crease|isolated)' "$OUT/${NAME}_plan.txt" | sed -E 's/^  (PASS|FAIL) /  INFO plan: /'; grep -E '^  (PASS|FAIL) (crease|isolated)' "$OUT/${NAME}_built.txt" | sed -E 's/^  (PASS|FAIL) /  INFO built: /'
echo "$(echo "return (LAB.erase($SITE))" | kr lab 0 | tail -1)"
exit $fail
