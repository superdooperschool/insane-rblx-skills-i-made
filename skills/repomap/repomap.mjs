#!/usr/bin/env node
// repomap: compact, persisted symbol index of a codebase so an agent loads a map (~KB)
// instead of whole files (~MB). One rg pass, grouped by file. rg walks the tree and
// honours .gitignore, so node_modules/build output stay out for free.
import { execFileSync } from "node:child_process";
import { writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const root = process.argv[2] ? process.argv[2] : process.cwd();
const outDir = join(root, ".repomap");
const mapPath = join(outDir, "map.md");

const EXTS = "js,jsx,ts,tsx,mjs,cjs,py,lua,luau,go,rs,java,kt,c,h,cpp,hpp,cs,rb,php,swift,scala,sh";

const DECL = String.raw`^\s*(?:export\s+)?(?:default\s+)?(?:public\s+|private\s+|static\s+)*(?:async\s+)?(?:function\s+[\w$]+|class\s+[\w$]+|def\s+[\w$]+|func\s+(?:\([^)]*\)\s*)?[\w$]+|type\s+[\w$]+|struct\s+[\w$]+|enum\s+[\w$]+|trait\s+[\w$]+|interface\s+[\w$]+|impl\b[^{]*|module\s+[\w$]+|local\s+function\s+[\w.:$]+|(?:export\s+)?const\s+[\w$]+\s*=\s*(?:async\s*)?(?:\(|function|new\b)|[\w.$]+\s*[:=]\s*(?:async\s+)?function\b)`;

function rg(args) {
	try {
		return execFileSync("rg", args, { cwd: root, encoding: "utf8", maxBuffer: 512 * 1024 * 1024 });
	} catch (e) {
		if (e.status === 1) return "";
		throw e;
	}
}

// exclude build/vendor/minified even when the repo ships no .gitignore
const EXCLUDE = "node_modules,dist,build,.next,out,vendor,.git,coverage,__pycache__,.venv,venv,env,target,bin,obj,.cache,public/assets";
const PER_FILE_CAP = 80; // more than this = generated/minified noise, not a real module

// one pass: rg walks the tree, filters by extension glob, emits path:line:text
const raw = rg([
	"-nP", "--no-heading",
	"-g", `*.{${EXTS}}`,
	"-g", `!**/{${EXCLUDE}}/**`,
	"-g", "!**/*.min.*",
	"-g", "!**/*.bundle.*",
	"-e", DECL, ".",
]);

const byFile = new Map();
let symCount = 0;
for (const line of raw.split("\n")) {
	if (!line) continue;
	if (line.length > 400) continue; // minified line: one physical line, many "symbols"
	const m = line.match(/^(.*?):(\d+):(.*)$/);
	if (!m) continue;
	const [, path, ln, text] = m;
	if (text.length > 200) continue;
	const sym = text.trim().replace(/\s*[{(].*$/, "").replace(/\s+/g, " ").slice(0, 90);
	const rel = path.replace(/^\.[\\/]/, "");
	if (!byFile.has(rel)) byFile.set(rel, []);
	byFile.get(rel).push(`  L${ln} ${sym}`);
	symCount++;
}

const sections = [...byFile.keys()].sort().map(f => {
	let decls = byFile.get(f);
	if (decls.length > PER_FILE_CAP) {
		const extra = decls.length - PER_FILE_CAP;
		decls = decls.slice(0, PER_FILE_CAP).concat(`  ... (+${extra} more, likely generated)`);
	}
	return `## ${f}\n${decls.join("\n")}`;
});

const header = `# repo map: ${root.split(/[\\/]/).filter(Boolean).pop()}\n` +
	`# ${byFile.size} files, ${symCount} symbols. Regenerate: node repomap.mjs "${root}"\n` +
	`# Use: grep this file for a symbol -> path + LNN -> windowed Read only that slice. Never whole-file read.\n`;

mkdirSync(outDir, { recursive: true });
const out = header + "\n" + sections.join("\n\n") + "\n";
writeFileSync(mapPath, out);

const bytes = Buffer.byteLength(out);
console.log(`map.md: ${byFile.size} files, ${symCount} symbols, ~${Math.round(bytes / 1024)}KB (~${Math.round(bytes / 4)} tokens) -> ${mapPath}`);
