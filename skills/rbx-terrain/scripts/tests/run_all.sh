#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"; S="$DIR/.."
export LABOUT=${LABOUT:-./lab_out}; mkdir -p "$LABOUT"
R="node $HOME/.claude/skills/rbx/rbx.mjs"; SA=${STUDIO:+--studio $STUDIO}
kr() { { echo "local RUN_MODE, CHUNK_INDEX, VARIANT = 'lab', 0, ''"; cat "$S/kit.lua" "$DIR/lab.lua"; cat; } | $R lua - $SA; }
declare -A P F T
total_fail=0
row() { local n=$1 log=$2 s=$3; P[$n]=$(grep -c '^\s*\(  [a-z0-9 ]*: \)\?PASS' "$log"); F[$n]=$(grep -c 'FAIL' "$log"); T[$n]=$s; [ "${F[$n]}" -gt 0 ] && total_fail=$((total_fail + 1)); }
t0=$(date +%s)
node "$S/analyze/analyze.mjs" --selftest > "$LABOUT/all_analyzer.log" 2>&1; row analyzer "$LABOUT/all_analyzer.log" $(( $(date +%s) - t0 ))
for t in mound bowl ring pad rolling hillfield paths bore cliff cliffadd paint trough caves; do
  a=$(date +%s); bash "$DIR/run.sh" $t > "$LABOUT/all_$t.log" 2>&1 || echo "FAIL $t: runner exit $?" >> "$LABOUT/all_$t.log"
  grep -q '^PASS site .* erased: 0 solid' "$LABOUT/all_$t.log" || echo "FAIL $t: site not proven empty" >> "$LABOUT/all_$t.log"
  row $t "$LABOUT/all_$t.log" $(( $(date +%s) - a ))
done
for r in "t_chunk.lua 7" "t_bridge.lua 9" "t_chunkguard.lua 14" "t_freeroam.lua 16" "t_river.lua 17"; do
  set -- $r; n=${1%.lua}; a=$(date +%s); GRADE=1 bash "$DIR/chunk.sh" "$DIR/$1" $2 > "$LABOUT/all_$n.log" 2>&1 || echo "FAIL $n: runner exit" >> "$LABOUT/all_$n.log"
  grep -q '^PASS site .* erased: 0 solid' "$LABOUT/all_$n.log" || echo "FAIL $n: site not proven empty" >> "$LABOUT/all_$n.log"
  row ${n#t_} "$LABOUT/all_$n.log" $(( $(date +%s) - a ))
done
a=$(date +%s); bash "$DIR/plan_check.sh" "$DIR/t_freeroam.lua" 16 > "$LABOUT/all_plan.log" 2>&1 || echo "FAIL plan: runner exit" >> "$LABOUT/all_plan.log"; grep -q "^PASS site .* erased: 0 solid" "$LABOUT/all_plan.log" || echo "FAIL plan: site not proven empty" >> "$LABOUT/all_plan.log"; row plan "$LABOUT/all_plan.log" $(( $(date +%s) - a ))
a=$(date +%s); bash "$S/run.sh" dry "$S/selftest.lua" > "$LABOUT/all_kitselftest.log" 2>&1; row kitselftest "$LABOUT/all_kitselftest.log" $(( $(date +%s) - a ))
echo "local o = {} for k = 0, 19 do o[#o + 1] = k .. '=' .. LAB.solid(k) end local bf = game:GetService('ServerStorage'):FindFirstChild('TerrainBackups') local lab = 0 for _, ch in ipairs(bf and bf:GetChildren() or {}) do if ch.Name:sub(1, 4) == 'lab_' then lab += 1 end end return 'sites solid voxels: ' .. table.concat(o, ' ') .. ' | lab backups left: ' .. lab" | kr > "$LABOUT/all_sites.log"
grep -qE '=([1-9])' <(grep -o 'sites solid voxels: .*|' "$LABOUT/all_sites.log") && { echo "FAIL sites not empty" >> "$LABOUT/all_sites.log"; total_fail=$((total_fail + 1)); }
grep -q 'lab backups left: 0' "$LABOUT/all_sites.log" || { echo "FAIL lab backups left" >> "$LABOUT/all_sites.log"; total_fail=$((total_fail + 1)); }
printf "%-12s %5s %5s %6s\n" test pass fail secs
for n in analyzer mound bowl ring pad rolling hillfield paths bore cliff cliffadd paint trough caves chunk bridge chunkguard freeroam river plan kitselftest; do printf "%-12s %5s %5s %6s\n" $n "${P[$n]}" "${F[$n]}" "${T[$n]}"; done
tail -1 "$LABOUT/all_sites.log"
grep -h 'FAIL' "$LABOUT"/all_*.log | cut -c1-220
echo "total $(( $(date +%s) - t0 ))s, failing tests: $total_fail"
[ $total_fail -eq 0 ] && echo "RUN_ALL PASS" || echo "RUN_ALL FAIL"
exit $total_fail
