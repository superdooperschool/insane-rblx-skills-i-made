// token-minimizer/scripts/audit.mjs - where the tokens went, from Claude Code transcripts.
// usage: node audit.mjs [projectDir=~/.claude/projects/<cwd-encoded>] [--rbx] [--session <id-prefix>]
// Usage is counted ONCE per assistant message id (the JSONL repeats usage on every content block).
import fs from "fs"; import os from "os"; import path from "path";
const args = process.argv.slice(2);
const dir = args.find(a => !a.startsWith("--")) || path.join(os.homedir(), ".claude", "projects", process.cwd().replace(/[^A-Za-z0-9]/g, "-"));
const onlyRbx = args.includes("--rbx"); const sid = args[args.indexOf("--session") + 1];
const files = fs.readdirSync(dir).filter(f => f.endsWith(".jsonl") && (!args.includes("--session") || f.startsWith(sid))).map(f => path.join(dir, f));
const L = n => Math.round(n).toLocaleString(); const isImg = p => /\.(jpe?g|png|webp|gif)$/i.test(p || "");
const T = { sessions: 0, msgs: 0, prompts: 0, in: 0, cw: 0, cr: 0, out: 0, ctx: 0, fixed: 0, textOnlyMsgs: 0, textChars: 0 };
const tools = {}; const dup = {}; const big = []; const rows = []; let truncReread = 0, sameFile = 0, imgReads = 0, unrangedReads = 0, rangedReads = 0, healthCalls = 0, playToggles = 0, fullWrites = 0;
for (const f of files) {
  let lines; try { lines = fs.readFileSync(f, "utf8").split("\n").filter(Boolean); } catch { continue; }
  const seen = {}, byUse = {}, seenRead = {}; let rbx = false, first = null, s = { id: path.basename(f).slice(0, 8), msgs: 0, ctx: 0, out: 0, prompts: 0, res: 0, model: "" };
  for (const line of lines) {
    let j; try { j = JSON.parse(line); } catch { continue; }
    if (j.type === "assistant" && j.message) {
      const m = j.message; const tus = (m.content || []).filter(c => c.type === "tool_use");
      for (const c of tus) {
        byUse[c.id] = c; const inp = JSON.stringify(c.input || {}); const cmd = c.input?.command || "";
        if (c.name.includes("rbx") || c.name.includes("Roblox") || inp.includes("rbx.mjs")) rbx = true;
        const t = tools[c.name] ||= { calls: 0, res: 0, max: 0, inChars: 0 }; t.calls++; t.inChars += inp.length;
        dup[c.name + "|" + inp.slice(0, 200)] = (dup[c.name + "|" + inp.slice(0, 200)] || 0) + 1;
        if (/\$R read|rbx\.mjs.* read /.test(cmd) || c.input?.op === "script_read" || c.name.endsWith("script_read")) { if (/--from|--to|--out/.test(cmd) || c.input?.args?.start_line || c.input?.start_line) rangedReads++; else unrangedReads++; }
        if (/\$R health/.test(cmd) || c.input?.op === "health" || c.name.endsWith("list_roblox_studios") || c.name.endsWith("get_studio_state")) healthCalls++;
        if (c.name.endsWith("start_stop_play")) playToggles++;
        if (/\$R write/.test(cmd) || c.name === "Write") fullWrites++;
        if (c.name === "Read") { const p = c.input?.file_path || ""; if (isImg(p)) imgReads++; else { if (/rbx-\d+\.txt|tool-results/.test(p)) truncReread++; if (seenRead[p]) sameFile++; seenRead[p] = 1; } }
      }
      if (seen[m.id]) continue; seen[m.id] = 1;
      const u = m.usage || {}; const ctx = (u.input_tokens || 0) + (u.cache_creation_input_tokens || 0) + (u.cache_read_input_tokens || 0);
      if (first === null) first = ctx; s.msgs++; s.ctx += ctx; s.out += u.output_tokens || 0; s.model = m.model; s.fixed = (s.fixed || 0) + first;
      s.in = (s.in || 0) + (u.input_tokens || 0); s.cw = (s.cw || 0) + (u.cache_creation_input_tokens || 0); s.cr = (s.cr || 0) + (u.cache_read_input_tokens || 0);
      if (!tus.length) { const tc = (m.content || []).filter(c => c.type === "text").reduce((a, c) => a + c.text.length, 0); if (tc) { s.textOnly = (s.textOnly || 0) + 1; s.textChars = (s.textChars || 0) + tc; } }
    } else if (j.type === "user" && j.message) {
      const c = j.message.content; if (typeof c === "string") s.prompts++;
      else if (Array.isArray(c)) for (const x of c) {
        if (x.type === "text") s.prompts++;
        if (x.type === "tool_result") { const txt = typeof x.content === "string" ? x.content : JSON.stringify(x.content || ""); const tu = byUse[x.tool_use_id]; const t = tools[tu?.name || "?"] ||= { calls: 0, res: 0, max: 0, inChars: 0 }; t.res += txt.length; if (txt.length > t.max) t.max = txt.length; s.res += txt.length; if (txt.length > 12000 && !txt.includes('"type":"image"')) big.push({ s: s.id, tool: tu?.name, chars: txt.length, input: JSON.stringify(tu?.input || {}).slice(0, 110) }); }
      }
    }
  }
  if (s.msgs < 3 || (onlyRbx && !rbx)) continue;
  T.sessions++; T.msgs += s.msgs; T.prompts += s.prompts; T.in += s.in; T.cw += s.cw; T.cr += s.cr; T.out += s.out; T.ctx += s.ctx; T.fixed += s.fixed; T.textOnlyMsgs += s.textOnly || 0; T.textChars += s.textChars || 0;
  rows.push({ ...s, first, avg: Math.round(s.ctx / s.msgs) });
}
const cost = T.in * 3e-6 + T.cr * 0.3e-6 + T.cw * 3.75e-6 + T.out * 15e-6;
console.log(`sessions=${T.sessions} model-calls=${L(T.msgs)} prompts=${L(T.prompts)} calls/prompt=${(T.msgs / Math.max(1, T.prompts)).toFixed(1)}`);
console.log(`tokens: fresh-in=${L(T.in)} cache-write=${L(T.cw)} cache-read=${L(T.cr)} output=${L(T.out)}`);
console.log(`context: Σ=${L(T.ctx)} avg/call=${L(T.ctx / T.msgs)}  fixed-system share≈${(100 * T.fixed / T.ctx).toFixed(0)}%  (fixed = first-call context, repaid every call)`);
console.log(`est $ (sonnet rates): ${cost.toFixed(0)} = cache-read ${(T.cr * 0.3e-6).toFixed(0)} + cache-write ${(T.cw * 3.75e-6).toFixed(0)} + output ${(T.out * 15e-6).toFixed(0)} + fresh ${(T.in * 3e-6).toFixed(0)}`);
console.log(`text-only model calls=${L(T.textOnlyMsgs)} (${L(T.textChars)} chars of prose)`);
console.log(`reads: ranged/--out=${rangedReads} unranged=${unrangedReads} | truncated-output re-reads=${truncReread} | same-file-twice=${sameFile} | image Reads=${imgReads} | health/state calls=${healthCalls} | play toggles=${playToggles} | full-file writes=${fullWrites}`);
console.log("\nTOP SESSIONS by Σcontext (each call re-sends its whole context):");
for (const r of rows.sort((a, b) => b.ctx - a.ctx).slice(0, 8)) console.log(` ${r.id} ${r.model} calls=${r.msgs} prompts=${r.prompts} avgCtx=${L(r.avg)} firstCtx=${L(r.first)} out=${L(r.out)} resultChars=${L(r.res)}`);
console.log("\nTOOLS by result chars (what lands in context and stays):");
for (const [n, t] of Object.entries(tools).sort((a, b) => b[1].res - a[1].res).slice(0, 14)) console.log(` ${n.padEnd(40)} calls=${String(t.calls).padStart(5)} result=${L(t.res).padStart(12)} avg=${L(t.res / t.calls).padStart(8)} max=${L(t.max).padStart(9)} input=${L(t.inChars).padStart(10)}`);
console.log("\nBIGGEST non-image results:"); for (const b of big.sort((a, b) => b.chars - a.chars).slice(0, 12)) console.log(` ${b.s} ${(b.tool || "?").padEnd(32)} ${L(b.chars).padStart(8)} ${b.input}`);
console.log("\nREPEATED identical calls (same tool + first 200 chars of input):"); for (const [k, c] of Object.entries(dup).filter(x => x[1] >= 5).sort((a, b) => b[1] - a[1]).slice(0, 15)) console.log(` ${c}x ${k.slice(0, 150).replace(/\n/g, " ")}`);
