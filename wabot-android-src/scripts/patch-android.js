#!/usr/bin/env node
  /**
   * patch-android.js
   * Remplace les fichiers de commandes qui utilisent des modules
   * incompatibles Android (ffmpeg, sharp, canvas, puppeteer)
   * par des stubs qui répondent "non disponible sur mobile".
   */
  const fs   = require('fs');
  const path = require('path');

  const CORE_DIR = path.join(__dirname, '..', 'wabot-core');
  const INCOMPATIBLE = ['fluent-ffmpeg', 'sharp', 'canvas', 'puppeteer'];

  const STUB = `// Android stub — commande non disponible sur mobile
  module.exports = async function(conn, mek, m, extra) {
    try {
      const from = mek?.key?.remoteJid || (extra && extra.from);
      if (from && conn && conn.sendMessage) {
        await conn.sendMessage(from,
          { text: '❌ Cette commande n\\'est pas disponible sur mobile.' },
          { quoted: mek }
        );
      }
    } catch (_) {}
  };
  module.exports.default = module.exports;
  `;

  function patchDir(dir) {
    if (!fs.existsSync(dir)) return;
    for (const file of fs.readdirSync(dir)) {
      const full = path.join(dir, file);
      if (fs.statSync(full).isDirectory()) { patchDir(full); continue; }
      if (!file.endsWith('.js')) continue;
      const content = fs.readFileSync(full, 'utf8');
      const bad = INCOMPATIBLE.some(m =>
        content.includes(`require('${m}')`) ||
        content.includes(`require("${m}")`)
      );
      if (bad) {
        console.log('  ✂️  Patché:', full.replace(CORE_DIR + '/', ''));
        fs.writeFileSync(full, STUB);
      }
    }
  }

  console.log('\n🔧 Application des patches Android...');
  patchDir(path.join(CORE_DIR, 'commands'));
  patchDir(path.join(CORE_DIR, 'lib'));
  console.log('✅ Patches terminés\n');
  