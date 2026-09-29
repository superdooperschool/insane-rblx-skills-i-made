#!/usr/bin/env bash
# rbx-terrain front end. All heavy work runs inside Studio; only summaries come back.
#   run.sh scan <Box> [map]          analyse a box (terrain grammar numbers)
#   run.sh dry|map|build <recipe>    dry = conflicts + planned slopes, map = + ASCII preview, build = restore baseline + write
#   run.sh backup <Box> [force]      save baseline TerrainRegion + tile hashes (kept unless force)
#   run.sh restore <Box>             paste baseline back, prove every tile hash matches
#   run.sh list                      baselines in ServerStorage.TerrainBackups
#   run.sh drop <Box>                delete a baseline (after user sign-off)
#   run.sh lua <file>                any Luau with the kit (K) loaded
#   run.sh analyze <Box|x0,z0,x1,z1> [step 4] [name]   grab surface + hills/bowls/climb/slope/paint -> $SCANS/<name>.json/.png
#   run.sh plan <recipe.lua> [nChunks|0]   compose only (no writes), export the planned surface, analyze it + verdict
#   STUDIO=<id> selects the Studio when two are connected; ANALYZE_OPTS="start=x,z climbDeg=25 nms=32" tunes analyze
DIR="$(cd "$(dirname "$0")" && pwd)"
R="node $HOME/.claude/skills/rbx/rbx.mjs"
SA=${STUDIO:+--studio $STUDIO}
cmd="$1"; shift
kitrun() { { echo "local RUN_MODE = '$1'"; cat "$DIR/kit.lua"; cat; } | $R lua - $SA "${@:2}"; }
case "$cmd" in
  scan)    sed "s/__BOX__/$1/; s/__MAP__/$( [ -n "$2" ] && echo true || echo false )/" "$DIR/scan.lua" | $R lua - $SA ;;
  dry|map|build) kitrun "$cmd" < "$1" "${@:2}" ;;
  lua)     kitrun lua < "$1" "${@:2}" ;;
  backup)  echo "return K.backup(K.grid('$1'), $( [ -n "$2" ] && echo true || echo false ))" | kitrun x ;;
  restore) echo "local G = K.grid('$1') K.record('rbx-terrain restore', function() K.restore(G) end) local d, t = K.compareBaseline(G) return (#d == 0 and 'PASS' or 'FAIL') .. ' restore $1: ' .. #d .. '/' .. t .. ' tiles differ from baseline'" | kitrun x ;;
  list)    echo "local o = {} local f = game.ServerStorage:FindFirstChild('TerrainBackups') for _, c in ipairs(f and f:GetChildren() or {}) do o[#o+1] = c.Name .. ' ' .. tostring(c:GetAttribute('Stamp')) end return #o > 0 and table.concat(o, '\n') or 'no baselines'" | kitrun x ;;
  drop)    echo "local f = game.ServerStorage:FindFirstChild('TerrainBackups') local c = f and f:FindFirstChild('$1') if c then c:Destroy() end return c and 'dropped $1' or 'none'" | kitrun x ;;
  analyze) st=${2:-4}; nm=${3:-$1}; sd=${SCANS:-./scans}; mkdir -p "$sd"
           if [[ "$1" == *,* ]]; then IFS=, read -r ax az bx bz <<< "$1"
           else read -r ax az bx bz < <($R lua "local p = workspace:FindFirstChild('$1', true) assert(p and p:IsA('BasePart'), 'no box $1') local s = $st local a, b = p.Position - p.Size / 2, p.Position + p.Size / 2 return string.format('%d %d %d %d', math.ceil(a.X / s) * s, math.ceil(a.Z / s) * s, math.floor(b.X / s) * s, math.floor(b.Z / s) * s)" $SA | tail -1); fi
           [ -n "$bz" ] || { echo "cannot resolve $1"; exit 2; }
           STUDIO=$STUDIO bash "$DIR/analyze/grab.sh" "$sd/$nm.grab" "$ax" "$az" "$bx" "$bz" "$st" && node "$DIR/analyze/analyze.mjs" "$sd/$nm.grab" "$nm" $ANALYZE_OPTS ;;
  plan)    rec=$1; n=${2:-0}; nm=$(basename "$rec" .lua)_plan; sd=${SCANS:-./scans}; mkdir -p "$sd"
           fetch() { local f=$1; if head -1 "$f" | grep -q '^#pages'; then read -r _ np pn < <(head -1 "$f"); : > "$f"
               for ((k=1; k<=np; k++)); do $R lua "return game:GetService('ServerStorage').TerrainPlan['$pn'].p$k.Value" $SA --out "$f.pg" >/dev/null; grep -E '^(#grab|\|)' "$f.pg" >> "$f"; done
               rm -f "$f.pg"; $R lua "local r = game:GetService('ServerStorage'):FindFirstChild('TerrainPlan') if r and r:FindFirstChild('$pn') then r['$pn']:Destroy() end if r and #r:GetChildren() == 0 then r:Destroy() end return 'ok'" $SA >/dev/null; fi; }
           if [ "$n" = "0" ]; then { echo "local RUN_MODE = 'plan'"; cat "$DIR/kit.lua" "$rec"; } | $R lua - $SA --out "$sd/$nm.grab" >/dev/null; fetch "$sd/$nm.grab"
           else for ((i=1; i<=n; i++)); do { echo "local RUN_MODE, CHUNK_INDEX = 'plan', $i"; cat "$DIR/kit.lua" "$rec"; } | $R lua - $SA --out "$sd/${nm}_$i.grab" >/dev/null; fetch "$sd/${nm}_$i.grab"
                  grep -q '^#grab' "$sd/${nm}_$i.grab" || { echo "plan chunk $i failed:"; head -c 400 "$sd/${nm}_$i.grab"; exit 2; }; done
                node "$DIR/analyze/merge.mjs" "$sd/$nm.grab" "$sd"/${nm}_[0-9]*.grab; fi
           grep -q '^#grab' "$sd/$nm.grab" || { echo "plan failed:"; head -c 400 "$sd/$nm.grab"; exit 2; }
           node "$DIR/analyze/analyze.mjs" "$sd/$nm.grab" "$nm" $ANALYZE_OPTS ;;
  *) sed -n '2,13p' "$0" ;;
esac
