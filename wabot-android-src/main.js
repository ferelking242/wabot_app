'use strict';
process.env.NODE_ENV = 'production';

// ── Android polyfills ──────────────────────────────────────────────────────
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

// ── Env Android ────────────────────────────────────────────────────────────
const PORT     = parseInt(process.env.PORT || '3001', 10);
const DATA_DIR = process.env.WABOT_DATA_DIR || '/data/data/com.aivos.wabot.app/files/wabot';
const path     = require('path');
const AUTH_DIR = path.join(DATA_DIR, 'auth_state');

process.env.SUPABASE_URL              = process.env.SUPABASE_URL              || 'https://nublrlyhdbeoqimntdrl.supabase.co';
process.env.SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
process.env.SUPABASE_ANON_KEY         = process.env.SUPABASE_ANON_KEY         || '';
process.env.OWNER_NUMBER              = process.env.OWNER_NUMBER              || '242065491040';
process.env.BOT_NAME                  = process.env.BOT_NAME                  || 'Wabot';
process.env.THEME_EMOJI               = '•';
process.env.COMMAND_PREFIX            = '.';
process.env.WABOT_AUTH_DIR            = AUTH_DIR;
process.env.WABOT_STORE_FILE          = path.join(DATA_DIR, 'baileys_store.json');
process.env.WABOT_DATA_DIR            = DATA_DIR;

// ── Config WABOT ──────────────────────────────────────────────────────────
try { require('./wabot-core/config/config'); }
catch (e) { console.warn('[Android] config/config:', e.message); }

// ── Imports ────────────────────────────────────────────────────────────────
const {
  makeWASocket, DisconnectReason,
  useMultiFileAuthState, fetchLatestBaileysVersion,
  jidNormalizedUser
} = require('@whiskeysockets/baileys');
const { Boom }  = require('@hapi/boom');
const express   = require('express');
const fs        = require('fs');
const qrcode    = require('qrcode');
const { createClient } = require('@supabase/supabase-js');

// ── Supabase ───────────────────────────────────────────────────────────────
let supabase = null;
try {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (url && key) {
    supabase = createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } });
    console.log('[Android] Supabase configuré');
  }
} catch (e) { console.warn('[Android] Supabase init error:', e.message); }

// ── WABOT commandHandler ───────────────────────────────────────────────────
let buildMessageHandler = null;
try {
  buildMessageHandler = require('./wabot-core/lib/commandHandler').buildMessageHandler;
  console.log('[Android] buildMessageHandler chargé ✅');
} catch (e) {
  console.error('[Android] commandHandler ERREUR:', e.message);
  // Log la stack pour diagnostiquer le module qui plante
  if (e.stack) console.error(e.stack.split('\n').slice(0, 8).join('\n'));
}

// ── Store minimal ──────────────────────────────────────────────────────────
let store = null;
try {
  store = require('./wabot-core/lib/lightweight_store');
} catch (e) {
  store = {
    messages: {}, contacts: {}, chats: {},
    bind: () => {}, loadMessage: async () => null,
    readFromFile: () => {}, writeToFile: () => {},
  };
}

// ── Logs ───────────────────────────────────────────────────────────────────
const logs = [];
function addLog(level, msg) {
  const e = { level, msg, time: new Date().toISOString() };
  logs.push(e);
  if (logs.length > 300) logs.shift();
  console.log(`[${level}] ${msg}`);
}

// ── État global ────────────────────────────────────────────────────────────
let sock = null, lastQr = null, lastQrTs = 0, isConnected = false;
let botStarting = false, qrCount = 0, messageHandler = null;
let connectedPhone = '', connectedName = '', connectedJid = '';
let messagesTotal = 0;
const botStartTime = Date.now();

// ── Supabase session save/restore ─────────────────────────────────────────
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
    else addLog('INFO', 'Session Supabase sauvegardée ✅');
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
    addLog('INFO', 'Session Supabase restaurée ✅');
    return true;
  } catch (e) { return false; }
}

// ── Démarrage WhatsApp ────────────────────────────────────────────────────
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
    level: 'silent',
    trace: () => {}, debug: () => {}, info: () => {},
    warn:  m => addLog('WARN',  JSON.stringify(m).substring(0, 200)),
    error: m => addLog('ERROR', JSON.stringify(m).substring(0, 200)),
    fatal: m => addLog('ERROR', JSON.stringify(m).substring(0, 200)),
    child: () => silentLogger,
  };

  sock = makeWASocket({
    version, auth: state,
    printQRInTerminal: false,
    browser: ['Wabot', 'Chrome', '2.0.0'],
    logger: silentLogger,
    connectTimeoutMs: 60000,
    retryRequestDelayMs: 2000,
    msgRetryCounterCache: new Map(),
    getMessage: async (key) => {
      try {
        const jid = jidNormalizedUser(key.remoteJid);
        const msgs = store?.messages?.[jid];
        const m = Array.isArray(msgs) ? msgs.find(m => m.key?.id === key.id) : null;
        return m?.message || undefined;
      } catch (_) { return undefined; }
    }
  });

  try { store.bind(sock.ev); } catch (_) {}
  sock.ev.on('creds.update', saveCreds);

  // ── Construire le handler WABOT ─────────────────────────────────────────
  if (buildMessageHandler) {
    try {
      const ownerNum = process.env.OWNER_NUMBER || '242065491040';
      messageHandler = buildMessageHandler({
        prefix: '.',
        isOwner: (jid) => {
          if (!jid) return false;
          const digits = jid.replace(/[^0-9]/g, '');
          return digits.includes(ownerNum) || ownerNum.includes(digits.slice(-9));
        },
        botIdentity: 'main',
        featureFlags: { enableAutomations: true },
        channelInfo: { name: 'wabot-android', platform: 'android' }
      });
      addLog('INFO', 'Handler WABOT prêt ✅');
    } catch (e) {
      addLog('ERROR', 'buildMessageHandler crash: ' + e.message);
      if (e.stack) addLog('ERROR', e.stack.split('\n').slice(1, 4).join(' | '));
    }
  }

  // ── Messages entrants ───────────────────────────────────────────────────
  sock.ev.on('messages.upsert', async (chatUpdate) => {
    try {
      messagesTotal++;
      if (messageHandler) await messageHandler(sock, chatUpdate, true);
    } catch (e) {
      addLog('ERROR', 'Handler: ' + e.message.slice(0, 200));
    }
  });

  // ── Connexion ───────────────────────────────────────────────────────────
  sock.ev.on('connection.update', ({ qr, connection, lastDisconnect }) => {
    if (qr) {
      lastQr = qr; lastQrTs = Date.now(); qrCount++;
      addLog('INFO', 'QR #' + qrCount + ' généré');
      if (qrCount >= 5) {
        qrCount = 0;
        try { sock?.end(); } catch (_) {}
      }
    }

    if (connection === 'open') {
      isConnected  = true;
      botStarting  = false;
      lastQr       = null;
      qrCount      = 0;
      addLog('INFO', 'WhatsApp connecté ✅');

      const rawId = sock.user?.id || '';
      connectedJid   = rawId.includes(':') ? rawId.split(':')[0] + '@s.whatsapp.net' : rawId;
      connectedPhone = connectedJid.split('@')[0] || phone;
      connectedName  = sock.user?.name || 'Wabot';

      // ✅ FIX 1 : envoyer à SOI-MÊME (jid du bot), pas au owner
      sock.sendMessage(connectedJid, {
        text: '*Wabot Android actif !* 🟢\n\nConnecté : ' + new Date().toLocaleString('fr') +
              '\nNuméro : +' + connectedPhone +
              '\n\nTape *.help* pour voir les commandes disponibles.'
      }).catch(() => {});

      saveSession(connectedJid, connectedPhone).catch(() => {});
    }

    if (connection === 'close') {
      isConnected = false;
      botStarting = false;
      const err  = lastDisconnect?.error;
      const code = (new Boom(err))?.output?.statusCode;
      addLog('WARN', 'Connexion fermée — code: ' + code + ' | ' + (err?.message || ''));

      if (code === DisconnectReason.loggedOut) {
        addLog('INFO', 'Session expirée — suppression credentials');
        connectedPhone = ''; connectedName = ''; connectedJid = '';
        try { fs.rmSync(AUTH_DIR, { recursive: true, force: true }); } catch (_) {}
        setTimeout(() => startBot(), 2000);
      } else if (code === 401) {
        // 401 = unauthorized, même traitement que loggedOut
        addLog('WARN', 'Auth invalide — reset session');
        try { fs.rmSync(AUTH_DIR, { recursive: true, force: true }); } catch (_) {}
        setTimeout(() => startBot(), 3000);
      } else {
        // Reconnexion automatique (stream error, timeout, etc.)
        const delay = [515, 408, 503].includes(code) ? 3000 : 6000;
        addLog('INFO', 'Reconnexion dans ' + (delay / 1000) + 's...');
        setTimeout(() => startBot(), delay);
      }
    }
  });
}

// ── Express API (compatible format Flutter) ───────────────────────────────
const app = express();
app.use(express.json());

// Auth middleware (laxiste — clé optionnelle)
app.use('/api/v1', (req, res, next) => {
  const key = req.headers['x-api-key'] || req.query.api_key;
  if (key && key !== 'wabot_embedded_v1' && key !== 'wbk_dev') {
    return res.status(403).json({ success: false, error: 'UNAUTHORIZED' });
  }
  next();
});

app.get('/api/v1/health', (_, res) =>
  res.json({ ok: true, version: '2.1.0-android', uptime: process.uptime() }));

// ✅ FIX 2 : format { instance, process } attendu par Flutter
app.get('/api/v1/instance/status', (_, res) => {
  const mem = process.memoryUsage();
  res.json({
    success: true,
    // Format Flutter (getBotStatus) attend instance.connected
    instance: {
      connected:     isConnected,
      starting:      botStarting,
      phone:         connectedPhone || null,
      name:          connectedName  || 'Wabot',
      profilePicUrl: '',
    },
    // Format compatibilité legacy (direct)
    connected: isConnected,
    starting:  botStarting,
    // Infos process pour le dashboard
    process: {
      uptime: process.uptime(),
      node:   process.version,
      memory: {
        heapUsed: mem.heapUsed,
        heapTotal: mem.heapTotal,
        rss: mem.rss,
      },
    },
    stats: {
      messagesTotal,
      queueSize: 0,
    },
  });
});

// /api/v1/instance/info — informations bot
app.get('/api/v1/instance/info', (_, res) =>
  res.json({
    success: true,
    instance: {
      connected:   isConnected,
      phone:       connectedPhone || null,
      name:        connectedName  || 'Wabot',
      platform:    'android',
      version:     '2.1.0',
      nodeVersion: process.version,
    },
  })
);

// /api/v1/instance/qr — QR code
app.get('/api/v1/instance/qr', async (_, res) => {
  if (isConnected) return res.json({ success: true, connected: true });
  if (!lastQr)     return res.status(503).json({ success: false, error: 'QR_NOT_AVAILABLE', message: 'Bot en démarrage...' });
  const age = (Date.now() - lastQrTs) / 1000;
  if (age > 60)    return res.status(410).json({ success: false, error: 'QR_EXPIRED', ageSeconds: age });
  try {
    const qrImage = await qrcode.toDataURL(lastQr, { type: 'image/png', width: 300 });
    res.json({ success: true, connected: false, qr: lastQr, qrImage, ageSeconds: age });
  } catch (e) { res.status(500).json({ success: false, error: e.message }); }
});

// /api/v1/instance/reconnect
app.post('/api/v1/instance/reconnect', (_, res) => {
  try { sock?.end(); } catch (_) {}
  isConnected = false; botStarting = false; lastQr = null; qrCount = 0;
  setTimeout(() => startBot(), 800);
  res.json({ success: true, message: 'Reconnexion en cours...' });
});

// /api/v1/instance/reset — nouveau QR
app.post('/api/v1/instance/reset', (_, res) => {
  try { fs.rmSync(AUTH_DIR, { recursive: true, force: true }); } catch (_) {}
  try { sock?.end(); } catch (_) {}
  isConnected = false; botStarting = false; lastQr = null; qrCount = 0;
  connectedPhone = ''; connectedName = ''; connectedJid = '';
  setTimeout(() => startBot(), 1000);
  res.json({ success: true, message: 'Reset — nouveau QR en cours...' });
});

// /api/v1/instance/pair — pairing par numéro (si Baileys le supporte)
app.post('/api/v1/instance/pair', async (req, res) => {
  const { phone } = req.body || {};
  if (!phone) return res.status(400).json({ success: false, error: 'phone requis' });
  if (isConnected) return res.json({ success: true, connected: true });
  if (!sock) return res.status(503).json({ success: false, error: 'Bot non démarré' });
  try {
    const code = await sock.requestPairingCode(phone.replace(/[^0-9]/g, ''));
    res.json({ success: true, code });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

// /api/v1/logs
app.get('/api/v1/logs', (req, res) => {
  const limit = parseInt(req.query.limit || '100');
  res.json({ success: true, logs: logs.slice(-limit) });
});

// /api/v1/groups (stub pour Flutter)
app.get('/api/v1/groups', (_, res) =>
  res.json({ success: true, groups: [], total: 0 }));

// ── Démarrage ─────────────────────────────────────────────────────────────
app.listen(PORT, '127.0.0.1', () => {
  addLog('INFO', 'Wabot API sur le port ' + PORT);
  startBot();
});
