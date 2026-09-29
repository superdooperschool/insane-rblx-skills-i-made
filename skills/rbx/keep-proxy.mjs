import { spawn } from 'node:child_process';

// StudioMCP exits on stdin EOF; this detached host keeps its pipe open.
const proxy = spawn(process.argv[2], [], {
  windowsHide: true,
  stdio: ['pipe', 'ignore', 'ignore'],
});
proxy.on('error', () => process.exit(1));
proxy.on('exit', code => process.exit(code ?? 1));
proxy.stdin.on('error', () => process.exit(1));
proxy.stdin.write(JSON.stringify({
  jsonrpc: '2.0', id: 1, method: 'initialize',
  params: {
    protocolVersion: '2024-11-05', capabilities: {},
    clientInfo: { name: 'rbx-proxy-host', version: '1.0' },
  },
}) + '\n');
proxy.stdin.write(JSON.stringify({
  jsonrpc: '2.0', method: 'notifications/initialized',
}) + '\n');
