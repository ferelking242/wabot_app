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
          const body =
            msg.message?.conversation ||
            msg.message?.extendedTextMessage?.text ||
            msg.message?.imageMessage?.caption || '';
          if (!body) continue;

          addLog('INFO', 'Message de ' + from.replace('@s.whatsapp.net','') + ': ' + body.slice(0, 80));

          const cmd = body.trim().toLowerCase();
          try {
            if (cmd === '.ping') {
              await sock.sendMessage(from, { text: '🏓 Pong! Bot actif ✅' });
              addLog('SUCCESS', 'Commande .ping → réponse envoyée');
            } else if (cmd === '.help') {
              const help =
                '🤖 *Wabot - Commandes disponibles*\n\n' +
                '▸ *.ping* - Vérifier si le bot est actif\n' +
                '▸ *.help* - Afficher cette aide\n\n' +
                '_Bot connecté et fonctionnel_ ✅';
              await sock.sendMessage(from, { text: help });
              addLog('SUCCESS', 'Commande .help → réponse envoyée');
            }
          } catch (e) {
            addLog('ERROR', 'Erreur réponse: ' + e.message);
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
