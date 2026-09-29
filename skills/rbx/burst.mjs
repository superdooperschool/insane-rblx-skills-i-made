import { spawn } from 'node:child_process';
import path from 'node:path';
const HERE = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const p = spawn('node', ['server.mjs'], { cwd: HERE });
let out = '';
p.stdout.on('data', (d) => { out += d; });
const send = (o) => p.stdin.write(JSON.stringify(o) + '\n');
send({ jsonrpc: '2.0', id: 0, method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'burst', version: '1' } } });
await new Promise((r) => setTimeout(r, 1500));
const N = 10;
for (let i = 1; i <= N; i++) send({ jsonrpc: '2.0', id: i, method: 'tools/call', params: { name: 'studio', arguments: { op: 'lua', args: { code: 'return {i=' + i + '}' } } } });
await new Promise((r) => setTimeout(r, 9000));
const ms = out.trim().split('\n').filter(Boolean).map(JSON.parse);
const missing = [];
for (let i = 1; i <= N; i++) if (!ms.some((m) => m.id === i)) missing.push(i);
const mismatched = ms.filter((m) => m.id > 0 && m.result?.content && m.result.content[0].text !== '{"i":' + m.id + '}');
p.stdin.end();
if (missing.length) { console.log('DROPPED ' + missing.join(',')); process.exit(1); }
if (mismatched.length) { console.log('MISMATCHED ' + mismatched.map((m) => m.id).join(',')); process.exit(1); }
console.log('OK all ' + N + ' answered and correctly paired');
process.exit(0);
