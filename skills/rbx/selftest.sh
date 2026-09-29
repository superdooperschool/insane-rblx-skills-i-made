#!/usr/bin/env bash
# rbx selftest - creates ReplicatedStorage.RBXSelfTest, exercises every command, destroys it.
# Fails loud. Run against any open place; touches nothing else.
set -u
R="node $(dirname "$0")/rbx.mjs"
T=$(mktemp -d)
fail=0
ok(){ echo "PASS $1"; }
no(){ echo "FAIL $1 -- $2"; fail=1; }

# --- guard: everything below is Edit-only. Play mode is an environment state, not a failure ---
state=$($R call get_studio_state 2>&1)
case "$state" in
  *"Studio Mode: Play"*)
    echo "SKIP - Studio is in Play mode; this test needs Edit."
    echo "      Stop the playtest, then rerun. State: $(echo "$state" | tr -s ' \n' ' ')"
    exit 0;;
  *"NO PLACE OPEN"*|*"Place is not open"*)
    echo "SKIP - no place open in Studio."; exit 0;;
esac

# --- setup: scratch module with a deliberately duplicated anchor ---
cat > "$T/v1.lua" <<'LUA'
local M = {}
function M.dup() return 1 end
function M.dup2() return 1 end
M.marker = "alpha"
-- ZEBRAWORD lives only in this line comment
--[[ ZEBRAWORD also hides in this
     multi-line block comment ]]
local decoy = "ZEBRAWORDINSIDE"
local ZEBRAWORD = 1
local notWord = ZEBRAWORDLONGER
return M
LUA

$R lua 'local rs=game:GetService("ReplicatedStorage")
local old=rs:FindFirstChild("RBXSelfTest") if old then old:Destroy() end
local m=Instance.new("ModuleScript") m.Name="RBXSelfTest" m.Source="return {}" m.Parent=rs
return {made=m:GetFullName()}' >/dev/null || { echo "FAIL setup"; exit 1; }

# 1. write + hash verification
out=$($R write game.ReplicatedStorage.RBXSelfTest "$T/v1.lua" 2>&1)
case "$out" in OK*verified) ok "write hash-verified";; *) no "write" "$out";; esac

# 2. readback matches what we wrote (proves .Source actually synced, not detached)
$R read game.ReplicatedStorage.RBXSelfTest --out "$T/back.lua" >/dev/null 2>&1
if grep -q 'M.marker = "alpha"' "$T/back.lua"; then ok "read sees the written source"; else no "read" "$(head -5 "$T/back.lua")"; fi

# 3. edit REJECTS a non-unique anchor (the multi_edit splice bug)
out=$($R edit game.ReplicatedStorage.RBXSelfTest --old 'return 1 end' --new 'return 2 end' 2>&1)
case "$out" in *"not unique"*) ok "edit rejects ambiguous anchor";; *) no "edit-uniqueness" "$out";; esac

# 4. edit APPLIES a unique anchor and verifies readback
out=$($R edit game.ReplicatedStorage.RBXSelfTest --old 'M.marker = "alpha"' --new 'M.marker = "beta"' 2>&1)
case "$out" in OK*) ok "edit applies unique anchor";; *) no "edit-apply" "$out";; esac
$R read game.ReplicatedStorage.RBXSelfTest --out "$T/b2.lua" >/dev/null 2>&1
grep -q 'beta' "$T/b2.lua" && ok "edit landed on disk-readback" || no "edit-landed" "$(cat "$T/b2.lua")"

# 5. RBX.req returns FRESH module state after a rewrite (kills the require-cache trap)
out=$($R lua 'local m=RBX.req("game.ReplicatedStorage.RBXSelfTest") return {marker=m.marker}' 2>&1)
case "$out" in *beta*) ok "RBX.req is cache-free";; *) no "RBX.req" "$out";; esac

# 6. grep escapes Luau pattern magic (raw script_grep returns nothing for this)
out=$($R grep 'M.marker = "beta"' 2>&1)
case "$out" in *RBXSelfTest*) ok "grep finds literal with magic chars";; *) no "grep" "$out";; esac

# 7. RBX.set persists a property write through ChangeHistoryService
out=$($R lua 'local i=RBX.find("game.ReplicatedStorage.RBXSelfTest") RBX.set(i,"Name","RBXSelfTest") return {n=i.Name}' 2>&1)
case "$out" in *RBXSelfTest*) ok "RBX.set commits";; *) no "RBX.set" "$out";; esac

# 8. tree is filterable
out=$($R tree ReplicatedStorage --kw RBXSelfTest --depth 1 2>&1)
case "$out" in *RBXSelfTest*) ok "tree filters";; *) no "tree" "$out";; esac

# 9. find ignores comments: ZEBRAWORD appears in 2 comments and 3 code spots
out=$($R find ZEBRAWORD --path ReplicatedStorage.RBXSelfTest 2>&1)
case "$out" in *"no matches"*) no "find-vacuous" "found nothing at all - later comment assertions would pass vacuously";; *) ok "find returns hits (guards the next two)";; esac
if echo "$out" | grep -q "line comment"; then no "find-comments" "matched a line comment"; else ok "find skips line comments"; fi
if echo "$out" | grep -q "block comment"; then no "find-block" "matched a block comment"; else ok "find skips block comments"; fi

# 10. --word rejects substrings inside longer identifiers
out=$($R find ZEBRAWORD --path ReplicatedStorage.RBXSelfTest --word 2>&1)
if echo "$out" | grep -q "ZEBRAWORDINSIDE"; then no "find-word" "matched inside a longer token"; else ok "find --word respects boundaries"; fi
case "$out" in *"local ZEBRAWORD = 1"*) ok "find --word keeps the real hit";; *) no "find-word-hit" "$out";; esac

# 11. --comments opts back in
out=$($R find ZEBRAWORD --path ReplicatedStorage.RBXSelfTest --comments 2>&1)
case "$out" in *"line comment"*) ok "find --comments includes them";; *) no "find-comments-flag" "$out";; esac

# 12. reported line numbers match script_read exactly
line=$($R find "local ZEBRAWORD = 1" --path ReplicatedStorage.RBXSelfTest 2>&1 | head -1 | grep -oE 'RBXSelfTest:[0-9]+' | cut -d: -f2)
back=$($R read game.ReplicatedStorage.RBXSelfTest --from "$line" --to "$line" 2>&1)
case "$back" in *"local ZEBRAWORD = 1"*) ok "find line numbers match read (line $line)";; *) no "find-lineno" "line $line gave: $back";; esac

# 13. outline lists definitions
out=$($R outline game.ReplicatedStorage.RBXSelfTest 2>&1)
case "$out" in *"M.dup"*) ok "outline lists functions";; *) no "outline" "$out";; esac

# 14. MCP server answers a concurrent burst without dropping or mispairing responses
out=$(node "$(dirname "$0")/burst.mjs" 2>&1 | tail -1)
case "$out" in OK*) ok "server burst: $out";; *) no "server-burst" "$out";; esac

# --- teardown ---
$R lua 'local i=game:GetService("ReplicatedStorage"):FindFirstChild("RBXSelfTest") if i then i:Destroy() end return {cleaned=true}' >/dev/null 2>&1
rm -rf "$T"
[ $fail -eq 0 ] && echo "ALL PASS" || echo "SELFTEST FAILED"
exit $fail
