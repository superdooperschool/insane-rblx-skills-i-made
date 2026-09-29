#!/usr/bin/env bash
# rbx-perf/scripts/run.sh <move|stand> <seconds> [label]
# Drives player 1 along BENCH_A -> BENCH_B (server) while sampling the client. Play must be running with one player.
# env: BENCH_A="x,y,z" BENCH_B="x,y,z" BENCH_SPEED=110 BENCH_OUT=results.txt
R="node $HOME/.claude/skills/rbx/rbx.mjs"; HERE="$(cd "$(dirname "$0")" && pwd)"
MODE=${1:?move|stand}; SEC=${2:?seconds}; LABEL=${3:-run}
A=${BENCH_A:-"-330,500,153"}; B=${BENCH_B:-"550,500,153"}; SPEED=${BENCH_SPEED:-110}; OUT=${BENCH_OUT:-"$HERE/results.txt"}
TMP="$(mktemp -d)"
sed "s/__MODE__/$MODE/; s/__DUR__/$((SEC+5))/; s/__A__/$A/; s/__B__/$B/; s/__SPEED__/$SPEED/" "$HERE/move.lua" > "$TMP/move.lua"
sed "s/__SEC__/$SEC/" "$HERE/measure.lua" > "$TMP/measure.lua"
$R lua --dm Server "$TMP/move.lua" >/dev/null
RES=$($R lua --dm Client "$TMP/measure.lua")
echo "$(date +%H:%M:%S) $LABEL $MODE ${SEC}s $RES" | tee -a "$OUT"
rm -rf "$TMP"
