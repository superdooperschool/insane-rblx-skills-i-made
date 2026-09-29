#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { connect, text as _text, PRELUDE, withPrelude, djb2, loose, writeCode, editCode, searchCode, fmtSearch, setImgDir, LAST_HEALTH as _LH } from './lib.mjs';

const HERE = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const PORT_CACHE = path.join(HERE, '.port');
const BIG = 4000;

const die = (m) => { console.error('rbx: ' + m); process.exit(1); };

function emit(s, outFile, label) {
  if (outFile && outFile !== true) {
    fs.writeFileSync(outFile, s);
    console.log((label || 'wrote') + ' ' + outFile + ' (' + s.length + ' chars, ' + s.split('\n').length + ' lines)');
    return;
  }
  if (s.length > BIG) {
    const f = path.join(os.tmpdir(), 'rbx-' + Date.now() + '.txt');
    fs.writeFileSync(f, s);
    console.log(s.slice(0, BIG));
    console.log('\n--- truncated at ' + BIG + ' chars. full output: ' + f + ' (' + s.length + ' chars) ---');
    return;
  }
  console.log(s);
}

const argv = process.argv.slice(2);
const cmd = argv.shift();
const flags = {};
const pos = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i].startsWith('--')) {
    const k = argv[i].slice(2);
    flags[k] = (argv[i + 1] && !argv[i + 1].startsWith('--')) ? argv[++i] : true;
  } else pos.push(argv[i]);
}
const readArg = (v) => (v === '-' ? fs.readFileSync(0, 'utf8') : fs.existsSync(v) ? fs.readFileSync(v, 'utf8') : v);

const USAGE = [
  'rbx <command>   (drives Roblox Studio directly, no MCP tool call)',
  '',
  '  health                            proxy port, studio count, open place',
  '  studios                           connected Studio instance ids',
  '  tools                             the 28 tool names',
  '  lua <file|-|inline> [--dm Edit]   run Luau, print the return value',
  '  call <tool> <json|file>           raw tools/call, any tool',
  '  read <game.Path> [--from N --to M] [--out f]',
  '  find <term> [--path P] [--word] [--i] [--comments] [--limit N]',
  '                                    literal search that SKIPS COMMENTS; exact script_read line numbers',
  '  outline <game.Path>               function definitions + line numbers, without reading the file',
  '  tree <path> [--type T] [--kw K] [--depth N] [--limit N]',
  '  write <game.Path> <file>          full rewrite via UpdateSourceAsync, hash-verified',
  '  edit <game.Path> --old f --new f  anchor uniqueness enforced, readback verified',
  '  console                           Studio output log',
  '',
  '  --studio <id>  pick instance when several are connected',
  '  --dm <Edit|Client|Server>   datamodel, default Edit',
  '',
  '  In lua/write/edit code, RBX helpers are available:',
  '    RBX.find(path)  RBX.set(inst,prop,val)  RBX.src(inst,new)  RBX.req(path)  RBX.hash(s)'
].join('\n');

if (!cmd || cmd === 'help' || cmd === '--help') { console.log(USAGE); process.exit(0); }

const C = await connect().catch((e) => die(e.message));
const list = await C.studios().catch(() => []);
const picked = flags.studio || (list.length === 1 ? list[0].id : null);
const SID = () => picked || die('multiple studios connected, pass --studio:\n' + list.map((s) => '  ' + s.id + '  ' + s.name).join('\n'));
if (flags.dir && flags.dir !== true) setImgDir(flags.dir);
const DM = flags.dm === true || !flags.dm ? 'Edit' : flags.dm;
const rawCall = (name, args) => C.rpc('tools/call', { name, arguments: Object.assign({ studio_id: SID() }, args) });

async function callTool(name, args) {
  const r = await rawCall(name, args);
  const t = text(r);
  if (/datamodel is not available/i.test(t) && name !== 'get_studio_state') {
    const st = text(await rawCall('get_studio_state', {}));
    r.__hint = '\n--- studio state: ' + st.replace(/\s+/g, ' ').trim() +
      '\n--- rerun with --dm <one of the available datamodels>, or stop Play first:' +
      '\n---   rbx call start_stop_play \'{"is_start":false}\'';
  }
  return r;
}
const text = (r) => _text(r) + (r.__hint || '');

try {
  switch (cmd) {
    case 'health': {
      console.log('port ' + C.port);
      console.log(_LH.trim());
      console.log(list.length ? list.map((s) => 'studio ' + s.id + '  ' + (s.name || '(NO PLACE OPEN)')).join('\n') : 'no studios registered');
      break;
    }
    case 'studios':
      console.log(list.length ? list.map((s) => s.id + '  ' + (s.name || '(NO PLACE OPEN)')).join('\n') : 'none');
      break;
    case 'tools': {
      const r = await C.rpc('tools/list', {});
      console.log(((r.result && r.result.tools) || []).map((t) => t.name).join('\n'));
      break;
    }
    case 'lua': {
      if (!pos[0]) die('lua needs a file, - for stdin, or inline code');
      emit(text(await callTool('execute_luau', { datamodel_type: DM, code: withPrelude(readArg(pos[0])) })), flags.out);
      break;
    }
    case 'call': {
      const tool = pos[0];
      if (!tool) die('call needs a tool name');
      emit(text(await callTool(tool, pos[1] ? JSON.parse(readArg(pos[1])) : {})), flags.out);
      break;
    }
    case 'read': {
      const args = { target_file: pos[0] };
      if (flags.from || flags.to) {
        args.should_read_entire_file = false;
        args.start_line_one_indexed = +(flags.from || 1);
        args.end_line_one_indexed_inclusive = +(flags.to || 100000);
      }
      emit(text(await callTool('script_read', args)), flags.out, 'read ->');
      break;
    }
    case 'grep':
    case 'find': {
      if (!pos[0]) die('find needs a term');
      const code = searchCode({
        term: pos[0], path: flags.path === true ? null : flags.path,
        word: !!flags.word, ignoreCase: !!flags.i,
        includeComments: !!flags.comments, limit: +(flags.limit || 100)
      });
      emit(fmtSearch(text(await callTool('execute_luau', { datamodel_type: DM, code }))), flags.out);
      break;
    }
    case 'outline': {
      if (!pos[0]) die('outline needs <game.Path>');
      const code = searchCode({ mode: 'outline', path: pos[0] });
      emit(fmtSearch(text(await callTool('execute_luau', { datamodel_type: DM, code }))), flags.out);
      break;
    }
    case 'tree': {
      const a = { datamodel_type: DM, max_depth: +(flags.depth || 3), head_limit: +(flags.limit || 200) };
      if (pos[0]) a.path = pos[0];
      if (flags.type) a.instance_type = flags.type;
      if (flags.kw) a.keywords = flags.kw;
      emit(text(await callTool('search_game_tree', a)), flags.out);
      break;
    }
    case 'console':
      emit(text(await callTool('get_console_output', {})), flags.out);
      break;
    case 'capture': {
      const a = { capture_id: pos[0] || 'ScreenCapture_1' };
      if (flags.from) a.camera_position = JSON.parse(flags.from);
      if (flags.at) a.look_at_position = JSON.parse(flags.at);
      console.log(text(await callTool('screen_capture', a)));
      break;
    }
    case 'write': {
      const ipath = pos[0], file = pos[1];
      if (!ipath || !file) die('write needs <game.Path> <file>');
      const src = fs.readFileSync(file, 'utf8');
      const out = text(await callTool('execute_luau', { datamodel_type: 'Edit', code: writeCode(ipath, src) }));
      const got = loose(out);
      const wantHash = djb2(src), wantLen = Buffer.byteLength(src);
      if (+got.hash === wantHash && +got.len === wantLen) {
        console.log('OK ' + ipath + '  ' + wantLen + ' bytes  hash ' + wantHash + ' verified');
      } else {
        console.log('UNVERIFIED WRITE. studio returned: ' + out);
        console.log('expected len=' + wantLen + ' hash=' + wantHash);
        process.exitCode = 2;
      }
      break;
    }
    case 'edit': {
      const ipath = pos[0];
      if (!ipath || !flags.old || !flags.new) die('edit needs <game.Path> --old <file|string> --new <file|string>');
      const code = editCode(ipath, readArg(flags.old), readArg(flags.new));
      const out = text(await callTool('execute_luau', { datamodel_type: 'Edit', code }));
      const got = loose(out);
      if (got.ok === true) console.log('OK ' + ipath + '  ' + got.len + ' bytes  hash ' + got.hash);
      else { console.log('EDIT FAILED: ' + out); process.exitCode = 2; }
      break;
    }
    default:
      console.log(USAGE);
  }
} catch (e) {
  die(e.message);
}
C.ws.onclose = () => process.exit(process.exitCode || 0);
C.ws.onerror = () => process.exit(process.exitCode || 0);
C.close();
setTimeout(() => process.exit(process.exitCode || 0), 1500).unref();
