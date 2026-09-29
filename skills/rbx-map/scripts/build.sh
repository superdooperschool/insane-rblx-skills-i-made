#!/usr/bin/env bash
# rbx-map/scripts/build.sh <game-name> [out-dir]  -> <out-dir>/MAP.md   (default out-dir ./<game-name>)
# Indexes every script per service with map.lua, prepends a summary (services, remotes, Net channels, big scripts).
set -e
GAME="${1:?game name}"; OUT="${2:-./$GAME}"; mkdir -p "$OUT"
R="node $HOME/.claude/skills/rbx/rbx.mjs"; HERE="$(cd "$(dirname "$0")" && pwd)"; TMP="$(mktemp -d)"
{
  echo "# $GAME MAP  (generated $(date +%F) by rbx-map; grep it, never read it whole)"
  echo
  echo "Regenerate: bash ~/.claude/skills/rbx-map/scripts/build.sh $GAME"
  echo
  echo "## Summary"
  $R lua "$HERE/summary.lua"
  echo
  echo "## Net channels (from rbx-net)"
  $R lua "$HOME/.claude/skills/rbx-net/scripts/net.lua" | sed 's/^/    /'
  echo
} > "$OUT/MAP.md"
for svc in ServerScriptService ServerStorage ReplicatedStorage ReplicatedFirst StarterGui StarterPlayer StarterPack Workspace; do
  sed "s|__SERVICE__|$svc|" "$HERE/map.lua" | $R lua - --out "$TMP/$svc.md" >/dev/null 2>&1 || true
  if [ -s "$TMP/$svc.md" ] && ! grep -q "^ERROR" "$TMP/$svc.md"; then cat "$TMP/$svc.md" >> "$OUT/MAP.md"; echo >> "$OUT/MAP.md"; fi
done
rm -rf "$TMP"
echo "wrote $OUT/MAP.md ($(wc -c < "$OUT/MAP.md") chars, $(grep -c '^- ' "$OUT/MAP.md") scripts)"
