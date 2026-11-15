// Tower Climb — a make.fun roblox-game-01 entry (Node 22, standard library only).
//
// This program hands the game in. The game itself is the Rojo project in
// this directory: build it first with `rojo build default.project.json
// --output game.rbxl`, put three PNG screenshots in screenshots/ (the
// first by name is the cover) and fill in PLAY.json with the published
// place once the owner has made the experience Public on Roblox.
//
// This program copies game.rbxl, src/, screenshots/ and PLAY.json from
// beside this file to /output and writes /output/dossier.json, the summary
// the judge reads, with the vendored make.fun library.
//
// Outside the grader's container, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

// The scorer's own caps (reference/gate.json): only text_max_bytes shapes
// the bytes; the other caps refuse an entry the scorer would refuse —
// more than 4 screenshots or one over 256 KiB; a place of more than
// 500000 instances, whose scripts' sources come to over 8 MiB or whose
// scripts' paths come to over 1048576 characters, in all.
const DOSSIER_CAPS = {
  text_max_bytes: 65536,
  screenshots: { max: 4, max_bytes: 262144 },
  max_instances: 500000,
  scripts_max_source_bytes: 8388608,
  scripts_max_path_chars: 1048576,
} as const;

// Refuse to hand in a half-built entry: every deliverable must be here.
const requiredFiles = ['game.rbxl', 'PLAY.json'];
for (const file of requiredFiles) {
  if (!existsSync(join(here, file))) {
    throw new Error(`Tower Climb: missing ${file} — run \`rojo build default.project.json --output game.rbxl\` first and fill in PLAY.json.`);
  }
}
if (!existsSync(join(here, 'src')) || readdirSync(join(here, 'src')).length === 0) {
  throw new Error('Tower Climb: src/ is missing or empty — the Luau source is a required deliverable.');
}
const screenshots = existsSync(join(here, 'screenshots'))
  ? readdirSync(join(here, 'screenshots')).filter((name) => !name.startsWith('.') && statSync(join(here, 'screenshots', name)).isFile())
  : [];
if (screenshots.length < 3 || screenshots.length > 4) {
  throw new Error(`Tower Climb: screenshots/ must hold 3 or 4 images, found ${screenshots.length}.`);
}

// Copy the entry into /output, then write the dossier from what was copied.
mkdirSync(out, { recursive: true });
for (const file of requiredFiles) {
  copyFileSync(join(here, file), join(out, file));
}
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true });
mkdirSync(join(out, 'screenshots'), { recursive: true });
cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true });

writeFileSync(join(out, 'dossier.json'), buildDossier(out, DOSSIER_CAPS));

console.log(`Tower Climb: handed in ${screenshots.length} screenshots, src/ and game.rbxl to ${out}.`);
