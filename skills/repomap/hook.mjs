#!/usr/bin/env node
// SessionStart hook: refresh the repo map when the session opens in a real project,
// and tell the model the map exists so it navigates from the index, not whole-file reads.
// Skips the home dir and any folder with no project marker, so it never maps all of $HOME.
import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join, parse } from "node:path";
import { homedir } from "node:os";

function bail() { process.exit(0); } // silent no-op: nothing injected

const cwd = process.cwd();
const home = homedir();
const rootOfDrive = parse(cwd).root.replace(/[\\/]+$/, "");

if (cwd === home || cwd.replace(/[\\/]+$/, "") === rootOfDrive) bail();

const MARKERS = [".git", "package.json", "pyproject.toml", "go.mod", "Cargo.toml", "deno.json", "pom.xml", "build.gradle"];
if (!MARKERS.some(m => existsSync(join(cwd, m)))) bail();

try {
	const out = execFileSync("node", [join(import.meta.dirname, "repomap.mjs"), cwd], {
		encoding: "utf8", timeout: 45000, maxBuffer: 64 * 1024 * 1024,
	}).trim();
	const context =
		`A repo map is ready at .repomap/map.md (${out.replace(/^map\.md:\s*/, "")}). ` +
		`To find or edit code, Grep .repomap/map.md for the symbol -> path + line -> windowed Read of that slice. ` +
		`Do not whole-file read to locate code, and do not grep the whole tree. Regenerate after structural edits: ` +
		`node "${join(import.meta.dirname, "repomap.mjs")}" "${cwd}"`;
	process.stdout.write(JSON.stringify({
		suppressOutput: true,
		hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: context },
	}));
} catch {
	bail();
}
