#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"; S="$DIR/.."
R="node $HOME/.claude/skills/rbx/rbx.mjs"; SA=${STUDIO:+--studio $STUDIO}
OUT=${LABOUT:-./lab_out}; mkdir -p "$OUT"
t=$1; mode=${2:-full}
site=$(grep -oE 'SITE = [0-9]+' "$DIR/t_$t.lua" | grep -oE '[0-9]+$')
lab() { { echo "local RUN_MODE, VARIANT = 'lab', '$VARIANT'"; cat "$S/kit.lua" "$DIR/lab.lua"; cat; } | $R lua - $SA "$@"; }
if [ "$mode" != "erase" ]; then
  lab --out "$OUT/$t.build.txt" < "$DIR/t_$t.lua" >/dev/null
  grep -E '^(ERROR|PASS|FAIL|WARN|INFO|timing|columns|chunk|phases|compose phases|climb|ring|field|hills|trough|berm)' "$OUT/$t.build.txt" | cut -c1-240
  grep -q '^ERROR' "$OUT/$t.build.txt" && { echo "FAIL $t: build error (site left as is)"; grep -o 'AssistantCommand:[0-9]*: .*' "$OUT/$t.build.txt" | head -c 400; exit 2; }
  read -r cx cz < <(echo "local c = LAB.site($site) return string.format('%d %d', c.X, c.Z)" | lab | tail -1)
  STUDIO=$STUDIO bash "$S/analyze/grab.sh" "$OUT/$t.grab" $((cx-508)) $((cz-508)) $((cx+508)) $((cz+508)) 4 >/dev/null || exit 2
  node "$S/analyze/analyze.mjs" "$OUT/$t.grab" "$t" > "$OUT/$t.txt"
  node "$DIR/grade.mjs" "$t" "$OUT" $cx $cz
fi
[ "$mode" = "keep" ] || echo "return (LAB.erase($site))" | lab | tail -1
