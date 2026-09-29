#!/usr/bin/env bash
out=$1; CX=$2; CZ=$3; HALF=${4:-2040}; STEP=${5:-8}; STUDIO=${STUDIO:+--studio $STUDIO}
N=$(( 2 * HALF / STEP )); : > "$out"
for a in $(seq 0 60 $N); do b=$((a+59)); [ $b -gt $N ] && b=$N
  { echo "local CX, CZ, HALF, STEP, ROW_A, ROW_B = $CX, $CZ, $HALF, $STEP, $a, $b"; cat "$(dirname "$0")/sample.lua"; } | node $HOME/.claude/skills/rbx/rbx.mjs lua - $STUDIO --out /tmp/rs_part.txt >/dev/null
  grep -E '^[A-Za-z0-9+/]{3}' /tmp/rs_part.txt >> "$out"
done
wc -l "$out"
