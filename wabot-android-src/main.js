'use strict';
process.env.NODE_ENV = 'production';

// ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂ nodejs-mobile polyfills ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂ
// nodejs-mobile is compiled without ICU and without full Web APIs.
// All patches must run BEFORE any require() so baileys never sees the broken APIs.

// 1. TextDecoder: `fatal` option not supported without ICU ÃÂ¢ÃÂÃÂ strip it silently.
;(function patchTextDecoder() {
  if (typeof TextDecoder === 'undefined') return;
  const _Native = TextDecoder;
  global.TextDecoder = class TextDecoder extends _Native {
    constructor(label, options) {
      super(label, options ? { ...options, fatal: false } : options);
    }
  };
})();

// 2. globalThis.crypto / SubtleCrypto: missing in nodejs-mobile builds.
//    Try native Node.js webcrypto first; fall back to @peculiar/webcrypto (pure-JS).
;(function patchCrypto() {
  if (globalThis.crypto && globalThis.crypto.subtle) return; // already fine
  try {
    const { webcrypto } = require('crypto');
    if (webcrypto && webcrypto.subtle) {
      globalThis.crypto = webcrypto;
      return;
    }
  } catch (_) {}
  // Pure-JS WebCrypto polyfill ÃÂ¢ÃÂÃÂ covers all SubtleCrypto operations baileys needs.
  const { Crypto } = require('@peculiar/webcrypto');
  globalThis.crypto = new Crypto();
})();
// ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂ end polyfills ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂ

const { makeWASocket, DisconnectReason, useMultiFileAuthState, fetchLatestBaileysVersion } =
  require('@whiskeysockets/baileys');
const express = require('express');
const path    = require('path');
const fs      = require('fs');

const PORT     = parseInt(process.env.PORT     || '3001', 10);
const DATA_DIR = process.env.WABOT_DATA_DIR    || path.join(process.cwd(), 'data');
const AUTH_DIR = path.join(DATA_DIR, 'auth_state');
const API_KEY  = process.env.WABOT_AUTH_KEY    || 'wabot_embedded_v1';

// Minimal silent logger compatible with Baileys' pino interface
const noopLogger = {
  trace: () => {}, debug: () => {}, verbose: () => {},
  info:  console.log.bind(console),
  warn:  console.warn.bind(console),
  error: console.error.bind(console),
  fatal: console.error.bind(console),
  child: () => noopLogger,
  level: 'silent',
};

if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
if (!fs.existsSync(AUTH_DIR)) fs.mkdirSync(AUTH_DIR, { recursive: true });

const app = express();
app.use(express.json());

// Auth middleware (skip /v1/health)
app.use('/v1', (req, res, next) => {
  if (req.path === '/health') return next();
  const key = req.headers['x-api-key'] || req.query.key;
  if (key !== API_KEY) {
    return res.status(401).json({ success: false, error: 'UNAUTHORIZED' });
  }
  next();
});

// ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂ State ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂ
let sock            = null;
let lastQr          = null;
let lastQrTimestamp = null;
let isConnected     = false;
let botStarting     = false;
let qrCount         = 0;

  const botLogs = [];
  function addLog(level, msg) {
    botLogs.push({ level, message: msg, timestamp: new Date().toISOString() });
    if (botLogs.length > 500) botLogs.shift();
    console.log('[' + level + '] ' + msg);
  }


function clearAuthAndRestart() {
  try {
    if (fs.existsSync(AUTH_DIR)) {
      fs.rmSync(AUTH_DIR, { recursive: true, force: true });
      fs.mkdirSync(AUTH_DIR, { recursive: true });
      console.log('[Wabot] Auth state cleared');
    }
  } catch (err) {
    console.error('[Wabot] Clear error:', err.message);
  }
  sock        = null;
  lastQr      = null;
  isConnected = false;
  botStarting = false;
  qrCount     = 0;
  setTimeout(startBot, 1000);
}

// ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂ WhatsApp Connection ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂ
async function startBot() {
  if (botStarting) return;
  botStarting = true;
  try {
    const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
    const { version }          = await fetchLatestBaileysVersion();

    sock = makeWASocket({
      version,
      auth:                         state,
      printQRInTerminal:            false,
      browser:                      ['Wabot', 'Chrome', '120.0.0.0'],
      connectTimeoutMs:             60_000,
      keepAliveIntervalMs:          25_000,
      retryRequestDelayMs:          2_000,
      generateHighQualityLinkPreview: false,
      logger:                       noopLogger,
    });

    sock.ev.on('creds.update', saveCreds);

            // ── Message handler ──────────────────────────────────────────────
        sock.ev.on('messages.upsert', async ({ messages, type }) => {
          if (type !== 'notify') return;
          for (const msg of messages) {
            if (!msg.message || msg.key.fromMe) continue;
            const from = msg.key.remoteJid;
            const isGroup = from.endsWith('@g.us');
            const senderId = msg.key.participant || from;
            const body =
              msg.message?.conversation ||
              msg.message?.extendedTextMessage?.text ||
              msg.message?.imageMessage?.caption ||
              msg.message?.videoMessage?.caption || '';
            if (!body) continue;

            addLog('INFO', 'Msg de ' + (senderId.split('@')[0]) + ': ' + body.slice(0, 80));

            const PREFIX = '.';
            if (!body.trim().startsWith(PREFIX)) continue;

            const cmd = body.trim().toLowerCase().split(' ')[0];
            const args = body.trim().split(' ').slice(1);
            const argsText = args.join(' ');
            const ownerNumber = process.env.OWNER_NUMBER || '242065491040';
            const isOwner = senderId.includes(ownerNumber);

            try {
              switch (cmd) {
                case '.ping':
                  await sock.sendMessage(from, { text: '🏓 *Pong!* Bot actif ✅\n⏱️ Latence: ' + Math.round(Math.random()*30+10) + 'ms' }, { quoted: msg });
                  break;

                case '.help':
                case '.menu':
                case '.bot':
                  await sock.sendMessage(from, {
                    text: '🤖 *Wabot — Menu principal*\n\n' +
                      '*Système*\n' +
                      '▸ .ping — Vérifier si le bot est actif\n' +
                      '▸ .help — Afficher ce menu\n' +
                      '▸ .owner — Infos du propriétaire\n' +
                      '▸ .alive — Statut du bot\n\n' +
                      '*Groupe*\n' +
                      '▸ .tagall — Mentionner tous les membres\n' +
                      '▸ .groupinfo — Infos du groupe\n' +
                      '▸ .kick @user — Exclure un membre\n' +
                      '▸ .mute <min> — Muter le groupe\n' +
                      '▸ .unmute — Démuter le groupe\n' +
                      '▸ .promote @user — Promouvoir admin\n' +
                      '▸ .demote @user — Rétrograder admin\n\n' +
                      '*Fun*\n' +
                      '▸ .joke — Blague aléatoire\n' +
                      '▸ .quote — Citation inspirante\n' +
                      '▸ .fact — Fait insolite\n' +
                      '▸ .8ball <question> — Boule magique\n\n' +
                      '_Préfixe : ._ | _Version : 1.0_'
                  }, { quoted: msg });
                  break;

                case '.alive':
                  await sock.sendMessage(from, {
                    text: '✅ *Wabot est en ligne !*\n\n' +
                      '⏱️ Uptime: ' + Math.floor(process.uptime() / 3600) + 'h ' + Math.floor((process.uptime() % 3600) / 60) + 'min\n' +
                      '💾 RAM: ' + Math.round(process.memoryUsage().rss / 1024 / 1024) + 'MB\n' +
                      '📅 ' + new Date().toLocaleString('fr-FR')
                  }, { quoted: msg });
                  break;

                case '.owner':
                  await sock.sendMessage(from, {
                    text: '👑 *Propriétaire du bot*\n\n📱 +' + ownerNumber
                  }, { quoted: msg });
                  break;

                case '.groupinfo': {
                  if (!isGroup) { await sock.sendMessage(from, { text: '❌ Commande réservée aux groupes.' }, { quoted: msg }); break; }
                  try {
                    const meta = await sock.groupMetadata(from);
                    await sock.sendMessage(from, {
                      text: '📋 *Infos du groupe*\n\n' +
                        '📌 Nom: ' + meta.subject + '\n' +
                        '👥 Membres: ' + meta.participants.length + '\n' +
                        '📝 Description: ' + (meta.desc || 'Aucune') + '\n' +
                        '🔗 ID: ' + from
                    }, { quoted: msg });
                  } catch(e) { await sock.sendMessage(from, { text: '❌ Erreur: ' + e.message }, { quoted: msg }); }
                  break;
                }

                case '.tagall': {
                  if (!isGroup) { await sock.sendMessage(from, { text: '❌ Commande réservée aux groupes.' }, { quoted: msg }); break; }
                  try {
                    const meta = await sock.groupMetadata(from);
                    const mentions = meta.participants.map(p => p.id);
                    const text = '📢 *Attention tout le monde !*\n\n' + mentions.map(jid => '@' + jid.split('@')[0]).join(' ');
                    await sock.sendMessage(from, { text, mentions }, { quoted: msg });
                  } catch(e) { await sock.sendMessage(from, { text: '❌ Erreur: ' + e.message }, { quoted: msg }); }
                  break;
                }

                case '.kick': {
                  if (!isGroup) { await sock.sendMessage(from, { text: '❌ Commande réservée aux groupes.' }, { quoted: msg }); break; }
                  const mentioned = msg.message?.extendedTextMessage?.contextInfo?.mentionedJid || [];
                  if (!mentioned.length) { await sock.sendMessage(from, { text: '❌ Mentionnez un membre à exclure.' }, { quoted: msg }); break; }
                  try {
                    await sock.groupParticipantsUpdate(from, mentioned, 'remove');
                    await sock.sendMessage(from, { text: '✅ Membre(s) exclus du groupe.' }, { quoted: msg });
                  } catch(e) { await sock.sendMessage(from, { text: '❌ Erreur: ' + e.message }, { quoted: msg }); }
                  break;
                }

                case '.promote': {
                  if (!isGroup) { await sock.sendMessage(from, { text: '❌ Commande réservée aux groupes.' }, { quoted: msg }); break; }
                  const toPromote = msg.message?.extendedTextMessage?.contextInfo?.mentionedJid || [];
                  if (!toPromote.length) { await sock.sendMessage(from, { text: '❌ Mentionnez un membre à promouvoir.' }, { quoted: msg }); break; }
                  try {
                    await sock.groupParticipantsUpdate(from, toPromote, 'promote');
                    await sock.sendMessage(from, { text: '✅ Membre(s) promu(s) administrateur.' }, { quoted: msg });
                  } catch(e) { await sock.sendMessage(from, { text: '❌ Erreur: ' + e.message }, { quoted: msg }); }
                  break;
                }

                case '.demote': {
                  if (!isGroup) { await sock.sendMessage(from, { text: '❌ Commande réservée aux groupes.' }, { quoted: msg }); break; }
                  const toDemote = msg.message?.extendedTextMessage?.contextInfo?.mentionedJid || [];
                  if (!toDemote.length) { await sock.sendMessage(from, { text: '❌ Mentionnez un admin à rétrograder.' }, { quoted: msg }); break; }
                  try {
                    await sock.groupParticipantsUpdate(from, toDemote, 'demote');
                    await sock.sendMessage(from, { text: '✅ Admin(s) rétrogradé(s).' }, { quoted: msg });
                  } catch(e) { await sock.sendMessage(from, { text: '❌ Erreur: ' + e.message }, { quoted: msg }); }
                  break;
                }

                case '.mute': {
                  if (!isGroup) { await sock.sendMessage(from, { text: '❌ Commande réservée aux groupes.' }, { quoted: msg }); break; }
                  try {
                    await sock.groupSettingUpdate(from, 'announcement');
                    await sock.sendMessage(from, { text: '🔇 Groupe muté — seuls les admins peuvent écrire.' }, { quoted: msg });
                  } catch(e) { await sock.sendMessage(from, { text: '❌ Erreur: ' + e.message }, { quoted: msg }); }
                  break;
                }

                case '.unmute': {
                  if (!isGroup) { await sock.sendMessage(from, { text: '❌ Commande réservée aux groupes.' }, { quoted: msg }); break; }
                  try {
                    await sock.groupSettingUpdate(from, 'not_announcement');
                    await sock.sendMessage(from, { text: '🔊 Groupe démuté — tout le monde peut écrire.' }, { quoted: msg });
                  } catch(e) { await sock.sendMessage(from, { text: '❌ Erreur: ' + e.message }, { quoted: msg }); }
                  break;
                }

                case '.joke': {
                  const jokes = [
                    'Pourquoi les plongeurs plongent-ils toujours en arrière et jamais en avant ? Parce que sinon ils tomberaient dans le bateau ! 😂',
                    'Un homme entre dans une bibliothèque et demande un livre sur les tortues. La bibliothécaire lui dit: "Avec ou sans carapace?" Il répond: "Sans." Elle dit: "Désolé, nous n'avons que des livres reliés." 😄',
                    'Je voulais raconter une blague sur le papier, mais elle est déchirante. 📄😅',
                    'Qu'est-ce qu'un canif ? Un petit fien ! 🐕',
                    'Pourquoi Einstein n'avait-il pas d'amis ? Parce qu'il était trop relatif ! 🧪😂'
                  ];
                  await sock.sendMessage(from, { text: '😂 ' + jokes[Math.floor(Math.random() * jokes.length)] }, { quoted: msg });
                  break;
                }

                case '.quote': {
                  const quotes = [
                    '"La vie, c'est comme une bicyclette, il faut avancer pour ne pas perdre l'équilibre." — Einstein',
                    '"Le succès c'est tomber sept fois, se relever huit." — Proverbe japonais',
                    '"Sois le changement que tu veux voir dans le monde." — Gandhi',
                    '"Un voyage de mille lieues commence toujours par un premier pas." — Lao Tseu',
                    '"Il n'y a qu'une façon d'échouer, c'est d'abandonner avant d'avoir réussi." — Georges Clemenceau'
                  ];
                  await sock.sendMessage(from, { text: '💬 ' + quotes[Math.floor(Math.random() * quotes.length)] }, { quoted: msg });
                  break;
                }

                case '.fact': {
                  const facts = [
                    '🐙 Les pieuvres ont trois cœurs et du sang bleu.',
                    '🍯 Le miel ne se périme jamais — on en a trouvé dans des tombes égyptiennes vieilles de 3000 ans.',
                    '🦅 Un aigle peut voir un lapin à 3 km de distance.',
                    '🌙 La Lune s'éloigne de la Terre d'environ 3,8 cm par an.',
                    '🐘 Les éléphants sont les seuls animaux qui ne peuvent pas sauter.',
                    '🫀 Le cœur humain bat environ 100 000 fois par jour.'
                  ];
                  await sock.sendMessage(from, { text: facts[Math.floor(Math.random() * facts.length)] }, { quoted: msg });
                  break;
                }

                case '.8ball': {
                  if (!argsText) { await sock.sendMessage(from, { text: '❌ Posez une question ! Ex: .8ball Est-ce que je vais réussir ?' }, { quoted: msg }); break; }
                  const answers = ['✅ Oui, certainement !', '❌ Non, pas du tout.', '🤔 Peut-être...', '💯 Absolument !', '🚫 Définitivement non.', '⏳ Demande plus tard.', '🎯 Sans aucun doute !', '😅 Je ne suis pas sûr.'];
                  await sock.sendMessage(from, { text: '🎱 *Boule Magique*\n\nQuestion: ' + argsText + '\nRéponse: ' + answers[Math.floor(Math.random() * answers.length)] }, { quoted: msg });
                  break;
                }

                default:
                  // Commande inconnue — ne pas répondre pour éviter le spam
                  addLog('INFO', 'Commande inconnue: ' + cmd);
                  break;
              }
              addLog('SUCCESS', 'Commande ' + cmd + ' exécutée');
            } catch (e) {
              addLog('ERROR', 'Erreur commande ' + cmd + ': ' + e.message);
              try { await sock.sendMessage(from, { text: '❌ Erreur interne. Réessayez.' }, { quoted: msg }); } catch(_) {}
            }
          }
        });

    

    sock.ev.on('connection.update', ({ qr, connection, lastDisconnect }) => {
      if (qr) {
        lastQr          = qr;
        lastQrTimestamp = Date.now();
        qrCount++;
        console.log('[Wabot] QR code ready #' + qrCount);
        if (qrCount >= 3) {
          console.log('[Wabot] 3 QR sans connexion â reset auth state');
          qrCount = 0;
          sock?.end();
          setTimeout(clearAuthAndRestart, 500);
          return;
        }
      }
      if (connection === 'open') {
        isConnected = true;
        botStarting = false;
        lastQr      = null;
        qrCount     = 0;
        addLog('SUCCESS', 'WhatsApp connecté: ' + (sock?.user?.id || ''));
          console.log('[Wabot] Connected:', sock?.user?.id);
      }
      if (connection === 'close') {
        isConnected = false;
        botStarting = false;
        const code  = lastDisconnect?.error?.output?.statusCode;
        if (code !== DisconnectReason.loggedOut) {
          console.log('[Wabot] Reconnecting in 5sÃÂ¢ÃÂÃÂ¦');
          setTimeout(startBot, 5_000);
        } else {
          console.log('[Wabot] Logged out ÃÂ¢ÃÂÃÂ delete auth_state to re-pair');
        }
      }
    });
  } catch (err) {
    botStarting = false;
    console.error('[Wabot] Start error:', err.message);
    setTimeout(startBot, 10_000);
  }
}

// ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂ Routes ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂ

app.get('/api/v1/health', (_req, res) =>
  res.json({ ok: true, version: '1.0.0-android' }));

app.get('/api/v1/instance/status', (_req, res) => {
  const mem = process.memoryUsage();
  res.json({
    success: true,
    instance: {
      connected: isConnected,
      phone:    sock?.user?.id?.replace(/:.*@/, '@') || null,
      name:     sock?.user?.name || null,
      platform: 'Baileys-Android',
    },
    process: {
      uptime:  Math.floor(process.uptime()),
      pid:     process.pid,
      memory:  {
        rss:      `${Math.round(mem.rss / 1024 / 1024)} MB`,
        heapUsed: `${Math.round(mem.heapUsed / 1024 / 1024)} MB`,
      },
      node: process.version,
    },
    timestamp: new Date().toISOString(),
  });
});

app.get('/api/v1/instance/qr', async (_req, res) => {
  if (isConnected)
    return res.json({ success: true, connected: true });
  if (!lastQr)
    return res.status(503).json({
      success: false, error: 'QR_NOT_AVAILABLE',
      message: 'QR not yet generated. Bot startingÃÂ¢ÃÂÃÂ¦',
    });
  const ageSeconds = Math.floor((Date.now() - lastQrTimestamp) / 1000);
  if (ageSeconds > 60)
    return res.status(410).json({ success: false, error: 'QR_EXPIRED', ageSeconds });
  try {
    const qrcode = require('qrcode');
    const png = await qrcode.toDataURL(lastQr, { type: 'image/png', width: 300 });
    res.json({
      success: true, connected: false,
      qr: lastQr, qrImage: png,
      ageSeconds, expiresInSeconds: 60 - ageSeconds,
    });
  } catch (err) {
    res.status(500).json({ success: false, error: 'QR_FAILED', message: err.message });
  }
});

app.post('/api/v1/instance/pair', async (req, res) => {
  if (isConnected) return res.json({ success: true, connected: true });
  const { phone } = req.body;
  if (!phone)
    return res.status(400).json({ success: false, error: 'MISSING_PHONE' });
  const cleanPhone = String(phone).replace(/[^\d]/g, '');
  if (!sock)
    return res.status(503).json({
      success: false, error: 'BOT_NOT_STARTED',
      message: 'Bot still starting. Retry in a moment.',
    });
  try {
    let code = await sock.requestPairingCode(cleanPhone);
    code = code?.match(/.{1,4}/g)?.join('-') || code;
    res.json({ success: true, code, phone: cleanPhone });
  } catch (err) {
    res.status(500).json({ success: false, error: 'PAIR_FAILED', message: err.message });
  }
});

app.post('/api/v1/instance/reconnect', (req, res) => {
  res.json({ success: true, message: 'ReconnectingÃÂ¢ÃÂÃÂ¦' });
  isConnected = false;
  botStarting = false;
  sock        = null;
  setTimeout(startBot, 500);
});

app.post('/api/v1/instance/reset', (_req, res) => {
  res.json({ success: true, message: 'Auth cleared, restarting...' });
  sock?.end();
  clearAuthAndRestart();
});

// ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂ Start ÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂÃÂ¢ÃÂÃÂ

  app.get('/api/v1/logs', (req, res) => {
    const limit = parseInt(req.query.limit) || 100;
    res.json(botLogs.slice(-limit).reverse());
  });
  
app.listen(PORT, '127.0.0.1', () => {
  console.log(`[Wabot-Android] API server started on port ${PORT}`);
  startBot();
});
