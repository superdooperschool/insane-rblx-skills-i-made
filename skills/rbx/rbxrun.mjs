// Generic row runner: node rbxrun.mjs <dir>  reads <dir>/steps.json:
// { "lua": ["author.lua"], "scripts": [["game.Path","ModuleScript","file.lua"]], "edits": [["game.Path","old","new"]], "verify": "verify.lua" }
import fs from "fs"; import { execFileSync } from "child_process"; import { fileURLToPath } from "url";
const R = fileURLToPath(new URL("./rbx.mjs", import.meta.url)), D = process.argv[2];
const spec = JSON.parse(fs.readFileSync(`${D}/steps.json`, "utf8"));
const run = (args) => execFileSync("node", [R, ...args], { encoding: "utf8", maxBuffer: 1 << 24 }).trim();
let fails = 0;
const step = (name, fn) => {
  try { const out = fn(); const last = (out || "").split("\n").pop(); if (/^ERROR/m.test(out)) throw new Error(out); console.log("OK  ", name, last); return out; }
  catch (e) { fails++; console.log("FAIL", name, ((e.stdout || "") + (e.stderr || "") + e.message).slice(0, 600)); }
};
for (const f of spec.lua || []) step("lua " + f, () => run(["lua", `${D}/${f}`]));
for (const [p, cls, file] of spec.scripts || []) {
  step("create " + p, () => run(["call", "multi_edit", JSON.stringify({ file_path: p, className: cls, datamodel_type: "Edit", edits: [{ old_string: "", new_string: "return nil" }] })]));
  step("write " + p, () => run(["write", p, `${D}/${file}`]));
}
for (const [p, file] of spec.writes || []) step("write " + p, () => run(["write", p, `${D}/${file}`]));
(spec.edits || []).forEach(([p, o, n], i) => {
  fs.writeFileSync(`${D}/e${i}.old`, o); fs.writeFileSync(`${D}/e${i}.new`, n);
  step(`edit ${i} ${p.split(".").pop()}`, () => run(["edit", p, "--old", `${D}/e${i}.old`, "--new", `${D}/e${i}.new`]));
});
for (const f of spec.post || []) step("post " + f, () => run(["lua", `${D}/${f}`]));
if (spec.verify) { console.log("== verify"); try { const v = run(["lua", `${D}/${spec.verify}`]); console.log(v); if (/^ERROR/m.test(v)) { fails++; console.log("VERIFY FAIL (error in output)"); } } catch (e) { fails++; console.log("VERIFY FAIL", (e.stdout || "") + (e.stderr || "") + e.message); } }
console.log(fails ? `FAILED ${fails}` : "ALL OK");
process.exitCode = fails ? 1 : 0;
