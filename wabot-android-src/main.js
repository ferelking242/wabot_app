'use strict';
  process.env.NODE_ENV = 'production';

  // nodejs-mobile polyfills
  ;(function patchTextDecoder() {
    if (typeof TextDecoder === 'undefined') return;
    const _Native = TextDecoder;
    global.TextDecoder = class TextDecoder extends _Native {
      constructor(label, options) {
        super(label, options ? { ...options, fatal: false } : options);
      }
    };
  })();

  ;(function patchCrypto() {
    if (globalThis.crypto && globalThis.crypto.subtle) return;
    try {
      const { webcrypto } = require('crypto');
      if (webcrypto && webcrypto.subtle) { globalThis.crypto = webcrypto; return; }
    } catch (_) {}
    const { Crypto } = require('@peculiar/webcrypto');
    globalThis.crypto = new Crypto();
  })();

  const { makeWASocket, DisconnectReason, useMultiFileAuthState, fetchLatestBaileysVersion } =
    require('@whiskeysockets/baileys');
  const express = require('express');
  const path    = require('path');
  const fs      = require('fs');

  const PORT     = parseInt(process.env.PORT || '3001', 10);
  const DATA_DIR = process.env.WABOT_DATA_DIR || path.join(process.cwd(), 'data');
  const AUTH_DIR = path.join(DATA_DIR, 'auth_state');
  const API_KEY  = process.env.WABOT_AUTH_KEY || 'wabot_embedded_v1';

  // Supabase config
  const SUPA_URL = 'https://nublrlyhdbeoqimntdrl.supabase.co';
  const SUPA_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im51YmxybHloZGJlb3FpbW50ZHJsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3ODExMzkzNiwiZXhwIjoyMDkzNjg5OTM2fQ.-wl6GyU5L4aRas7ke41UBr5P5cnsDv1c42UqaGdrc88';

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

  app.use('/api/v1', (req, res, next) => {
    if (req.path === '/health') return next();
    const key = req.headers['x-api-key'] || req.query.key;
    if (key !== API_KEY) return res.status(401).json({ success: false, error: 'UNAUTHORIZED' });
    next();
  });

  const botLogs = [];
  function addLog(level, msg) {
    botLogs.push({ level, message: msg, timestamp: new Date().toISOString() });
    if (botLogs.length > 500) botLogs.shift();
    console.log('[' + level + '] ' + msg);
  }

  // ── Supabase session save ─────────────────────────────────────────────────────
  async function saveSessionToSupabase(jid, phone) {
    try {
      const sessionFiles = {};
      if (fs.existsSync(AUTH_DIR)) {
        const files = fs.readdirSync(AUTH_DIR);
        for (const file of files) {
          const filePath = path.join(AUTH_DIR, file);
          if (fs.statSync(filePath).isFile()) {
            sessionFiles[file] = fs.readFileSync(filePath).toString('base64');
          }
        }
      }
      const body = JSON.stringify({
        whatsapp_jid: jid,
        whatsapp_phone: phone,
        session_data: sessionFiles,
        session_updated_at: new Date().toISOString(),
        bot_status: 'connected',
        last_seen: new Date().toISOString(),
        platform: 'android',
      });
      const resp = await fetch(SUPA_URL + '/rest/v1/wabot_devices?on_conflict=whatsapp_jid', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + SUPA_KEY,
          'apikey': SUPA_KEY,
          'Prefer': 'resolution=merge-duplicates,return=minimal',
        },
        body,
      });
      if (resp.ok || resp.status === 201 || resp.status === 204) {
        addLog('SUCCESS', 'Session WA sauvegardee sur Supabase');
      } else {
        const err = await resp.text();
        addLog('WARN', 'Supabase session save: ' + resp.status + ' ' + err.slice(0, 100));
      }
    } catch (e) {
      addLog('ERROR', 'saveSession error: ' + e.message);
    }
  }

  // ── Restore session from Supabase ─────────────────────────────────────────────
  async function restoreSessionFromSupabase(phone) {
    try {
      const resp = await fetch(
        SUPA_URL + '/rest/v1/wabot_devices?whatsapp_phone=eq.' + encodeURIComponent(phone) + '&select=session_data&limit=1',
        {
          headers: {
            'Authorization': 'Bearer ' + SUPA_KEY,
            'apikey': SUPA_KEY,
          },
        }
      );
      if (!resp.ok) return;
      const rows = await resp.json();
      if (!rows || !rows[0] || !rows[0].session_data) return;
      const sessionFiles = rows[0].session_data;
      if (!fs.existsSync(AUTH_DIR)) fs.mkdirSync(AUTH_DIR, { recursive: true });
      for (const [file, b64] of Object.entries(sessionFiles)) {
        fs.writeFileSync(path.join(AUTH_DIR, file), Buffer.from(b64, 'base64'));
      }
      addLog('SUCCESS', 'Session restauree depuis Supabase');
    } catch (e) {
      addLog('ERROR', 'restoreSession error: ' + e.message);
    }
  }

  function clearAuthAndRestart() {
    try {
      if (fs.existsSync(AUTH_DIR)) {
        fs.rmSync(AUTH_DIR, { recursive: true, force: true });
        fs.mkdirSync(AUTH_DIR, { recursive: true });
      }
    } catch (err) { console.error('[Wabot] Clear error:', err.message); }
    sock = null; lastQr = null; isConnected = false; botStarting = false; qrCount = 0;
    setTimeout(startBot, 1000);
  }

  let sock = null, lastQr = null, lastQrTimestamp = null;
  let isConnected = false, botStarting = false, qrCount = 0;

  async function startBot() {
    if (botStarting) return;
    botStarting = true;
    try {
      const phone = process.env.WABOT_PHONE || '';
      if (phone) await restoreSessionFromSupabase(phone);

      const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
      const { version }          = await fetchLatestBaileysVersion();

      sock = makeWASocket({
        version,
        auth:                           state,
        printQRInTerminal:              false,
        browser:                        ['Wabot', 'Chrome', '120.0.0.0'],
        connectTimeoutMs:               60_000,
        keepAliveIntervalMs:            25_000,
        retryRequestDelayMs:            2_000,
        generateHighQualityLinkPreview: false,
        logger:                         noopLogger,
      });

      sock.ev.on('creds.update', saveCreds);

      // ── Message handler ───────────────────────────────────────────────────────
      sock.ev.on('messages.upsert', async ({ messages, type }) => {
        // Accept 'notify' (messages from others) AND 'append' (owner's own messages sent from same account)
          if (!['notify', 'append'].includes(type)) return;
        for (const msg of messages) {
          if (!msg.message) continue;
            // Allow fromMe so owner can send commands from their own number
            // Skip only automated protocol messages
            if (msg.key.fromMe && msg.message?.protocolMessage) continue;
          const from     = msg.key.remoteJid;
          const isGroup  = from.endsWith('@g.us');
          const senderId = msg.key.participant || from;
          const body     =
            msg.message?.conversation ||
            msg.message?.extendedTextMessage?.text ||
            msg.message?.imageMessage?.caption ||
            msg.message?.videoMessage?.caption || '';
          if (!body) continue;

          addLog('INFO', 'Msg: ' + (senderId.split('@')[0]) + ': ' + body.slice(0, 80));

          const PREFIX = '.';
          if (!body.trim().startsWith(PREFIX)) continue;

          const cmd      = body.trim().toLowerCase().split(' ')[0];
          const args     = body.trim().split(' ').slice(1);
          const argsText = args.join(' ');
          const ownerNum = process.env.OWNER_NUMBER || '242065491040';
          const isOwner  = senderId.includes(ownerNum);

          try {
            switch (cmd) {
              case '.ping':
                await sock.sendMessage(from,
                  { text: 'Pong! Bot actif ' + new Date().toLocaleTimeString() },
                  { quoted: msg });
                break;

              case '.help':
              case '.menu':
              case '.bot':
                await sock.sendMessage(from, {
                  text: [
                    'Wabot - Commandes disponibles',
                    '',
                    'SYSTEME:',
                    '.ping          - Bot actif ?',
                    '.alive         - Statut complet (uptime, RAM)',
                    '.help          - Ce menu',
                    '.owner         - Infos proprietaire',
                    '',
                    'GROUPE:',
                    '.tagall         - Mentionner tout le groupe',
                    '.groupinfo      - Infos du groupe',
                    '.kick @user     - Exclure un membre',
                    '.promote @user  - Promouvoir admin',
                    '.demote @user   - Retrograder admin',
                    '.mute           - Muter le groupe',
                    '.unmute         - Demuter le groupe',
                    '.ban @user      - Bannir un membre',
                    '.warn @user     - Avertir un membre',
                    '',
                    'FUN:',
                    '.joke           - Blague aleatoire',
                    '.quote          - Citation inspirante',
                    '.fact           - Fait insolite',
                    '.8ball <q>      - Boule magique',
                    '.dare           - Defi aleatoire',
                    '.truth          - Question verite',
                    '.compliment     - Compliment aleatoire',
                    '.insult         - Insulte amicale',
                    '.coinflip       - Pile ou face',
                    '.trivia         - Culture generale',
                    '.rps            - Pierre-Feuille-Ciseaux',
                    '',
                    'UTILITAIRES:',
                    '.weather <city> - Meteo en direct (wttr.in)',
                    '.translate <x>  - Traduire en francais',
                    '.sticker        - Image citee -> sticker WA',
                    '',
                    'Prefixe: . | v2.0 | Appuyez longuement pour copier',
                  ].join('\n'),
                }, { quoted: msg });
                break;

              case '.alive':
                await sock.sendMessage(from, {
                  text: 'Bot en ligne !\n' +
                    'Uptime: ' + Math.floor(process.uptime() / 3600) + 'h ' +
                    Math.floor((process.uptime() % 3600) / 60) + 'min\n' +
                    'RAM: ' + Math.round(process.memoryUsage().rss / 1024 / 1024) + 'MB',
                }, { quoted: msg });
                break;

              case '.owner':
                await sock.sendMessage(from,
                  { text: 'Proprietaire du bot: +' + ownerNum },
                  { quoted: msg });
                break;

              case '.groupinfo': {
                if (!isGroup) { await sock.sendMessage(from, { text: 'Commande reservee aux groupes.' }, { quoted: msg }); break; }
                const meta = await sock.groupMetadata(from);
                await sock.sendMessage(from, {
                  text: 'Infos du groupe\n\n' +
                    'Nom: ' + meta.subject + '\n' +
                    'Membres: ' + meta.participants.length + '\n' +
                    'ID: ' + from,
                }, { quoted: msg });
                break;
              }

              case '.tagall': {
                if (!isGroup) { await sock.sendMessage(from, { text: 'Commande reservee aux groupes.' }, { quoted: msg }); break; }
                const meta     = await sock.groupMetadata(from);
                const mentions = meta.participants.map(p => p.id);
                const text     = 'Attention tout le monde !\n\n' +
                  mentions.map(jid => '@' + jid.split('@')[0]).join(' ');
                await sock.sendMessage(from, { text, mentions }, { quoted: msg });
                break;
              }

              case '.kick': {
                if (!isGroup) { await sock.sendMessage(from, { text: 'Commande reservee aux groupes.' }, { quoted: msg }); break; }
                const mentioned = msg.message?.extendedTextMessage?.contextInfo?.mentionedJid || [];
                if (!mentioned.length) { await sock.sendMessage(from, { text: 'Mentionnez un membre.' }, { quoted: msg }); break; }
                await sock.groupParticipantsUpdate(from, mentioned, 'remove');
                await sock.sendMessage(from, { text: 'Membre(s) exclus.' }, { quoted: msg });
                break;
              }

              case '.promote': {
                if (!isGroup) { await sock.sendMessage(from, { text: 'Commande reservee aux groupes.' }, { quoted: msg }); break; }
                const toP = msg.message?.extendedTextMessage?.contextInfo?.mentionedJid || [];
                if (!toP.length) { await sock.sendMessage(from, { text: 'Mentionnez un membre.' }, { quoted: msg }); break; }
                await sock.groupParticipantsUpdate(from, toP, 'promote');
                await sock.sendMessage(from, { text: 'Membre(s) promu(s) admin.' }, { quoted: msg });
                break;
              }

              case '.demote': {
                if (!isGroup) { await sock.sendMessage(from, { text: 'Commande reservee aux groupes.' }, { quoted: msg }); break; }
                const toD = msg.message?.extendedTextMessage?.contextInfo?.mentionedJid || [];
                if (!toD.length) { await sock.sendMessage(from, { text: 'Mentionnez un admin.' }, { quoted: msg }); break; }
                await sock.groupParticipantsUpdate(from, toD, 'demote');
                await sock.sendMessage(from, { text: 'Admin(s) retrograde(s).' }, { quoted: msg });
                break;
              }

              case '.mute': {
                if (!isGroup) { await sock.sendMessage(from, { text: 'Commande reservee aux groupes.' }, { quoted: msg }); break; }
                await sock.groupSettingUpdate(from, 'announcement');
                await sock.sendMessage(from, { text: 'Groupe mute. Seuls les admins peuvent ecrire.' }, { quoted: msg });
                break;
              }

              case '.unmute': {
                if (!isGroup) { await sock.sendMessage(from, { text: 'Commande reservee aux groupes.' }, { quoted: msg }); break; }
                await sock.groupSettingUpdate(from, 'not_announcement');
                await sock.sendMessage(from, { text: 'Groupe demute.' }, { quoted: msg });
                break;
              }

              case '.joke': {
                const jokes = [
                  'Pourquoi les plongeurs plongent toujours en arriere ? Parce que sinon ils tomberaient dans le bateau !',
                  'Un homme entre dans une bibliotheque. Il demande un livre sur les tortues. La bibliothecaire dit : Avec ou sans carapace ? Il repond : Sans. Elle dit : Desole, nous avons que des livres relies !',
                  'Je voulais raconter une blague sur le papier, mais elle est dechirante.',
                  'Pourquoi Einstein avait-il peu amis ? Parce que tout le monde le trouvait trop relatif !',
                ];
                await sock.sendMessage(from,
                  { text: jokes[Math.floor(Math.random() * jokes.length)] },
                  { quoted: msg });
                break;
              }

              case '.quote': {
                const quotes = [
                  'La vie est comme une bicyclette, il faut avancer pour ne pas perdre l equilibre. - Einstein',
                  'Le succes, c est tomber sept fois et se relever huit. - Proverbe japonais',
                  'Sois le changement que tu veux voir dans le monde. - Gandhi',
                  'Un voyage de mille lieues commence par un premier pas. - Lao Tseu',
                ];
                await sock.sendMessage(from,
                  { text: quotes[Math.floor(Math.random() * quotes.length)] },
                  { quoted: msg });
                break;
              }

              case '.fact': {
                const facts = [
                  'Les pieuvres ont trois coeurs et du sang bleu.',
                  'Le miel ne se perime jamais - on en a trouve dans des tombes egyptiennes de 3000 ans.',
                  'Un aigle peut voir un lapin a 3 km de distance.',
                  'La Lune s eloigne de la Terre de 3,8 cm par an.',
                  'Les elephants ne peuvent pas sauter.',
                ];
                await sock.sendMessage(from,
                  { text: facts[Math.floor(Math.random() * facts.length)] },
                  { quoted: msg });
                break;
              }

              case '.8ball': {
                if (!argsText) {
                  await sock.sendMessage(from, { text: 'Posez une question ! Ex: .8ball vais-je reussir ?' }, { quoted: msg });
                  break;
                }
                const answers = [
                  'Oui, certainement !', 'Non, pas du tout.',
                  'Peut-etre...', 'Absolument !',
                  'Definitivement non.', 'Demande plus tard.',
                  'Sans aucun doute !', 'Je ne suis pas sur.',
                ];
                await sock.sendMessage(from, {
                  text: 'Boule Magique\nQuestion: ' + argsText +
                    '\nReponse: ' + answers[Math.floor(Math.random() * answers.length)],
                }, { quoted: msg });
                break;
              }


              case '.coinflip': {
                const cf = Math.random() < 0.5 ? 'PILE' : 'FACE';
                await sock.sendMessage(from, { text: '🪙 ' + cf + ' !' }, { quoted: msg });
                break;
              }

              case '.dare': {
                const dares = ['Envoie un message vocal en chantant 30s.', 'Change ton statut pour "Je suis le meilleur" 1h.', 'Envoie une photo avec 3 emojis sur le visage.', 'Ecris un poeme sur le bot en 4 lignes.', 'Fais 10 pompes et envoie une video.', 'Envoie un message a quelqu un que tu n as pas contacte depuis longtemps.'];
                await sock.sendMessage(from, { text: '🎯 *Defi:* ' + dares[Math.floor(Math.random() * dares.length)] }, { quoted: msg });
                break;
              }

              case '.truth': {
                const truths = ['Quelle est la chose la plus embarrassante qui vous soit arrivee ?', 'Quel est votre plus grand secret ?', 'Quelle est la chose la plus folle que vous ayez faite ?', 'Qui etait votre premier crush ?', 'Quel est le mensonge que vous avez dit le plus souvent ?'];
                await sock.sendMessage(from, { text: '💬 *Verite:* ' + truths[Math.floor(Math.random() * truths.length)] }, { quoted: msg });
                break;
              }

              case '.compliment': {
                const comps = ['Tu es brillant(e) et inspirant(e) !', 'Tu as un sens de l humour incroyable.', 'Ton intelligence est vraiment admirable.', 'Tu rends le monde meilleur juste en existant.', 'Tout le monde s illumine quand tu arrives !'];
                await sock.sendMessage(from, { text: '💝 ' + comps[Math.floor(Math.random() * comps.length)] }, { quoted: msg });
                break;
              }

              case '.insult': {
                const ins = ['T es tellement lent(e) que les escargots te font signe de la main.', 'Si l intelligence etait de l eau, tu serais le desert du Sahara.', 'Meme Google ne peut pas trouver ton intelligence.', 'T es tellement bete que t as mis du sel dans ta boite mail.'];
                await sock.sendMessage(from, { text: '🤣 (humour) ' + ins[Math.floor(Math.random() * ins.length)] }, { quoted: msg });
                break;
              }

              case '.rps':
              case '.rockpaperscissors': {
                const rpsOpts = ['Pierre ✊', 'Feuille ✋', 'Ciseaux ✌️'];
                const rpsBot = rpsOpts[Math.floor(Math.random() * 3)];
                const rpsPlayer = argsText ? 'Tu : *' + argsText + '*  |  ' : '';
                await sock.sendMessage(from, { text: rpsPlayer + 'Bot: *' + rpsBot + '*' }, { quoted: msg });
                break;
              }

              case '.trivia': {
                const trivias = [{q:'Capitale de la France ?',a:'Paris'},{q:'Combien de continents ?',a:'7'},{q:'Plus grand ocean ?',a:'Pacifique'},{q:'Planete la plus proche du Soleil ?',a:'Mercure'},{q:'Annee fondation WhatsApp ?',a:'2009'},{q:'Pattes d une araignee ?',a:'8'},{q:'Animal le plus rapide ?',a:'Le guepard'}];
                const tv = trivias[Math.floor(Math.random() * trivias.length)];
                await sock.sendMessage(from, { text: '🧠 *Trivia:* ' + tv.q + '\n_(30 secondes pour repondre)_' }, { quoted: msg });
                setTimeout(async () => { try { await sock.sendMessage(from, { text: '⏰ Reponse: *' + tv.a + '*' }); } catch(_) {} }, 30000);
                break;
              }

              case '.weather': {
                if (!argsText) { await sock.sendMessage(from, { text: 'Usage: .weather <ville>\nEx: .weather Paris' }, { quoted: msg }); break; }
                try {
                  const cityEnc = encodeURIComponent(argsText.trim());
                  const wResp = await fetch('https://wttr.in/' + cityEnc + '?format=3&lang=fr');
                  const wText = await wResp.text();
                  await sock.sendMessage(from, { text: '🌤 *Meteo:* ' + wText.trim() }, { quoted: msg });
                } catch (e) { await sock.sendMessage(from, { text: 'Erreur meteo: ' + e.message }, { quoted: msg }); }
                break;
              }

              case '.translate': {
                if (!argsText) { await sock.sendMessage(from, { text: 'Usage: .translate <texte>\nEx: .translate hello world' }, { quoted: msg }); break; }
                try {
                  const trEnc = encodeURIComponent(argsText.trim());
                  const trResp = await fetch('https://api.mymemory.translated.net/get?q=' + trEnc + '&langpair=auto|fr');
                  const trData = await trResp.json();
                  const translated = trData.responseData?.translatedText || 'Erreur traduction';
                  await sock.sendMessage(from, { text: '🌍 *Traduction:* ' + translated }, { quoted: msg });
                } catch (e) { await sock.sendMessage(from, { text: 'Erreur: ' + e.message }, { quoted: msg }); }
                break;
              }

              case '.ban': {
                if (!isOwner && !isGroup) { await sock.sendMessage(from, { text: 'Commande reservee au proprietaire.' }, { quoted: msg }); break; }
                const toBan = msg.message?.extendedTextMessage?.contextInfo?.mentionedJid || [];
                if (!toBan.length) { await sock.sendMessage(from, { text: 'Mentionnez un utilisateur avec @.' }, { quoted: msg }); break; }
                if (isGroup) await sock.groupParticipantsUpdate(from, toBan, 'remove');
                await sock.sendMessage(from, { text: '🚫 ' + toBan.map(j => '@' + j.split('@')[0]).join(', ') + ' banni(s).', mentions: toBan }, { quoted: msg });
                break;
              }

              case '.warn': {
                const toWarn = msg.message?.extendedTextMessage?.contextInfo?.mentionedJid || [];
                if (!toWarn.length) { await sock.sendMessage(from, { text: 'Mentionnez un utilisateur avec @.' }, { quoted: msg }); break; }
                await sock.sendMessage(from, { text: '⚠️ *Avertissement* pour ' + toWarn.map(j => '@' + j.split('@')[0]).join(', ') + '\n' + (argsText || 'Comportement inapproprie.'), mentions: toWarn }, { quoted: msg });
                break;
              }

              case '.sticker': {
                const quotedCtx = msg.message?.extendedTextMessage?.contextInfo;
                const quotedMsg2 = quotedCtx?.quotedMessage;
                if (!quotedMsg2?.imageMessage && !quotedMsg2?.videoMessage) {
                  await sock.sendMessage(from, { text: '📌 Reponds a une image avec .sticker' }, { quoted: msg }); break;
                }
                try {
                  const { downloadMediaMessage } = require('@whiskeysockets/baileys');
                  const fMsg = { key: { remoteJid: from, id: quotedCtx.stanzaId, fromMe: false, participant: quotedCtx.participant }, message: quotedMsg2 };
                  const buf = await downloadMediaMessage(fMsg, 'buffer', {}, { logger: noopLogger, reuploadRequest: sock.updateMediaMessage });
                  await sock.sendMessage(from, { sticker: buf }, { quoted: msg });
                } catch (e) { await sock.sendMessage(from, { text: 'Erreur sticker: ' + e.message }, { quoted: msg }); }
                break;
              }

              default:
                addLog('INFO', 'Cmd inconnue: ' + cmd);
            }
            addLog('SUCCESS', 'Cmd ' + cmd + ' executee');
          } catch (e) {
            addLog('ERROR', 'Erreur cmd ' + cmd + ': ' + e.message);
            try { await sock.sendMessage(from, { text: 'Erreur interne.' }, { quoted: msg }); } catch (_) {}
          }
        }
      });

      sock.ev.on('connection.update', ({ qr, connection, lastDisconnect }) => {
        if (qr) {
          lastQr = qr; lastQrTimestamp = Date.now(); qrCount++;
          console.log('[Wabot] QR #' + qrCount);
          if (qrCount >= 3) {
            qrCount = 0; sock?.end();
            setTimeout(clearAuthAndRestart, 500);
            return;
          }
        }
        if (connection === 'open') {
          isConnected = true; botStarting = false; lastQr = null; qrCount = 0;
          const jid   = sock?.user?.id || '';
          const phone = jid.replace(/:.*@/, '@').split('@')[0];
          addLog('SUCCESS', 'WhatsApp connecte: ' + jid);
          // Save session to Supabase
          saveSessionToSupabase(jid, phone).catch(e => addLog('WARN', 'Session save: ' + e.message));
          // Envoie un message de confirmation a l'owner apres connexion
          setTimeout(async () => {
            try {
              const selfJid = phone + '@s.whatsapp.net';
              const now = new Date().toLocaleTimeString('fr-FR');
              await sock.sendMessage(selfJid, {
                text: '*Bot actif !* \n\n Connecte: ' + now + '\n Numero: ' + phone + '\n\nTape .help pour les commandes'
              });
              addLog('INFO', 'Message connexion envoye');
            } catch (e) {
              addLog('WARN', 'Msg connexion echec: ' + e.message);
            }
          }, 4000);
        }
        if (connection === 'close') {
          isConnected = false; botStarting = false;
          // Update bot status in Supabase
          const jid = sock?.user?.id || '';
          if (jid) {
            fetch(SUPA_URL + '/rest/v1/wabot_devices?whatsapp_jid=eq.' + encodeURIComponent(jid), {
              method: 'PATCH',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + SUPA_KEY,
                'apikey': SUPA_KEY,
              },
              body: JSON.stringify({ bot_status: 'disconnected' }),
            }).catch(() => {});
          }
          const code = lastDisconnect?.error?.output?.statusCode;
          if (code !== DisconnectReason.loggedOut) {
            console.log('[Wabot] Reconnecting in 5s...');
            setTimeout(startBot, 5_000);
          } else {
            console.log('[Wabot] Logged out');
          }
        }
      });
    } catch (err) {
      botStarting = false;
      console.error('[Wabot] Start error:', err.message);
      setTimeout(startBot, 10_000);
    }
  }

  // ── Routes ────────────────────────────────────────────────────────────────────

  app.get('/api/v1/health', (_req, res) => res.json({ ok: true, version: '1.0.0-android' }));

  app.get('/api/v1/instance/status', (_req, res) => {
    const mem = process.memoryUsage();
    res.json({
      success: true,
      instance: {
        connected: isConnected,
        phone:     sock?.user?.id?.replace(/:.*@/, '@') || null,
        name:      sock?.user?.name || null,
        platform:  'Baileys-Android',
      },
      process: {
        uptime:  Math.floor(process.uptime()),
        pid:     process.pid,
        memory:  {
          rss:      Math.round(mem.rss / 1024 / 1024) + ' MB',
          heapUsed: Math.round(mem.heapUsed / 1024 / 1024) + ' MB',
        },
        node: process.version,
      },
      timestamp: new Date().toISOString(),
    });
  });

  app.get('/api/v1/instance/qr', async (_req, res) => {
    if (isConnected) return res.json({ success: true, connected: true });
    if (!lastQr) return res.status(503).json({ success: false, error: 'QR_NOT_AVAILABLE', message: 'QR not yet generated.' });
    const ageSeconds = Math.floor((Date.now() - lastQrTimestamp) / 1000);
    if (ageSeconds > 60) return res.status(410).json({ success: false, error: 'QR_EXPIRED', ageSeconds });
    try {
      const qrcode = require('qrcode');
      const png = await qrcode.toDataURL(lastQr, { type: 'image/png', width: 300 });
      res.json({ success: true, connected: false, qr: lastQr, qrImage: png, ageSeconds, expiresInSeconds: 60 - ageSeconds });
    } catch (err) {
      res.status(500).json({ success: false, error: 'QR_FAILED', message: err.message });
    }
  });

  app.post('/api/v1/instance/pair', async (req, res) => {
    if (isConnected) return res.json({ success: true, connected: true });
    const { phone } = req.body;
    if (!phone) return res.status(400).json({ success: false, error: 'MISSING_PHONE' });
    const cleanPhone = String(phone).replace(/[^\d]/g, '');
    if (!sock) return res.status(503).json({ success: false, error: 'BOT_NOT_STARTED', message: 'Bot still starting.' });
    try {
      let code = await sock.requestPairingCode(cleanPhone);
      code = code?.match(/.{1,4}/g)?.join('-') || code;
      res.json({ success: true, code, phone: cleanPhone });
    } catch (err) {
      res.status(500).json({ success: false, error: 'PAIR_FAILED', message: err.message });
    }
  });

  app.post('/api/v1/instance/reconnect', (req, res) => {
    res.json({ success: true, message: 'Reconnecting...' });
    isConnected = false; botStarting = false; sock = null;
    setTimeout(startBot, 500);
  });

  app.post('/api/v1/instance/reset', (_req, res) => {
    res.json({ success: true, message: 'Auth cleared, restarting...' });
    sock?.end();
    clearAuthAndRestart();
  });

  app.get('/api/v1/logs', (req, res) => {
    const limit = parseInt(req.query.limit) || 100;
    res.json(botLogs.slice(-limit).reverse());
  });

  // ── Start ─────────────────────────────────────────────────────────────────────
  app.listen(PORT, '127.0.0.1', () => {
    console.log('[Wabot-Android] API server started on port ' + PORT);
    startBot();
  });
  