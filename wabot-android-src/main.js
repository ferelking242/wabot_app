'use strict';
  process.env.NODE_ENV = 'production';

  // ── Handlers globaux — le process ne doit JAMAIS mourir ──────────────────
  process.on('uncaughtException', (err, origin) => {
    const msg = (err && err.message) ? err.message : String(err);
    _safeLog('ERROR', '[uncaughtException] ' + origin + ': ' + msg.slice(0, 300));
  });
  process.on('unhandledRejection', (reason) => {
    const msg = (reason instanceof Error) ? reason.message : String(reason);
    _safeLog('WARN', '[unhandledRejection] ' + msg.slice(0, 300));
  });

  // ── Polyfills Android ─────────────────────────────────────────────────────
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

  // ── Infos device Android (passées par MainActivity via env vars) ──────────
  const DEVICE_RAM_MB      = parseInt(process.env.DEVICE_TOTAL_RAM_MB    || '0',       10);
  const DEVICE_CPU_CORES   = parseInt(process.env.DEVICE_CPU_CORES       || '0',       10);
  const DEVICE_MODEL       = process.env.DEVICE_MODEL         || 'Android';
  const DEVICE_BRAND       = process.env.DEVICE_BRAND         || '';
  const DEVICE_MANUFACTURER= process.env.DEVICE_MANUFACTURER  || '';
  const DEVICE_ANDROID_VER = process.env.DEVICE_ANDROID_VERSION || '';
  const DEVICE_SDK_INT     = parseInt(process.env.DEVICE_SDK_INT        || '0',       10);
  const DEVICE_HARDWARE    = process.env.DEVICE_HARDWARE      || '';

  // ── Logs ───────────────────────────────────────────────────────────────────
  const logs = [];
  const LOG_DIR_INT = path.join(DATA_DIR, 'logs');
  const LOG_DIR_EXT = '/storage/emulated/0/wabot/logs';
  const fs = require('fs');

  function sanitize(str) {
    if (typeof str !== 'string') str = String(str);
    return str
      .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '')
      .replace(/\x1b\[[0-9;]*[mGKHF]/g, '')
      .substring(0, 400);
  }

  function _safeLog(level, msg) {
    try {
      const entry = { level, msg: sanitize(msg), time: new Date().toISOString() };
      logs.push(entry);
      if (logs.length > 300) logs.shift();
      console.log('[' + level + '] ' + entry.msg);
      _appendToLogFile(entry.time + ' [' + level + '] ' + entry.msg + '\n');
    } catch (_) {}
  }

  let _logFileInt = null, _logFileExt = null;
  function _initLogFile() {
    try {
      fs.mkdirSync(LOG_DIR_INT, { recursive: true });
      _logFileInt = path.join(LOG_DIR_INT, 'wabot_node.log');
    } catch (_) {}
    try {
      fs.mkdirSync(LOG_DIR_EXT, { recursive: true });
      _logFileExt = path.join(LOG_DIR_EXT, 'wabot_node.log');
    } catch (_) {}
  }

  function _appendToLogFile(line) {
    try { if (_logFileInt) fs.appendFileSync(_logFileInt, line); } catch (_) {}
    try { if (_logFileExt) fs.appendFileSync(_logFileExt, line); } catch (_) {}
  }

  // ── Safe require : tout module manquant retourne {} sans planter ──────────
  ;(function patchModuleLoad() {
    const Module = require('module');
    const _load  = Module._load.bind(Module);
    Module._load = function(request, parent, isMain) {
      try {
        return _load(request, parent, isMain);
      } catch (err) {
        if (err.code === 'MODULE_NOT_FOUND') {
          const stub = () => stub;
          stub.default = stub;
          stub.__esModule = true;
          stub.prototype = stub;
          ['connect','create','build','parse','encode','decode','load','get','set',
           'start','stop','run','execute','command','handler','process'].forEach(k => { stub[k] = stub; });
          _safeLog('WARN', 'MODULE_NOT_FOUND (stubbed): ' + request);
          return stub;
        }
        throw err;
      }
    };
  })();

  // ── Imports core ──────────────────────────────────────────────────────────
  const {
    makeWASocket, DisconnectReason,
    useMultiFileAuthState, fetchLatestBaileysVersion,
    jidNormalizedUser, makeCacheableSignalKeyStore, Browsers
  } = require('@whiskeysockets/baileys');
  const { Boom }  = require('@hapi/boom');
  const express   = require('express');
  const qrcode    = require('qrcode');

  let supabase = null;
  try {
    const { createClient } = require('@supabase/supabase-js');
    const url = process.env.SUPABASE_URL;
    const key = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (url && key) {
      supabase = createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } });
      _safeLog('INFO', 'Supabase configuré');
    }
  } catch (e) { _safeLog('WARN', 'Supabase init: ' + e.message); }

  // ── Config WABOT ──────────────────────────────────────────────────────────
  try { require('./wabot-core/config/config'); }
  catch (e) { _safeLog('WARN', 'config/config: ' + e.message); }

  // ── commandHandler ────────────────────────────────────────────────────────
  let buildMessageHandler = null;
  try {
    buildMessageHandler = require('./wabot-core/lib/commandHandler').buildMessageHandler;
    _safeLog('INFO', 'commandHandler chargé ✅');
  } catch (e) {
    _safeLog('ERROR', 'commandHandler ERREUR: ' + e.message);
  }

  // ── Store ─────────────────────────────────────────────────────────────────
  let store = null;
  try {
    store = require('./wabot-core/lib/lightweight_store');
  } catch (_) {
    store = {
      messages: {}, contacts: {}, chats: {},
      bind: () => {}, loadMessage: async () => null,
      readFromFile: () => {}, writeToFile: () => {},
    };
  }

  // ── État global ────────────────────────────────────────────────────────────
  let sock = null, lastQr = null, lastQrTs = 0, isConnected = false;
  let botStarting = false, qrCount = 0, messageHandler = null;
  let connectedPhone = '', connectedName = '', connectedJid = '';
  let messagesTotal = 0, commandsTotal = 0;
  const botStartTime = Date.now();

  // Stats pour analytics
  const dailyActivity = [];
  function _recordActivity(type) {
    const today = new Date().toISOString().slice(0, 10);
    let day = dailyActivity.find(d => d.day === today);
    if (!day) {
      day = { day: today, messages: 0, commands: 0 };
      dailyActivity.push(day);
      if (dailyActivity.length > 30) dailyActivity.shift();
    }
    day[type] = (day[type] || 0) + 1;
  }

  // ── Keepalive ─────────────────────────────────────────────────────────────
  const _keepalive = setInterval(() => {
    try { store.writeToFile && store.writeToFile(); } catch (_) {}
  }, 60_000);
  _keepalive.unref();

  // ── Supabase session ──────────────────────────────────────────────────────
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
      await supabase.from('wabot_devices').upsert({
        whatsapp_jid:      jid,
        whatsapp_phone:    phone,
        session_data:      files,
        bot_status:        'connected',
        last_seen:         new Date().toISOString(),
        platform:          'android',
        device_model:      DEVICE_MODEL,
        device_brand:      DEVICE_BRAND,
        device_manufacturer: DEVICE_MANUFACTURER,
        device_os:         'Android',
        device_os_version: DEVICE_ANDROID_VER,
        device_sdk_int:    DEVICE_SDK_INT || null,
      }, { onConflict: 'whatsapp_jid' });
      _safeLog('INFO', 'Session Supabase sauvegardée (' + phone + ')');
    } catch (e) { _safeLog('WARN', 'saveSession: ' + e.message); }
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
      _safeLog('INFO', 'Session Supabase restaurée');
      return true;
    } catch (_) { return false; }
  }

  // ── Démarrage WhatsApp ────────────────────────────────────────────────────
  async function startBot() {
    if (botStarting || isConnected) return;
    botStarting = true;
    _safeLog('INFO', 'Démarrage du bot...');
    _safeLog('INFO', 'Device: ' + DEVICE_BRAND + ' ' + DEVICE_MODEL +
             ' | RAM: ' + DEVICE_RAM_MB + 'MB | CPU: ' + DEVICE_CPU_CORES + ' cores' +
             ' | Android ' + DEVICE_ANDROID_VER);
    fs.mkdirSync(AUTH_DIR, { recursive: true });
    fs.mkdirSync(DATA_DIR, { recursive: true });

    const phone = process.env.WHATSAPP_PHONE_NUMBER || '';
    if (phone) await restoreSession(phone);

    let state, saveCreds;
    try {
      const creds = await useMultiFileAuthState(AUTH_DIR);
      state = creds.state; saveCreds = creds.saveCreds;
    } catch (e) {
      _safeLog('ERROR', 'useMultiFileAuthState: ' + e.message);
      botStarting = false;
      return setTimeout(() => startBot(), 5000);
    }

    let version;
    try {
      const v = await fetchLatestBaileysVersion();
      version = v.version;
    } catch (_) {
      version = [2, 3000, 1023561582];
    }

    const silentLogger = {
      level: 'silent',
      trace: () => {}, debug: () => {}, info: () => {},
      warn:  m => _safeLog('WARN',  typeof m === 'object' ? JSON.stringify(m).slice(0, 200) : String(m)),
      error: m => _safeLog('ERROR', typeof m === 'object' ? JSON.stringify(m).slice(0, 200) : String(m)),
      fatal: m => _safeLog('ERROR', typeof m === 'object' ? JSON.stringify(m).slice(0, 200) : String(m)),
      child: () => silentLogger,
    };

    // makeCacheableSignalKeyStore est requis pour le pairing code
    let authState;
    try {
      authState = {
        creds: state.creds,
        keys:  makeCacheableSignalKeyStore(state.keys, silentLogger),
      };
    } catch (_) {
      // fallback si version de baileys sans makeCacheableSignalKeyStore
      authState = state;
    }

    sock = makeWASocket({
      version,
      auth: authState,
      printQRInTerminal: false,
      // Browsers.windows('Chrome') est compatible avec le pairing code WhatsApp
      browser: Browsers ? Browsers.windows('Chrome') : ['Wabot', 'Chrome', '2.0.0'],
      logger: silentLogger,
      connectTimeoutMs: 60000,
      retryRequestDelayMs: 2000,
      msgRetryCounterCache: new Map(),
      getMessage: async (key) => {
        try {
          const jid2 = jidNormalizedUser(key.remoteJid);
          const msgs = store?.messages?.[jid2];
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
        _safeLog('INFO', 'Handler WABOT prêt ✅');
      } catch (e) {
        _safeLog('ERROR', 'buildMessageHandler crash: ' + e.message);
        messageHandler = null;
      }
    }

    // ── Messages entrants ───────────────────────────────────────────────────
    sock.ev.on('messages.upsert', async (chatUpdate) => {
      try {
        const msgs = chatUpdate?.messages;
        if (!Array.isArray(msgs) || msgs.length === 0) return;

        for (const m of msgs) {
          if (m.key?.fromMe === true) continue;
          if (m.key?.remoteJid === 'status@broadcast') continue;

          messagesTotal++;
          _recordActivity('messages');

          if (messageHandler) {
            try {
              await messageHandler(sock, { messages: [m], type: chatUpdate.type }, true);
            } catch (e) {
              _safeLog('ERROR', 'messageHandler: ' + (e.message || String(e)).slice(0, 200));
            }
          }
        }
      } catch (e) {
        _safeLog('ERROR', 'messages.upsert: ' + (e.message || String(e)).slice(0, 200));
      }
    });

    // ── Connexion ───────────────────────────────────────────────────────────
    sock.ev.on('connection.update', ({ qr, connection, lastDisconnect }) => {
      if (qr) {
        lastQr = qr; lastQrTs = Date.now(); qrCount++;
        _safeLog('INFO', 'QR #' + qrCount + ' généré');
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
        _safeLog('INFO', 'WhatsApp connecté ✅');

        const rawId = sock.user?.id || '';
        connectedJid   = rawId.includes(':') ? rawId.split(':')[0] + '@s.whatsapp.net' : rawId;
        connectedPhone = connectedJid.split('@')[0] || phone;
        connectedName  = sock.user?.name || 'Wabot';

        sock.sendMessage(connectedJid, {
          text: '*Wabot Android actif !* 🟢\n\n' +
                'Connecté : ' + new Date().toLocaleString('fr') +
                '\nNuméro : +' + connectedPhone +
                '\n\nTape *.help* pour voir les commandes.'
        }).catch(() => {});

        saveSession(connectedJid, connectedPhone).catch(() => {});
      }

      if (connection === 'close') {
        isConnected = false;
        botStarting = false;
        const err  = lastDisconnect?.error;
        const code = (new Boom(err))?.output?.statusCode;
        _safeLog('WARN', 'Connexion fermée — code: ' + code + ' | ' + (err?.message || ''));

        if (code === DisconnectReason.loggedOut || code === 401) {
          _safeLog('INFO', 'Session expirée — reset credentials');
          connectedPhone = ''; connectedName = ''; connectedJid = '';
          try { fs.rmSync(AUTH_DIR, { recursive: true, force: true }); } catch (_) {}
          setTimeout(() => startBot(), 2000);
        } else {
          const delay = [515, 408, 503].includes(code) ? 3000 : 6000;
          _safeLog('INFO', 'Reconnexion dans ' + (delay / 1000) + 's...');
          setTimeout(() => startBot(), delay);
        }
      }
    });
  }

  // ── Express API ────────────────────────────────────────────────────────────
  const app = express();
  app.use(express.json());

  // Auth middleware
  app.use('/api/v1', (req, res, next) => {
    const key = req.headers['x-api-key'] || req.query.api_key;
    if (key && key !== 'wabot_embedded_v1' && key !== 'wbk_dev') {
      return res.status(403).json({ success: false, error: 'UNAUTHORIZED' });
    }
    next();
  });

  app.get('/api/v1/health', (_, res) =>
    res.json({ ok: true, version: '2.3.0-android', uptime: Math.floor(process.uptime()) }));

  // ── /api/v1/instance/status ───────────────────────────────────────────────
  app.get('/api/v1/instance/status', (_, res) => {
    const mem = process.memoryUsage();
    res.json({
      success: true,
      instance: {
        connected:     isConnected,
        starting:      botStarting,
        phone:         connectedPhone || null,
        name:          connectedName  || 'Wabot',
        profilePicUrl: '',
        platform:      'android',
      },
      connected: isConnected,
      starting:  botStarting,
      process: {
        uptime: Math.floor(process.uptime()),
        node:   process.version,
        memory: {
          heapUsed:  Math.floor(mem.heapUsed),
          heapTotal: Math.floor(mem.heapTotal),
          rss:       Math.floor(mem.rss),
        },
      },
      // Infos ressources du téléphone Android
      device: {
        totalRamMb:      DEVICE_RAM_MB,
        cpuCores:        DEVICE_CPU_CORES,
        model:           DEVICE_MODEL,
        brand:           DEVICE_BRAND,
        manufacturer:    DEVICE_MANUFACTURER,
        androidVersion:  DEVICE_ANDROID_VER,
        sdkInt:          DEVICE_SDK_INT,
        hardware:        DEVICE_HARDWARE,
        nodeHeapMb:      Math.floor(mem.heapUsed  / 1024 / 1024),
        nodeRssMb:       Math.floor(mem.rss        / 1024 / 1024),
        // Utilisation RAM node vs total device
        ramUsagePct: DEVICE_RAM_MB > 0
          ? Math.round((mem.rss / 1024 / 1024) / DEVICE_RAM_MB * 100)
          : null,
      },
      stats: {
        messagesTotal,
        commandsTotal,
      },
    });
  });

  // ── /api/v1/instance/info ─────────────────────────────────────────────────
  app.get('/api/v1/instance/info', (_, res) =>
    res.json({
      success: true,
      instance: {
        connected:   isConnected,
        phone:       connectedPhone || null,
        name:        connectedName  || 'Wabot',
        platform:    'android',
        version:     '2.3.0',
        nodeVersion: process.version,
      },
    })
  );

  // ── /api/v1/instance/qr ──────────────────────────────────────────────────
  app.get('/api/v1/instance/qr', async (_, res) => {
    if (isConnected) return res.json({ success: true, connected: true });
    if (!lastQr)     return res.status(503).json({ success: false, error: 'QR_NOT_AVAILABLE', starting: botStarting });
    const age = (Date.now() - lastQrTs) / 1000;
    if (age > 60)    return res.status(410).json({ success: false, error: 'QR_EXPIRED', ageSeconds: age });
    try {
      const qrImage = await qrcode.toDataURL(lastQr, { type: 'image/png', width: 300 });
      res.json({ success: true, connected: false, qr: lastQr, qrImage, ageSeconds: age });
    } catch (e) { res.status(500).json({ success: false, error: e.message }); }
  });

  // ── /api/v1/instance/reconnect ────────────────────────────────────────────
  app.post('/api/v1/instance/reconnect', (_, res) => {
    try { sock?.end(); } catch (_) {}
    isConnected = false; botStarting = false; lastQr = null; qrCount = 0;
    setTimeout(() => startBot(), 800);
    res.json({ success: true, message: 'Reconnexion en cours...' });
  });

  // ── /api/v1/instance/reset ────────────────────────────────────────────────
  app.post('/api/v1/instance/reset', (_, res) => {
    try { fs.rmSync(AUTH_DIR, { recursive: true, force: true }); } catch (_) {}
    try { sock?.end(); } catch (_) {}
    isConnected = false; botStarting = false; lastQr = null; qrCount = 0;
    connectedPhone = ''; connectedName = ''; connectedJid = '';
    setTimeout(() => startBot(), 1000);
    res.json({ success: true, message: 'Reset — nouveau QR en cours...' });
  });

  // ── /api/v1/instance/pair ────────────────────────────────────────────────
  app.post('/api/v1/instance/pair', async (req, res) => {
    const { phone } = req.body || {};
    if (!phone) return res.status(400).json({ success: false, error: 'phone requis' });
    if (isConnected) return res.json({ success: true, connected: true });

    // Démarrer le bot si pas encore fait, attendre qu'il soit prêt
    if (!sock) {
      if (!botStarting) startBot();
      return res.status(503).json({
        success: false,
        error: 'BOT_NOT_STARTED',
        message: 'Bot en démarrage, réessaie dans 3 secondes'
      });
    }

    try {
      // Petit délai pour s'assurer que la socket est bien initialisée
      await new Promise(r => setTimeout(r, 500));
      const cleanPhone = phone.replace(/[^0-9]/g, '');
      const code = await sock.requestPairingCode(cleanPhone);
      // Format XXXX-XXXX
      const fmt = code && code.length === 8
        ? code.slice(0,4) + '-' + code.slice(4)
        : code;
      res.json({ success: true, code: fmt });
    } catch (e) {
      _safeLog('ERROR', 'requestPairingCode: ' + e.message);
      res.status(500).json({ success: false, error: e.message });
    }
  });

  // ── /api/v1/logs ──────────────────────────────────────────────────────────
  app.get('/api/v1/logs', (req, res) => {
    const limit = Math.min(parseInt(req.query.limit || '100'), 300);
    res.json({ success: true, logs: logs.slice(-limit) });
  });

  // ── /api/v1/groups ────────────────────────────────────────────────────────
  app.get('/api/v1/groups', (_, res) =>
    res.json({ success: true, groups: [], total: 0 }));

  // ── /api/v1/messages ─────────────────────────────────────────────────────
  app.get('/api/v1/messages', (_, res) =>
    res.json({ success: true, messages: [], total: messagesTotal }));

  // ── /api/v1/analytics ─────────────────────────────────────────────────────
  app.get('/api/v1/analytics', (req, res) => {
    const period = req.query.period || '7d';
    const days   = period === '30d' ? 30 : period === '1d' ? 1 : 7;
    const slice  = dailyActivity.slice(-days);
    const filled = [];
    for (let i = days - 1; i >= 0; i--) {
      const day = new Date(Date.now() - i * 86400000).toISOString().slice(0, 10);
      const found = slice.find(d => d.day === day);
      filled.push(found || { day, messages: 0, commands: 0 });
    }
    res.json({
      success:        true,
      period,
      totalMessages:  messagesTotal,
      totalCommands:  commandsTotal,
      totalGroups:    0,
      totalUsers:     0,
      messagesGrowth: 0.0,
      commandsGrowth: 0.0,
      topCommands:    [],
      dailyActivity:  filled,
    });
  });

  // ── /api/v1/metrics ───────────────────────────────────────────────────────
  app.get('/api/v1/metrics', (_, res) => {
    const mem = process.memoryUsage();
    res.json({
      success:        true,
      messagesPerMin: 0,
      activeChats:    0,
      commandsToday:  commandsTotal,
      errorsToday:    0,
      cpuHistory:      Array.from({ length: 12 }, (_, i) => ({ time: i, value: 0 })),
      ramHistory:      Array.from({ length: 12 }, (_, i) => ({ time: i, value: Math.floor(mem.heapUsed / 1024 / 1024) })),
      messagesHistory: dailyActivity.slice(-7).map(d => ({ day: d.day, count: d.messages })),
    });
  });

  // ── Démarrage ─────────────────────────────────────────────────────────────
  _initLogFile();
  app.listen(PORT, '127.0.0.1', () => {
    _safeLog('INFO', 'Wabot API v2.3.0 démarrée sur le port ' + PORT);
    _safeLog('INFO', 'Device: ' + DEVICE_BRAND + ' ' + DEVICE_MODEL +
             ' | RAM: ' + DEVICE_RAM_MB + 'MB | CPU: ' + DEVICE_CPU_CORES + ' cores' +
             ' | Android ' + DEVICE_ANDROID_VER);
    startBot();
  });
  