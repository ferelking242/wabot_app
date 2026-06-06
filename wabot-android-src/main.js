'use strict';
  process.env.NODE_ENV = 'production';

  // ── Android polyfills ────────────────────────────────────────────────
  ;(function patchTextDecoder() {
    if (typeof TextDecoder === 'undefined') return;
    const _N = TextDecoder;
    global.TextDecoder = class TextDecoder extends _N {
      constructor(l, o) { super(l, o ? { ...o, fatal: false } : o); }
    };
  })();

  ;(function patchCrypto() {
    if (globalThis.crypto?.subtle) return;
    try {
      const { webcrypto } = require('crypto');
      if (webcrypto?.subtle) { globalThis.crypto = webcrypto; return; }
    } catch (_) {}
    try {
      const { Crypto } = require('@peculiar/webcrypto');
      globalThis.crypto = new Crypto();
    } catch (_) {}
  })();

  // ── Env Android ──────────────────────────────────────────────────────
  const PORT     = parseInt(process.env.PORT || '3001', 10);
  const DATA_DIR = process.env.WABOT_DATA_DIR || '/data/data/com.aivos.wabot.app/files/wabot';
  const path     = require('path');
  const AUTH_DIR = path.join(DATA_DIR, 'auth_state');

  // Variables que le cœur WABOT attend
  process.env.SUPABASE_URL              = process.env.SUPABASE_URL              || 'https://nublrlyhdbeoqimntdrl.supabase.co';
  process.env.SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
  process.env.SUPABASE_ANON_KEY         = process.env.SUPABASE_ANON_KEY         || '';
  process.env.OWNER_NUMBER              = process.env.OWNER_NUMBER              || '242065491040';
  process.env.BOT_NAME                  = process.env.BOT_NAME                  || 'wabot';
  process.env.THEME_EMOJI               = '•';
  process.env.COMMAND_PREFIX            = '.';
  // Chemins Android pour le store et l'auth
  process.env.WABOT_AUTH_DIR   = AUTH_DIR;
  process.env.WABOT_STORE_FILE = path.join(DATA_DIR, 'baileys_store.json');
  process.env.WABOT_DATA_DIR   = DATA_DIR;

  // ── Charger la config WABOT (pose global.APIs etc.) ──────────────────
  try { require('./wabot-core/config/config'); }
  catch (e) { console.warn('[Android] config/config:', e.message); }

  // ── Imports ──────────────────────────────────────────────────────────
  const {
    makeWASocket, DisconnectReason,
    useMultiFileAuthState, fetchLatestBaileysVersion,
    makeCacheableSignalKeyStore, makeInMemoryStore,
    jidNormalizedUser
  } = require('@whiskeysockets/baileys');
  const { Boom }    = require('@hapi/boom');
  const express     = require('express');
  const fs          = require('fs');
  const qrcode      = require('qrcode');
  const { createClient } = require('@supabase/supabase-js');

  // ── Supabase (session save) ───────────────────────────────────────────
  let supabase = null;
  try {
    const url = process.env.SUPABASE_URL;
    const key = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (url && key) {
      supabase = createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } });
      console.log('[Android] Supabase configuré');
    } else {
      console.warn('[Android] Supabase non configuré — sessions ne seront pas sauvegardées');
    }
  } catch (e) { console.warn('[Android] Supabase init error:', e.message); }

  // ── WABOT commandHandler ──────────────────────────────────────────────
  let buildMessageHandler = null;
  try {
    buildMessageHandler = require('./wabot-core/lib/commandHandler').buildMessageHandler;
    console.log('[Android] buildMessageHandler chargé ✅');
  } catch (e) {
    console.error('[Android] Impossible de charger commandHandler:', e.message);
  }

  // ── Lightweight store (pour quotedMessages etc.) ──────────────────────
  let store = null;
  try {
    store = require('./wabot-core/lib/lightweight_store');
  } catch (e) {
    // Store minimal de secours
    store = {
      messages: {}, contacts: {}, chats: {},
      bind: () => {},
      loadMessage: async () => null,
      readFromFile: () => {},
      writeToFile: () => {},
    };
  }

  // ── Logs en mémoire ───────────────────────────────────────────────────
  const logs = [];
  function addLog(level, msg) {
    const e = { level, msg, time: new Date().toISOString() };
    logs.push(e);
    if (logs.length > 300) logs.shift();
    console.log(`[${level}] ${msg}`);
  }

  // ── Etat du bot ───────────────────────────────────────────────────────
  let sock = null, lastQr = null, lastQrTs = 0, isConnected = false;
  let botStarting = false, qrCount = 0, messageHandler = null;

  // ── Gestion de session Supabase ───────────────────────────────────────
  async function saveSession(jid, phone) {
    if (!supabase) return;
    try {
      const files = {};
      if (fs.existsSync(AUTH_DIR)) {
        fs.readdirSync(AUTH_DIR).forEach(f => {
          const fp = path.join(AUTH_DIR, f);
          if (fs.statSync(fp).isFile())
            files[f] = Buffer.from(fs.readFileSync(fp)).toString('base64');
        });
      }
      const { error } = await supabase.from('wabot_devices').upsert({
        whatsapp_jid: jid, whatsapp_phone: phone,
        session_data: files, bot_status: 'connected',
        last_seen: new Date().toISOString(), platform: 'android',
      }, { onConflict: 'whatsapp_jid' });
      if (error) addLog('WARN', 'Session save: ' + error.message);
      else addLog('INFO', 'Session sauvegardée dans Supabase ✅');
    } catch (e) { addLog('WARN', 'saveSession: ' + e.message); }
  }

  async function restoreSession(phone) {
    if (!supabase || !phone) return false;
    try {
      const { data, error } = await supabase
        .from('wabot_devices').select('session_data')
        .eq('whatsapp_phone', phone).single();
      if (error || !data?.session_data) return false;
      fs.mkdirSync(AUTH_DIR, { recursive: true });
      for (const [f, b64] of Object.entries(data.session_data))
        fs.writeFileSync(path.join(AUTH_DIR, f), Buffer.from(b64, 'base64'));
      addLog('INFO', 'Session restaurée depuis Supabase ✅');
      return true;
    } catch (e) { return false; }
  }

  // ── Démarrage WhatsApp ────────────────────────────────────────────────
  async function startBot() {
    if (botStarting || isConnected) return;
    botStarting = true;
    addLog('INFO', 'Démarrage du bot...');
    fs.mkdirSync(AUTH_DIR, { recursive: true });
    fs.mkdirSync(DATA_DIR, { recursive: true });

    const phone = process.env.WHATSAPP_PHONE_NUMBER || '';
    if (phone) await restoreSession(phone);

    let state, saveCreds;
    try {
      const creds = await useMultiFileAuthState(AUTH_DIR);
      state = creds.state; saveCreds = creds.saveCreds;
    } catch (e) {
      addLog('ERROR', 'useMultiFileAuthState: ' + e.message);
      botStarting = false;
      return setTimeout(() => startBot(), 5000);
    }

    const { version } = await fetchLatestBaileysVersion();
    const silentLogger = {
      level: 'silent', trace: () => {}, debug: () => {}, info: () => {},
      warn: m => addLog('WARN', JSON.stringify(m)),
      error: m => addLog('ERROR', JSON.stringify(m)),
      fatal: m => addLog('ERROR', JSON.stringify(m)),
      child: () => silentLogger,
    };

    sock = makeWASocket({
      version, auth: state,
      printQRInTerminal: false,
      browser: ['Wabot', 'Chrome', '2.0.0'],
      logger: silentLogger,
      connectTimeoutMs: 30000,
      retryRequestDelayMs: 2000,
      msgRetryCounterCache: new Map(),
      getMessage: async (key) => {
        const jid = jidNormalizedUser(key.remoteJid);
        const msg = store?.messages?.[jid]?.find?.(m => m.key?.id === key.id);
        return msg?.message || undefined;
      }
    });

    // Lier le store aux events
    try { store.bind(sock.ev); } catch(_) {}

    sock.ev.on('creds.update', saveCreds);

    // Construire le handler WABOT
    if (buildMessageHandler) {
      try {
        const ownerNum = process.env.OWNER_NUMBER || '242065491040';
        messageHandler = buildMessageHandler({
          prefix: '.',
          isOwner: (jid) => jid && jid.replace(/[^0-9]/g, '').includes(ownerNum),
          botIdentity: 'main',
          featureFlags: { enableAutomations: true },
          channelInfo: { name: 'wabot-android', platform: 'android' }
        });
        addLog('INFO', 'Handler WABOT chargé ✅');
      } catch (e) {
        addLog('ERROR', 'buildMessageHandler: ' + e.message);
      }
    }

    // Traitement des messages
    sock.ev.on('messages.upsert', async (chatUpdate) => {
      try {
        if (messageHandler) await messageHandler(sock, chatUpdate, true);
      } catch (e) {
        addLog('ERROR', 'MessageHandler: ' + e.message.slice(0, 200));
      }
    });

    // Gestion connexion
    sock.ev.on('connection.update', ({ qr, connection, lastDisconnect }) => {
      if (qr) {
        lastQr = qr; lastQrTs = Date.now(); qrCount++;
        addLog('INFO', 'QR #' + qrCount + ' généré');
        if (qrCount >= 4) { qrCount = 0; try { sock?.end(); } catch(_) {} }
      }
      if (connection === 'open') {
        isConnected = true; botStarting = false; lastQr = null; qrCount = 0;
        addLog('INFO', 'WhatsApp connecté ✅');
        const rawId = sock.user?.id || '';
        const jid   = rawId.includes(':') ? rawId.split(':')[0] + '@s.whatsapp.net' : rawId;
        const connPhone = jid.split('@')[0] || phone;
        saveSession(jid, connPhone).catch(() => {});
        const ownerJid = (process.env.OWNER_NUMBER || '242065491040') + '@s.whatsapp.net';
        sock.sendMessage(ownerJid, {
          text: '*Wabot Android v2 actif !*\n\nConnecté: ' + new Date().toLocaleString('fr') +
                '\nNuméro: +' + connPhone + '\n\nTape *.help* pour voir les commandes'
        }).catch(() => {});
      }
      if (connection === 'close') {
        isConnected = false; botStarting = false;
        const code = new Boom(lastDisconnect?.error)?.output?.statusCode;
        addLog('WARN', 'Connexion fermée, code: ' + code);
        if (code === DisconnectReason.loggedOut) {
          addLog('INFO', 'Déconnecté — suppression session');
          try { fs.rmSync(AUTH_DIR, { recursive: true, force: true }); } catch(_) {}
          setTimeout(() => startBot(), 2000);
        } else {
          setTimeout(() => startBot(), 5000);
        }
      }
    });
  }

  // ── Express HTTP server pour Flutter ─────────────────────────────────
  const app = express();
  app.use(express.json());

  app.use('/api/v1', (req, res, next) => {
    const key = req.headers['x-api-key'] || req.query.api_key;
    if (key && key !== 'wabot_embedded_v1' && key !== 'wbk_dev') {
      return res.status(403).json({ success: false, error: 'UNAUTHORIZED' });
    }
    next();
  });

  app.get('/api/v1/health', (_, res) =>
    res.json({ ok: true, version: '2.0.0-android', uptime: process.uptime() }));

  app.get('/api/v1/instance/status', (_, res) =>
    res.json({ success: true, connected: isConnected, starting: botStarting, phone: sock?.user?.id || null }));

  app.get('/api/v1/instance/qr', async (_, res) => {
    if (isConnected) return res.json({ success: true, connected: true });
    if (!lastQr)     return res.status(503).json({ success: false, error: 'QR_NOT_AVAILABLE', message: 'Bot en cours de démarrage...' });
    const age = (Date.now() - lastQrTs) / 1000;
    if (age > 60)    return res.status(410).json({ success: false, error: 'QR_EXPIRED', ageSeconds: age });
    try {
      const qrImage = await qrcode.toDataURL(lastQr, { type: 'image/png', width: 300 });
      res.json({ success: true, connected: false, qr: lastQr, qrImage, ageSeconds: age });
    } catch (e) { res.status(500).json({ success: false, error: e.message }); }
  });

  app.post('/api/v1/instance/reconnect', (_, res) => {
    try { sock?.end(); } catch(_) {}
    isConnected = false; botStarting = false; lastQr = null; qrCount = 0;
    setTimeout(() => startBot(), 800);
    res.json({ success: true, message: 'Reconnexion en cours...' });
  });

  app.post('/api/v1/instance/reset', (_, res) => {
    try { fs.rmSync(AUTH_DIR, { recursive: true, force: true }); } catch(_) {}
    try { sock?.end(); } catch(_) {}
    isConnected = false; botStarting = false; lastQr = null; qrCount = 0;
    setTimeout(() => startBot(), 1000);
    res.json({ success: true, message: 'Reset effectué — nouveau QR en cours...' });
  });

  app.get('/api/v1/logs', (req, res) => {
    const limit = parseInt(req.query.limit || '100');
    res.json({ success: true, logs: logs.slice(-limit) });
  });

  app.listen(PORT, '127.0.0.1', () => {
    addLog('INFO', `Wabot Android API démarré sur port ${PORT}`);
    startBot();
  });
  