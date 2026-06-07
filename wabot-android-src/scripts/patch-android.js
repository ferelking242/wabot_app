#!/usr/bin/env node
/**
 * patch-android.js
 * Remplace les fichiers de commandes qui utilisent des modules
 * incompatibles Android par des stubs "non disponible sur mobile".
 */
const fs   = require('fs');
const path = require('path');

const CORE_DIR = path.join(__dirname, '..', 'wabot-core');

// Modules incompatibles Android (natifs C++, Python, binaires externes)
// NB: quand esbuild les marque --external, ils restent comme require() dans
//     le bundle → crash au runtime si appelés au top-level d'un fichier chargé
//     par commandHandler.js. On stubbe les fichiers qui les utilisent.
const INCOMPATIBLE = [
  // Traitement media natif
  'fluent-ffmpeg', 'sharp', 'canvas', 'puppeteer',
  // Scrapers / libs externes
  'ruhend-scraper', 'mumaker',
  // WebP
  'node-webpmux', 'wa-sticker-formatter',
  // TTS Python/binaire
  'gtts', 'edge-tts',
  // Utilitaires avec deps natives potentielles
  'file-type', 'human-readable',
  // Autres binaires
  'sox', 'node-opus', 'opusscript',
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
      console.log('  ✂️  Patché:', full.replace(CORE_DIR + path.sep, ''));
      fs.writeFileSync(full, STUB);
    }
  }
}

console.log('\n🔧 Application des patches Android...');
patchDir(path.join(CORE_DIR, 'commands'));
patchDir(path.join(CORE_DIR, 'lib'));
patchDir(path.join(CORE_DIR, 'serena-assistant'));
patchDir(path.join(CORE_DIR, 'services'));
console.log('✅ Patches terminés\n');
