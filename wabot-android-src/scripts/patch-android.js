#!/usr/bin/env node
/**
 * patch-android.js
 * 1) Stubbe les fichiers qui utilisent des modules incompatibles Android
 * 2) Corrige TOUS les chemins ./data/tmp hardcodés dans tout le repo WABOT
 */
const fs   = require('fs');
const path = require('path');

const CORE_DIR = path.join(__dirname, '..', 'wabot-core');

// Modules incompatibles Android (natifs C++, Python, binaires externes, etc.)
const INCOMPATIBLE = [
  'fluent-ffmpeg', 'sharp', 'canvas', 'puppeteer',
  'ruhend-scraper', 'mumaker',
  'node-webpmux', 'wa-sticker-formatter',
  'gtts', 'edge-tts',
  'file-type', 'human-readable',
  'sox', 'node-opus', 'opusscript',
  // fs-extra n'est pas dispo dans le bundle esbuild Android
  'fs-extra',
];

const STUB = `// Android stub — commande non disponible sur mobile
module.exports = async function(conn, mek, m, extra) {
  try {
    const from = (mek && mek.key && mek.key.remoteJid) || (extra && extra.from);
    if (from && conn && typeof conn.sendMessage === 'function') {
      await conn.sendMessage(from,
        { text: '❌ Cette commande n\\'est pas disponible sur Android.' },
        { quoted: mek }
      );
    }
  } catch (_) {}
};
module.exports.default      = module.exports;
module.exports.command      = module.exports;
module.exports.startHangman = async () => {};
module.exports.guessLetter  = async () => {};
module.exports.startTrivia  = async () => {};
module.exports.answerTrivia = async () => {};
`;

function hasIncompatible(content) {
  return INCOMPATIBLE.some(mod =>
    content.includes(`require('${mod}')`) ||
    content.includes(`require("${mod}")`) ||
    content.includes(`from '${mod}'`) ||
    content.includes(`from "${mod}"`)
  );
}

// ── Étape 1 : stub des modules incompatibles ─────────────────────────────────
function patchDir(dir) {
  if (!fs.existsSync(dir)) return;
  for (const file of fs.readdirSync(dir)) {
    const full = path.join(dir, file);
    if (fs.statSync(full).isDirectory()) { patchDir(full); continue; }
    if (!file.endsWith('.js') && !file.endsWith('.cjs')) continue;
    let content;
    try { content = fs.readFileSync(full, 'utf8'); }
    catch (_) { continue; }
    if (hasIncompatible(content)) {
      console.log('  ✂️  Stubbed:', full.replace(CORE_DIR + path.sep, ''));
      fs.writeFileSync(full, STUB);
    }
  }
}

// ── Étape 2 : fix global des chemins tmp hardcodés ───────────────────────────
// Remplace TOUTES les variantes de ./data/tmp par le bon chemin Android
// Compatible avec toute version future du repo WABOT.
const TMP_REPLACEMENT =
  "(process.env.WABOT_TEMP_DIR || require('path').join(require('os').tmpdir(), 'wabot-tmp'))";

// Patterns à remplacer (chaînes littérales dans le JS source)
const TMP_PATTERNS = [
  // './data/tmp'  ou  "./data/tmp"
  { re: /(['"])\.\/data\/tmp\1/g,           rep: TMP_REPLACEMENT },
  // '../data/tmp'  ou  "../data/tmp"
  { re: /(['"])\.\.\/data\/tmp\1/g,         rep: TMP_REPLACEMENT },
  // path.join(process.cwd(), 'data', 'tmp')
  { re: /path\.join\(\s*process\.cwd\(\)\s*,\s*['"]data['"]\s*,\s*['"]tmp['"]\s*\)/g,
    rep: TMP_REPLACEMENT },
  // path.join(__dirname, '..', 'data', 'tmp')
  { re: /path\.join\(\s*__dirname\s*,\s*['"]\.\.['"]\s*,\s*['"]data['"]\s*,\s*['"]tmp['"]\s*\)/g,
    rep: TMP_REPLACEMENT },
];

function fixTmpInFile(full) {
  let content;
  try { content = fs.readFileSync(full, 'utf8'); } catch (_) { return; }
  const original = content;

  // Remplace les patterns de chemin
  for (const { re, rep } of TMP_PATTERNS) {
    content = content.replace(re, rep);
  }

  // Entoure les mkdirSync au niveau module d'un try-catch
  // (lignes en dehors de toute fonction : commencent par "if (!fs.existsSync" ou "fs.mkdirSync")
  content = content.replace(
    /^(\s*)(if\s*\(!fs\.existsSync\([^)]+\)\)\s*fs\.mkdirSync\([^;]+;\s*)$/gm,
    '$1try { $2} catch (_) {}'
  );
  content = content.replace(
    /^(\s*)(fs\.mkdirSync\([^;]+;\s*)$/gm,
    '$1try { $2} catch (_) {}'
  );

  if (content !== original) {
    fs.writeFileSync(full, content);
    return true;
  }
  return false;
}

function fixTmpDir(dir) {
  if (!fs.existsSync(dir)) return;
  for (const file of fs.readdirSync(dir)) {
    const full = path.join(dir, file);
    if (fs.statSync(full).isDirectory()) { fixTmpDir(full); continue; }
    if (!file.endsWith('.js') && !file.endsWith('.cjs')) continue;
    if (fixTmpInFile(full)) {
      console.log('  📁 tmp path fixed:', full.replace(CORE_DIR + path.sep, ''));
    }
  }
}

// ── Run ───────────────────────────────────────────────────────────────────────
console.log('\n🔧 Étape 1 — Stub modules incompatibles Android...');
patchDir(path.join(CORE_DIR, 'commands'));
patchDir(path.join(CORE_DIR, 'lib'));
patchDir(path.join(CORE_DIR, 'serena-assistant'));
patchDir(path.join(CORE_DIR, 'services'));

console.log('\n🔧 Étape 2 — Fix global chemins ./data/tmp...');
fixTmpDir(path.join(CORE_DIR, 'commands'));
fixTmpDir(path.join(CORE_DIR, 'lib'));
fixTmpDir(path.join(CORE_DIR, 'serena-assistant'));
fixTmpDir(path.join(CORE_DIR, 'services'));
fixTmpDir(path.join(CORE_DIR, 'config'));

console.log('\n✅ Patches Android terminés\n');
