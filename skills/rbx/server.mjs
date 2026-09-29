#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import * as L from './lib.mjs';

const MAX = 6000;
let C = null;
let STUDIOS = [];

const log = (m) => process.stderr.write('[rbx] ' + m + '\n');

async function conn() {
  if (C && C.ws.readyState === 1) return C;
  if (C) log('connection lost, reconnecting');
  C = null;
  STUDIOS = [];
  C = await L.connect();
  return C;
}

async function refreshStudios() {
  const c = await conn();
  STUDIOS = await c.studios().catch(() => []);
  return STUDIOS;
}

function sid(args) {
  if (args && args.studio_id) return args.studio_id;
  const open = STUDIOS.filter((s) => s.name);
  const pick = open.length ? open : STUDIOS;
  if (pick.length === 1) return pick[0].id;
  if (!pick.length) throw new Error('no Roblox Studio connected - open Studio and a place, then retry');
  throw new Error('several studios connected, pass studio_id: ' + pick.map((s) => s.id + ' (' + (s.name || 'no place open') + ')').join(', '));
}

async function raw(name, args) {
  for (let attempt = 0; attempt < 2; attempt++) {
    await refreshStudios();
    const c = await conn();
    try {
      return await c.rpc('tools/call', { name, arguments: Object.assign({ studio_id: sid(args) }, args) });
    } catch (e) {
      const retryable = /timeout|closed|failed|ECONNREFUSED|not running|no healthy/i.test(e.message);
      if (attempt === 1 || !retryable) throw e;
      log('call failed (' + e.message + '), rediscovering Studio');
      C = null;
      STUDIOS = [];
      L.forgetPort();
    }
  }
}

async function call(name, args) {
  const r = await raw(name, args);
  let t = L.text(r);
  if (/datamodel is not available/i.test(t) && name !== 'get_studio_state') {
    const st = L.text(await raw('get_studio_state', {}));
    t += '\n--- ' + st.replace(/\s+/g, ' ').trim() +
         '\n--- retry with that datamodel_type, or stop Play: op "start_stop_play", args {"is_start":false}';
  }
  return t;
}

function shrink(s, out) {
  if (out) { fs.writeFileSync(out, s); return 'wrote ' + out + ' (' + s.length + ' chars, ' + s.split('\n').length + ' lines). Grep it; do not read it whole.'; }
  if (s.length <= MAX) return s;
  const f = path.join(os.tmpdir(), 'rbx-' + Date.now() + '.txt');
  fs.writeFileSync(f, s);
  return s.slice(0, MAX) + '\n\n--- truncated. full ' + s.length + ' chars at: ' + f + '\n--- grep that file rather than re-running without a filter.';
}

const OPS = {
  async health() {
    await refreshStudios();
    return L.LAST_HEALTH.trim() + '\n' + (STUDIOS.length
      ? STUDIOS.map((s) => s.id + '  ' + (s.name || '(NO PLACE OPEN)')).join('\n')
      : 'no studios registered');
  },
  async studios() { await refreshStudios(); return STUDIOS.map((s) => s.id + '  ' + (s.name || '(NO PLACE OPEN)')).join('\n') || 'none'; },
  async help(a) {
    await conn();
    if (!a.op) return 'ops: ' + L.TOOLS.map((t) => t.name).join(', ');
    const t = L.TOOLS.find((x) => x.name === a.op);
    if (!t) return 'no such op: ' + a.op + '\nops: ' + L.TOOLS.map((x) => x.name).join(', ');
    return t.name + '\n' + t.description + '\nargs: ' + JSON.stringify(t.inputSchema.properties) + '\nrequired: ' + JSON.stringify(t.inputSchema.required);
  },
  lua: (a) => call('execute_luau', { datamodel_type: a.dm || 'Edit', code: L.withPrelude(a.code) }),
  read: (a) => call('script_read', a.from || a.to
    ? { target_file: a.path, should_read_entire_file: false, start_line_one_indexed: +(a.from || 1), end_line_one_indexed_inclusive: +(a.to || 100000) }
    : { target_file: a.path }),
  tree: (a) => call('search_game_tree', {
    datamodel_type: a.dm || 'Edit', path: a.path, instance_type: a.type, keywords: a.kw,
    max_depth: +(a.depth || 3), head_limit: +(a.limit || 200)
  }),
  console: () => call('get_console_output', {}),
  grep: async (a) => OPS.find(a),
  find: async (a) => L.fmtSearch(await call('execute_luau', { datamodel_type: a.dm || 'Edit', code: L.searchCode({
    term: a.term || a.q, path: a.path, word: !!a.word, ignoreCase: !!a.ignoreCase,
    includeComments: !!a.comments, limit: +(a.limit || 100) }) })),
  outline: async (a) => L.fmtSearch(await call('execute_luau', { datamodel_type: a.dm || 'Edit', code: L.searchCode({ mode: 'outline', path: a.path }) })),
  capture: (a) => { if (a.dir) L.setImgDir(a.dir); return call('screen_capture', { capture_id: a.id || 'ScreenCapture_1', camera_position: a.from, look_at_position: a.at }); },
  async write(a) {
    const src = a.source !== undefined ? a.source : fs.readFileSync(a.file, 'utf8');
    const out = await call('execute_luau', { datamodel_type: 'Edit', code: L.writeCode(a.path, src) });
    const got = L.loose(out);
    return (+got.hash === L.djb2(src) && +got.len === Buffer.byteLength(src))
      ? 'OK ' + a.path + '  ' + got.len + ' bytes  hash verified'
      : 'UNVERIFIED WRITE - studio said: ' + out + '\nexpected len=' + Buffer.byteLength(src) + ' hash=' + L.djb2(src);
  },
  async edit(a) {
    const out = await call('execute_luau', { datamodel_type: 'Edit', code: L.editCode(a.path, a.old, a.new) });
    const got = L.loose(out);
    return got.ok === true ? 'OK ' + a.path + '  ' + got.len + ' bytes' : 'EDIT FAILED: ' + out;
  }
};

const DESC = `Roblox Studio, all 28 tools behind one dispatch call. Set "op"; put that op's arguments in "args". studio_id is filled in automatically when one Studio is connected.

Preferred ops (these fix real bugs in the raw tools - use them instead of the raw equivalents):
  health                      -> proxy state, open place. Run first.
  lua    {code, dm?}          -> execute Luau (dm: Edit|Client|Server, default Edit). Batch many asserts into ONE call returning one table.
                                 Helpers available in code: RBX.find(path), RBX.set(inst,prop,val) (survives revert),
                                 RBX.src(inst,new), RBX.req(path) (fresh require, no stale cache), RBX.hash(s)
  read   {path, from?, to?}   -> script source. Use out:"file.lua" for anything large, then grep the file.
  find   {term, path?, word?, ignoreCase?, comments?, limit?}
                              -> literal search that SKIPS COMMENTS, with line numbers identical to read.
                                 Replaces script_grep, which is pattern-based (silently finds nothing for
                                 strings containing ( ) [ ] . - % + * ?), has line numbers offset from
                                 script_read, and matches inside comments. path scopes it to a subtree or
                                 one script; word forces identifier boundaries; comments:true opts them in.
  outline {path}              -> every function definition + line number, without reading the file.
                                 Do this before reading anything large, then read {from,to} one function.
  tree   {path, type?, kw?, depth?, limit?} -> filtered instance tree. Never call it unfiltered on a real place.
  write  {path, source|file}  -> full rewrite via UpdateSourceAsync, verified by hash readback. script.Source= does NOT sync.
  edit   {path, old, new}     -> one anchored edit; REFUSES a non-unique anchor. multi_edit is first-match-wins and
                                 its replace_all is a silent no-op - prefer this.
  capture {id?, dir?}         -> renders the viewport, saves a JPEG, returns the path. Read that path to see it.
  console                     -> Studio output log.

Any of the other 28 raw tools also work as an op, passing that tool's own arguments:
  execute_luau script_read script_grep script_search search_game_tree multi_edit inspect_instance
  get_console_output get_studio_state list_roblox_studios start_stop_play screen_capture subagent skill
  insert_asset search_asset http_get store_image upload_image segment_mesh run_as_job wait_job_finished
  generate_mesh generate_material generate_texture generate_procedural_model character_navigation
  user_mouse_input user_keyboard_input

  help {op?}  -> full argument schema for any op. Call this instead of guessing arguments.

Results over ${MAX} chars spill to a temp file and return the path - grep it rather than re-running unfiltered.`;

const TOOL = {
  name: 'studio',
  description: DESC,
  inputSchema: {
    type: 'object',
    properties: {
      op: { type: 'string', description: 'Operation name. See the list above; use op "help" for a schema.' },
      args: { type: 'object', description: "Arguments for that op. Omit for ops that take none.", additionalProperties: true },
      out: { type: 'string', description: 'Write the result to this absolute file path instead of returning it. Use for anything large.' }
    },
    required: ['op']
  }
};

async function dispatch(p) {
  const op = p.op;
  const a = p.args || {};
  if (OPS[op]) return shrink(String(await OPS[op](a)), p.out);
  await conn();
  if (!L.TOOLS.some((t) => t.name === op)) {
    return 'no such op: ' + op + '\nuse op "help" to list them.';
  }
  return shrink(await call(op, a), p.out);
}

const send = (m) => process.stdout.write(JSON.stringify(m) + '\n');
const ok = (id, result) => send({ jsonrpc: '2.0', id, result });

let stdinDone = false, pumping = false;
const queue = [];
const maybeExit = () => { if (stdinDone && !pumping && queue.length === 0) process.exit(0); };

async function handle(m) {
  if (m.method === 'initialize') {
    return ok(m.id, { protocolVersion: m.params?.protocolVersion || '2024-11-05', capabilities: { tools: {} }, serverInfo: { name: 'rbx', version: '1.0.0' } });
  }
  if (m.method === 'tools/list') return ok(m.id, { tools: [TOOL] });
  if (m.method === 'ping') return ok(m.id, {});
  if (m.method === 'tools/call') {
    if (m.params?.name !== 'studio') return ok(m.id, { content: [{ type: 'text', text: 'unknown tool: ' + m.params?.name }], isError: true });
    try {
      const t = await dispatch(m.params.arguments || {});
      return ok(m.id, { content: [{ type: 'text', text: t }], isError: /^ERROR:|^UNVERIFIED|^EDIT FAILED|^no such op/.test(t) });
    } catch (e) {
      return ok(m.id, { content: [{ type: 'text', text: 'ERROR: ' + e.message }], isError: true });
    }
  }
  if (m.id !== undefined && m.method) {
    return send({ jsonrpc: '2.0', id: m.id, error: { code: -32601, message: 'method not found: ' + m.method } });
  }
}

async function pump() {
  if (pumping) return;
  pumping = true;
  try {
    while (queue.length) {
      const line = queue.shift();
      let m;
      try { m = JSON.parse(line); } catch { continue; }
      try { await handle(m); } catch (e) { log('handler failed: ' + e.message); }
    }
  } finally {
    pumping = false;
    maybeExit();
  }
}

let buf = '';
process.stdin.on('data', (d) => {
  buf += d;
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim();
    buf = buf.slice(i + 1);
    if (line) queue.push(line);
  }
  pump();
});

process.stdin.on('end', () => { stdinDone = true; maybeExit(); });
log('rbx MCP server ready (1 tool, 28 ops)');
