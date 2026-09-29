#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
out=$1; X0=$2; Z0=$3; X1=$4; Z1=$5; S=${6:-4}
R="node $HOME/.claude/skills/rbx/rbx.mjs"; SA=${STUDIO:+--studio $STUDIO}
NX=$(( (X1 - X0) / S + 1 )); NZ=$(( (Z1 - Z0) / S + 1 ))
per=$(( 90000 / (NX * 5 + 1) )); [ $per -lt 1 ] && { echo "row too wide: step up"; exit 2; }
tmp="$out.part"
echo "#grab $X0 $Z0 $NX $NZ $S" > "$out"
for ((a=0; a<NZ; a+=per)); do b=$((a+per-1)); [ $b -ge $NZ ] && b=$((NZ-1))
  { echo "local X0, Z0, NX, STEP, ROW_A, ROW_B = $X0, $Z0, $NX, $S, $a, $b"; cat "$DIR/grab.lua"; } | $R lua - $SA --out "$tmp" >/dev/null
  grep '^|' "$tmp" >> "$out" || { echo "grab failed rows $a-$b:"; head -c 400 "$tmp"; exit 2; }
done
rm -f "$tmp"
got=$(grep -c '^|' "$out")
[ "$got" -eq "$NZ" ] || { echo "grab incomplete: $got/$NZ rows"; exit 2; }
echo "grab $NX x $NZ @ $S -> $out"
