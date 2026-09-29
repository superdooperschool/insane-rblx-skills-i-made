#!/bin/bash
f="$1"; target="$2"
python -c "
import sys
src=open('$f',encoding='utf-8').read()
open('c1.lua','w',encoding='utf-8').write('local f, e = loadstring([==[' + src + ']==]) return tostring(f ~= nil) .. \" \" .. tostring(e)')"
res=$(node "$HOME/.claude/skills/rbx/rbx.mjs" lua c1.lua)
echo "compile: $res"
case "$res" in "true nil") node "$HOME/.claude/skills/rbx/rbx.mjs" write "$target" "$f";; *) echo "ABORT push"; exit 2;; esac
