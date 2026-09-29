import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execSync, spawn } from 'node:child_process';

export const HERE = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const PORT_CACHE = path.join(HERE, '.port');

export let LAST_HEALTH = '';

async function healthy(port) {
  try {
    const r = await fetch('http://127.0.0.1:' + port + '/health', { signal: AbortSignal.timeout(700) });
    if (!r.ok) return false;
    const body = await r.text();
    if (!body.startsWith('OK')) return false;
    LAST_HEALTH = body;
    return true;
  } catch { return false; }
}

function findExe() {
  const base = path.join(os.homedir(), 'AppData', 'Local', 'Roblox', 'Versions');
  try {
    for (const d of fs.readdirSync(base)) {
      const p = path.join(base, d, 'StudioMCP.exe');
      if (fs.existsSync(p)) return p;
    }
  } catch { }
  return null;
}

async function findPort(spawned = false) {
  const cached = fs.existsSync(PORT_CACHE) && fs.readFileSync(PORT_CACHE, 'utf8').trim();
  if (cached && await healthy(cached)) return cached;
  const pids = new Set();
  try {
    for (const l of execSync('tasklist /fi "imagename eq StudioMCP.exe" /nh', { encoding: 'utf8' }).split('\n')) {
      const m = l.match(/StudioMCP\.exe\s+(\d+)/);
      if (m) pids.add(m[1]);
    }
  } catch { }
  if (!pids.size) {
    const exe = !spawned && findExe();
    if (!exe) throw new Error('StudioMCP.exe is not running. Open Roblox Studio.');
    spawn(process.execPath, [path.join(HERE, 'keep-proxy.mjs'), exe], { detached: true, stdio: 'ignore', windowsHide: true }).unref();
    await new Promise(r => setTimeout(r, 2000));
    return findPort(true);
  }
  const ports = new Set();
  for (const l of execSync('netstat -ano', { encoding: 'utf8' }).split('\n')) {
    const m = l.match(/TCP\s+127\.0\.0\.1:(\d+)\s+\S+\s+LISTENING\s+(\d+)/);
    if (m && pids.has(m[2])) ports.add(m[1]);
  }
  for (const p of ports) if (await healthy(p)) { fs.writeFileSync(PORT_CACHE, p); return p; }
  throw new Error('found StudioMCP.exe but no healthy /health port. Restart Studio.');
}

export function forgetPort() {
  try { fs.unlinkSync(PORT_CACHE); } catch { }
}

export async function connect() {
  const port = await findPort();
  const ws = new WebSocket('ws://127.0.0.1:' + port + '/proxy');
  const pend = new Map();
  const ctrl = new Map();
  let nid = Math.floor(Math.random() * 1e9);
  await new Promise((res, rej) => {
    ws.onopen = res;
    ws.onerror = () => rej(new Error('websocket connect failed on port ' + port));
  });
  ws.onmessage = (e) => {
    const m = JSON.parse(e.data);
    if (m.type === 'json_rpc' && pend.has(m.id)) { const f = pend.get(m.id); pend.delete(m.id); f(m); return; }
    if (m.control_type === 'list_studios_response' && ctrl.has(m.request_id)) { const f = ctrl.get(m.request_id); ctrl.delete(m.request_id); f(m); }
    if (m.control_type === 'tools_updated' && m.tools) TOOLS = m.tools;
  };
  ws.send(JSON.stringify({ type: 'control', control_type: 'proxy_hello', tools: null }));

  const rpc = (method, params, ms = 300000) => new Promise((res, rej) => {
    const id = ++nid;
    const t = setTimeout(() => { pend.delete(id); rej(new Error('timeout after ' + ms + 'ms: ' + method)); }, ms);
    pend.set(id, (v) => { clearTimeout(t); res(v); });
    ws.send(JSON.stringify({ type: 'json_rpc', jsonrpc: '2.0', id, method, params }));
  });

  const studios = () => new Promise((res, rej) => {
    const rid = 'r' + Math.random().toString(36).slice(2);
    const t = setTimeout(() => rej(new Error('list_studios timed out')), 8000);
    ctrl.set(rid, (m) => { clearTimeout(t); res(m.studios || []); });
    ws.send(JSON.stringify({ type: 'control', control_type: 'list_studios', request_id: rid }));
  });

  return { ws, rpc, studios, port, close: () => ws.close() };
}

export let TOOLS = [];

const EXT = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'audio/mpeg': 'mp3', 'audio/wav': 'wav' };
export let IMG_DIR = null;
export const setImgDir = (d) => { IMG_DIR = d; };

function saveBlob(x) {
  const ext = EXT[x.mimeType] || (x.type === 'image' ? 'png' : 'bin');
  const dir = IMG_DIR || os.tmpdir();
  fs.mkdirSync(dir, { recursive: true });
  const f = path.join(dir, 'rbx-' + x.type + '-' + Date.now() + '.' + ext);
  fs.writeFileSync(f, Buffer.from(x.data, 'base64'));
  return '[' + x.type + ' saved: ' + f + ' (' + (fs.statSync(f).size / 1024).toFixed(0) + ' KB, ' + x.mimeType + ')]';
}

export function text(r) {
  if (r.error) return 'JSONRPC ERROR: ' + JSON.stringify(r.error);
  const c = (r.result && r.result.content) || [];
  const s = c.map((x) => {
    if (x.text !== undefined) return x.text;
    if (x.data) return saveBlob(x);
    return '[' + x.type + ']';
  }).join('\n');
  return r.result && r.result.isError ? 'ERROR: ' + s : s;
}

export const PRELUDE = [
  'local _CHS=game:GetService("ChangeHistoryService")',
  'local _RS=game:GetService("ReplicatedStorage")',
  'local RBX={}',
  'function RBX.find(p)',
  '  local n=game',
  '  for seg in string.gmatch(p,"[^%.]+") do',
  '    if seg~="game" then',
  '      local nx=n:FindFirstChild(seg)',
  '      if not nx and n==game then local ok,sv=pcall(function() return game:GetService(seg) end); if ok then nx=sv end end',
  '      if not nx then error("no such instance: "..p.." (missing \'"..seg.."\')") end',
  '      n=nx',
  '    end',
  '  end',
  '  return n',
  'end',
  'function RBX.set(inst,prop,val)',
  '  local rec=_CHS:TryBeginRecording("rbx-set")',
  '  inst[prop]=val',
  '  if rec then _CHS:FinishRecording(rec,Enum.FinishRecordingOperation.Commit) end',
  '  return inst[prop]',
  'end',
  'function RBX.src(inst,new)',
  '  game:GetService("ScriptEditorService"):UpdateSourceAsync(inst,function() return new end)',
  '  return #new',
  'end',
  'function RBX.req(inst)',
  '  if type(inst)=="string" then inst=RBX.find(inst) end',
  '  local c=inst:Clone(); c.Parent=_RS',
  '  local ok,m=pcall(require,c); c:Destroy()',
  '  if not ok then error(m) end',
  '  return m',
  'end',
  'function RBX.hash(s)',
  '  local h=5381',
  '  for i=1,#s do h=(h*33+string.byte(s,i))%4294967296 end',
  '  return h',
  'end',
  ''
].join('\n');

export const withPrelude = (code) => (/\bRBX\./.test(code) ? PRELUDE + '\n' + code : code);

export function bracket(s) {
  let n = 0;
  while (s.includes(']' + '='.repeat(n) + ']')) n++;
  const e = '='.repeat(n);
  return ['[' + e + '[', ']' + e + ']'];
}

export const djb2 = (s) => {
  let h = 5381;
  for (const c of Buffer.from(s, 'utf8')) h = (h * 33 + c) % 4294967296;
  return h;
};

export function loose(out) {
  try { return JSON.parse(out); } catch { }
  const o = {};
  for (const m of out.matchAll(/["']?(\w+)["']?\s*[=:]\s*(-?\d+|true|false|"[^"]*")/g)) {
    o[m[1]] = m[2] === 'true' ? true : m[2] === 'false' ? false : m[2].startsWith('"') ? m[2].slice(1, -1) : +m[2];
  }
  return o;
}

export function writeCode(ipath, src) {
  const payload = JSON.stringify({ s: src });
  const b = bracket(payload);
  return PRELUDE + [
    '',
    'local new = game:GetService("HttpService"):JSONDecode(' + b[0] + payload + b[1] + ').s',
    'local inst = RBX.find("' + ipath + '")',
    'if not inst:IsA("LuaSourceContainer") then error("not a script: ' + ipath + '") end',
    'RBX.src(inst, new)',
    'local back = inst.Source',
    'return { len = #back, hash = RBX.hash(back) }'
  ].join('\n');
}

export function editCode(ipath, oldS, newS) {
  const payload = JSON.stringify({ o: oldS, n: newS });
  const b = bracket(payload);
  return PRELUDE + [
    '',
    'local p = game:GetService("HttpService"):JSONDecode(' + b[0] + payload + b[1] + ')',
    'local inst = RBX.find("' + ipath + '")',
    'local src = inst.Source',
    'local n, i = 0, 1',
    'while true do local s,e = string.find(src, p.o, i, true); if not s then break end; n = n + 1; i = e + 1 end',
    'if n == 0 then return { ok = false, why = "anchor not found", count = 0 } end',
    'if n > 1 then return { ok = false, why = "anchor not unique", count = n } end',
    'local s,e = string.find(src, p.o, 1, true)',
    'local out = string.sub(src,1,s-1) .. p.n .. string.sub(src,e+1)',
    'RBX.src(inst, out)',
    'local back = inst.Source',
    'return { ok = (back == out), len = #back, hash = RBX.hash(back), count = n }'
  ].join('\n');
}

export function searchCode(cfg) {
  const payload = JSON.stringify(cfg);
  const b = bracket(payload);
  const body = fs.readFileSync(path.join(HERE, 'search.lua'), 'utf8');
  return 'local CFG = game:GetService("HttpService"):JSONDecode(' + b[0] + payload + b[1] + ')\n' + body;
}

export function fmtSearch(out) {
  let r;
  try { r = JSON.parse(out); } catch { return out; }
  if (r.error) return 'ERROR: ' + r.error;
  if (r.defs) {
    const d = Array.isArray(r.defs) ? r.defs : Object.values(r.defs);
    return r.path + '  (' + r.lines + ' lines, ' + d.length + ' definitions)\n' + d.join('\n');
  }
  const h = r.hits ? (Array.isArray(r.hits) ? r.hits : Object.values(r.hits)) : [];
  if (!h.length) return 'no matches in ' + (r.matchedScripts + r.skippedScripts) + ' scripts' +
    (r.commentsIgnored ? ' (comments ignored - pass comments:true to include them)' : '');
  return h.join('\n') + '\n\n' + h.length + ' hits in ' + r.matchedScripts + ' scripts' +
    (r.commentsIgnored ? ', comments ignored' : ', comments included') +
    (r.truncated ? '. Stopped at the limit, so there may be more - narrow with path/word, or raise limit.' : '');
}

export const escapeLuauPattern = (s) => s.replace(/[%^$().[\]*+\-?]/g, '%$&');
