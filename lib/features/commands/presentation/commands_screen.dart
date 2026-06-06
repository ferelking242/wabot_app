import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _g      = Color(0xFF25D366);
const _gd     = Color(0xFF128C7E);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF8A9199);
const _border = Color(0xFF1E2128);
const _card   = Color(0xFF111316);
const _bg     = Color(0xFF0D0E11);

// ─── Toutes les vraies commandes tirées de commandHandler.js ──────────────────
const _allCommands = [
  // ──── SYSTÈME ────────────────────────────────────────────────────────────
  _Cmd('.ping',         'Vérifie si le bot est en ligne',                         'Système',      '.ping'),
  _Cmd('.alive',        'Vérifie si le bot est vivant',                            'Système',      '.alive'),
  _Cmd('.test',         'Test rapide du bot',                                      'Système',      '.test'),
  _Cmd('.connect',      'Connexion / relancer la liaison WhatsApp',                'Système',      '.connect'),
  _Cmd('.owner',        'Infos sur le propriétaire du bot',                        'Système',      '.owner'),
  _Cmd('.help',         'Liste toutes les commandes (alias: .menu .bot .list)',     'Système',      '.help [catégorie]'),
  _Cmd('.cmd',          'Détails sur une commande',                                'Système',      '.cmd [nom]'),
  _Cmd('.alias',        'Gérer les alias de commandes',                            'Système',      '.alias'),
  _Cmd('.lang',         'Changer la langue du bot',                                'Système',      '.lang [fr|en|...]'),
  _Cmd('.jid',          'Affiche le JID du groupe ou de l\'utilisateur',           'Système',      '.jid'),
  _Cmd('.bug',          'Signaler un bug au développeur',                          'Système',      '.bug [description]'),
  _Cmd('.suggest',      'Faire une suggestion au développeur',                     'Système',      '.suggest [texte]'),
  _Cmd('.update',       'Mettre à jour le bot',                                    'Système',      '.update'),
  _Cmd('.changelog',    'Voir les dernières modifications du bot',                 'Système',      '.changelog'),
  _Cmd('.notify',       'Gérer les notifications du bot',                          'Système',      '.notify [on|off]'),
  _Cmd('.sudo',         'Gérer les utilisateurs sudo',                             'Système',      '.sudo [add|remove|list]'),
  _Cmd('.clearsession', 'Nettoyer la session WhatsApp (alias: .clearsesi)',         'Système',      '.clearsession'),
  _Cmd('.cleartmp',     'Supprimer les fichiers temporaires du bot',               'Système',      '.cleartmp'),
  _Cmd('.setpp',        'Changer la photo de profil du bot',                       'Système',      '.setpp [répondre à une image]'),
  _Cmd('.autotyping',   'Activer/désactiver l\'indicateur de frappe automatique',  'Système',      '.autotyping [on|off]'),
  _Cmd('.autoread',     'Activer/désactiver la lecture automatique des messages',  'Système',      '.autoread [on|off]'),
  _Cmd('.autostatus',   'Voir et réagir automatiquement aux statuts WhatsApp',     'Système',      '.autostatus [on|off]'),
  _Cmd('.areact',       'Configurer les réactions automatiques (alias: .autoreact)','Système',     '.areact [emoji]'),
  _Cmd('.companion',    'Gérer les bots compagnons',                               'Système',      '.companion [add|remove|list]'),
  _Cmd('.mode',         'Changer le mode du bot (public / privé)',                 'Système',      '.mode [public|private]'),

  // ──── ADMIN GROUPE ───────────────────────────────────────────────────────
  _Cmd('.kick',         'Exclure un membre du groupe (répondre ou mentionner)',    'Admin',        '.kick @user'),
  _Cmd('.mute',         'Mettre le groupe en silence pendant N minutes',           'Admin',        '.mute [minutes]'),
  _Cmd('.unmute',       'Réactiver les messages dans le groupe',                   'Admin',        '.unmute'),
  _Cmd('.ban',          'Bannir un utilisateur du bot',                            'Admin',        '.ban @user'),
  _Cmd('.unban',        'Débannir un utilisateur',                                 'Admin',        '.unban @user'),
  _Cmd('.promote',      'Promouvoir un membre en administrateur',                  'Admin',        '.promote @user'),
  _Cmd('.demote',       'Rétrograder un administrateur',                           'Admin',        '.demote @user'),
  _Cmd('.tagall',       'Taguer tous les membres du groupe',                       'Admin',        '.tagall'),
  _Cmd('.tag',          'Envoyer un message en taguant des membres',               'Admin',        '.tag [texte] @user'),
  _Cmd('.antilink',     'Activer la protection contre les liens externes',         'Admin',        '.antilink [on|off]'),
  _Cmd('.antitag',      'Activer la protection contre les tags abusifs',           'Admin',        '.antitag [on|off]'),
  _Cmd('.antibadword',  'Activer le filtre anti-gros mots',                        'Admin',        '.antibadword [on|off]'),
  _Cmd('.chatbot',      'Activer le chatbot IA dans le groupe',                    'Admin',        '.chatbot [on|off]'),
  _Cmd('.welcome',      'Configurer le message de bienvenue',                      'Admin',        '.welcome [on|off|texte]'),
  _Cmd('.goodbye',      'Configurer le message d\'au revoir',                      'Admin',        '.goodbye [on|off|texte]'),
  _Cmd('.warn',         'Avertir un membre (3 avertissements = kick)',             'Admin',        '.warn @user'),
  _Cmd('.warnings',     'Voir les avertissements d\'un membre',                    'Admin',        '.warnings @user'),
  _Cmd('.delete',       'Supprimer un message (répondre au message, alias: .del)', 'Admin',        '.delete'),
  _Cmd('.antidelete',   'Activer la récupération des messages supprimés',          'Admin',        '.antidelete [on|off]'),
  _Cmd('.setname',      'Renommer le groupe',                                      'Admin',        '.setname [nouveau nom]'),
  _Cmd('.setdesc',      'Modifier la description du groupe',                       'Admin',        '.setdesc [description]'),
  _Cmd('.groupsetting', 'Modifier les paramètres du groupe',                       'Admin',        '.groupsetting [valeur]'),
  _Cmd('.seticon',      'Changer l\'icône du groupe (répondre à une image)',       'Admin',        '.seticon'),
  _Cmd('.groupinfo',    'Afficher les informations du groupe',                     'Admin',        '.groupinfo'),
  _Cmd('.resetlink',    'Révoquer et regénérer le lien d\'invitation (alias: .revoke)', 'Admin',  '.resetlink'),
  _Cmd('.staff',        'Lister les administrateurs du groupe (alias: .admins)',   'Admin',        '.staff'),
  _Cmd('.leave',        'Faire quitter le bot du groupe',                          'Admin',        '.leave'),
  _Cmd('.clear',        'Supprimer plusieurs messages en masse',                   'Admin',        '.clear'),
  _Cmd('.poll',         'Créer un sondage dans le groupe',                         'Admin',        '.poll [question] | [opt1] | [opt2]'),
  _Cmd('.vote',         'Voter dans un sondage actif',                             'Admin',        '.vote [id] [option]'),
  _Cmd('.pollresults',  'Voir les résultats d\'un sondage',                        'Admin',        '.pollresults [id]'),
  _Cmd('.polls',        'Lister tous les sondages actifs',                         'Admin',        '.polls'),
  _Cmd('.endpoll',      'Terminer un sondage (admin requis)',                      'Admin',        '.endpoll [id]'),

  // ──── MÉDIAS ─────────────────────────────────────────────────────────────
  _Cmd('.sticker',      'Convertir une image/vidéo en sticker (alias: .s)',        'Médias',       '.sticker [répondre à média]'),
  _Cmd('.simage',       'Convertir un sticker en image',                           'Médias',       '.simage [répondre au sticker]'),
  _Cmd('.svideo',       'Convertir un sticker en vidéo',                           'Médias',       '.svideo [répondre au sticker]'),
  _Cmd('.attp',         'Créer un sticker texte animé',                            'Médias',       '.attp [texte]'),
  _Cmd('.blur',         'Flouter une image (répondre à une image)',                 'Médias',       '.blur'),
  _Cmd('.take',         'Renommer un sticker (auteur et pack)',                     'Médias',       '.take [auteur] | [pack]'),
  _Cmd('.crop',         'Rogner un sticker en cercle',                             'Médias',       '.crop [répondre au sticker]'),
  _Cmd('.tg',           'Sticker Telegram animé (alias: .stickertelegram)',         'Médias',       '.tg [répondre à média]'),
  _Cmd('.removebg',     'Supprimer le fond d\'une image (alias: .rmbg .nobg)',      'Médias',       '.removebg [répondre à image]'),
  _Cmd('.remini',       'Améliorer/upscaler une image (alias: .enhance .upscale)', 'Médias',       '.remini [répondre à image]'),
  _Cmd('.dvo',          'Révéler un média vue unique (alias: .vv)',                 'Médias',       '.dvo | .dvo h | .dvo save'),
  _Cmd('.imagine',      'Générer une image par IA (alias: .flux .dalle)',           'Médias',       '.imagine [description]'),
  _Cmd('.metallic',     'Texte effet métallique en sticker',                        'Médias',       '.metallic [texte]'),
  _Cmd('.ice',          'Texte effet glace en sticker',                             'Médias',       '.ice [texte]'),
  _Cmd('.matrix',       'Texte effet Matrix en sticker',                            'Médias',       '.matrix [texte]'),
  _Cmd('.cyber',        'Texte effet cyber en sticker',                             'Médias',       '.cyber [texte]'),
  _Cmd('.graffiti',     'Texte effet graffiti en sticker',                          'Médias',       '.graffiti [texte]'),
  _Cmd('.water',        'Texte effet eau en sticker',                               'Médias',       '.water [texte]'),
  _Cmd('.electric',     'Texte effet électrique en sticker',                        'Médias',       '.electric [texte]'),
  _Cmd('.lava',         'Texte effet lave en sticker',                              'Médias',       '.lava [texte]'),
  _Cmd('.wooden',       'Texte effet bois en sticker',                              'Médias',       '.wooden [texte]'),
  _Cmd('.glass',        'Texte effet verre en sticker',                             'Médias',       '.glass [texte]'),
  _Cmd('.comic',        'Texte effet comics en sticker',                            'Médias',       '.comic [texte]'),
  _Cmd('.impressive',   'Texte effet impressionnant en sticker',                    'Médias',       '.impressive [texte]'),
  _Cmd('.christmas',    'Texte effet Noël en sticker',                              'Médias',       '.christmas [texte]'),

  // ──── TÉLÉCHARGEMENTS ────────────────────────────────────────────────────
  _Cmd('.instagram',    'Télécharger une vidéo/photo Instagram (alias: .insta .ig)','Téléchargements', '.instagram [url]'),
  _Cmd('.facebook',     'Télécharger une vidéo Facebook (alias: .fb)',              'Téléchargements', '.facebook [url]'),
  _Cmd('.play',         'Télécharger audio YouTube (alias: .mp3 .song .yta .ytmp3)','Téléchargements', '.play [titre/url]'),
  _Cmd('.music',        'Télécharger musique (interface alternative)',              'Téléchargements', '.music [titre/url]'),
  _Cmd('.video',        'Télécharger vidéo YouTube (alias: .ytv .ytmp4)',           'Téléchargements', '.video [titre/url]'),
  _Cmd('.tiktok',       'Télécharger une vidéo TikTok sans filigrane (alias: .tt)', 'Téléchargements', '.tiktok [url]'),
  _Cmd('.ytsearch',     'Rechercher sur YouTube (alias: .yts)',                    'Téléchargements', '.ytsearch [titre]'),
  _Cmd('.ss',           'Capture d\'écran d\'un site web (alias: .ssweb .screenshot)', 'Téléchargements', '.ss [url]'),

  // ──── IA & TRADUCTION ────────────────────────────────────────────────────
  _Cmd('.gpt',          'Chat avec l\'IA GPT (alias: .gemini)',                     'IA',           '.gpt [question]'),
  _Cmd('.tts',          'Convertir du texte en message vocal',                     'IA',           '.tts [texte]'),
  _Cmd('.translate',    'Traduire un texte (alias: .trt)',                          'IA',           '.translate [lang] [texte]'),
  _Cmd('.transcribe',   'Transcrire un message vocal en texte (alias: .transc)',   'IA',           '.transcribe [répondre à vocal]'),
  _Cmd('.ts',           'Text-to-speech alternatif',                               'IA',           '.ts [lang] [texte]'),
  _Cmd('.lyrics',       'Trouver les paroles d\'une chanson',                      'IA',           '.lyrics [titre artiste]'),

  // ──── FUN & SOCIAL ───────────────────────────────────────────────────────
  _Cmd('.joke',         'Envoyer une blague aléatoire',                            'Fun',          '.joke'),
  _Cmd('.fact',         'Envoyer un fait aléatoire',                               'Fun',          '.fact'),
  _Cmd('.meme',         'Envoyer un mème aléatoire',                               'Fun',          '.meme'),
  _Cmd('.quote',        'Envoyer une citation aléatoire',                          'Fun',          '.quote'),
  _Cmd('.dare',         'Recevoir un défi (vérité ou défi)',                       'Fun',          '.dare'),
  _Cmd('.truth',        'Recevoir une question vérité',                            'Fun',          '.truth'),
  _Cmd('.flirt',        'Envoyer une phrase de drague à quelqu\'un',               'Fun',          '.flirt'),
  _Cmd('.ship',         'Calculer la compatibilité entre deux membres',            'Fun',          '.ship'),
  _Cmd('.simp',         'Générer une carte simp (répondre ou mentionner)',         'Fun',          '.simp [@user]'),
  _Cmd('.waste',        'Effet "wasted" GTA sur une image',                        'Fun',          '.waste [répondre à image]'),
  _Cmd('.compliment',   'Envoyer un compliment à quelqu\'un',                      'Fun',          '.compliment [@user]'),
  _Cmd('.insult',       'Insulter quelqu\'un (pour rire)',                          'Fun',          '.insult [@user]'),
  _Cmd('.8ball',        'Boule de cristal magique',                                'Fun',          '.8ball [question]'),
  _Cmd('.goodnight',    'Message bonne nuit (alias: .gn .lovenight)',              'Fun',          '.goodnight'),
  _Cmd('.shayari',      'Poème romantique (alias: .shayri)',                       'Fun',          '.shayari'),
  _Cmd('.roseday',      'Message rose du jour',                                    'Fun',          '.roseday'),
  _Cmd('.heart',        'Envoyer un message coeur animé',                          'Fun',          '.heart [@user]'),
  _Cmd('.tweet',        'Générer un faux tweet',                                   'Fun',          '.tweet [nom] [texte]'),
  _Cmd('.ytcomment',    'Générer un faux commentaire YouTube',                     'Fun',          '.ytcomment [nom] [texte]'),
  _Cmd('.oogway',       'Citation du Maître Oogway',                               'Fun',          '.oogway [texte]'),
  _Cmd('.namecard',     'Générer une carte avec ton nom',                          'Fun',          '.namecard [nom]'),
  _Cmd('.simpcard',     'Générer une carte simp stylisée',                         'Fun',          '.simpcard [@user]'),
  _Cmd('.horny',        'Filtre "Horny License" sur une image',                    'Fun',          '.horny [répondre à image]'),
  _Cmd('.circle',       'Cadrer une image en cercle',                              'Fun',          '.circle [répondre à image]'),
  _Cmd('.jail',         'Mettre quelqu\'un derrière les barreaux',                 'Fun',          '.jail [répondre à image]'),
  _Cmd('.triggered',    'Filtre "triggered" sur une image',                        'Fun',          '.triggered [répondre à image]'),
  _Cmd('.passed',       'Filtre "passed away"',                                    'Fun',          '.passed [répondre à image]'),
  _Cmd('.comrade',      'Filtre drapeau soviétique',                               'Fun',          '.comrade [répondre à image]'),
  _Cmd('.gay',          'Filtre drapeau LGBT sur une image',                       'Fun',          '.gay [répondre à image]'),

  // ──── ANIME ──────────────────────────────────────────────────────────────
  _Cmd('.animu',        'GIF anime aléatoire',                                     'Anime',        '.animu'),
  _Cmd('.hug',          'GIF anime : câlin',                                        'Anime',        '.hug [@user]'),
  _Cmd('.kiss',         'GIF anime : bisou',                                        'Anime',        '.kiss [@user]'),
  _Cmd('.pat',          'GIF anime : câlins sur la tête',                          'Anime',        '.pat [@user]'),
  _Cmd('.poke',         'GIF anime : poke',                                         'Anime',        '.poke [@user]'),
  _Cmd('.nom',          'GIF anime : manger',                                       'Anime',        '.nom [@user]'),
  _Cmd('.cry',          'GIF anime : pleurer',                                      'Anime',        '.cry'),
  _Cmd('.wink',         'GIF anime : clin d\'oeil',                                 'Anime',        '.wink'),
  _Cmd('.facepalm',     'GIF anime : facepalm',                                     'Anime',        '.facepalm'),
  _Cmd('.neko',         'Image neko aléatoire',                                    'Anime',        '.neko'),
  _Cmd('.waifu',        'Image waifu aléatoire',                                   'Anime',        '.waifu'),
  _Cmd('.animuquote',   'Citation anime aléatoire',                                'Anime',        '.animuquote'),

  // ──── JEUX ───────────────────────────────────────────────────────────────
  _Cmd('.ttt',          'Jouer au Tic-tac-toe (alias: .tictactoe)',                 'Jeux',         '.ttt @adversaire'),
  _Cmd('.move',         'Jouer un coup au Tic-tac-toe (position 1-9)',             'Jeux',         '.move [1-9]'),
  _Cmd('.surrender',    'Abandonner la partie en cours (alias: .abandon)',          'Jeux',         '.surrender'),
  _Cmd('.hangman',      'Commencer une partie de Pendu',                           'Jeux',         '.hangman'),
  _Cmd('.guess',        'Deviner une lettre (Pendu)',                               'Jeux',         '.guess [lettre]'),
  _Cmd('.trivia',       'Lancer un quiz (questions culturelles)',                   'Jeux',         '.trivia'),
  _Cmd('.answer',       'Répondre à une question du quiz',                         'Jeux',         '.answer [réponse]'),
  _Cmd('.roulette',     'Jouer à la roulette russe',                               'Jeux',         '.roulette'),
  _Cmd('.riddle',       'Recevoir une devinette',                                   'Jeux',         '.riddle'),
  _Cmd('.coinflip',     'Pile ou face',                                             'Jeux',         '.coinflip'),
  _Cmd('.rps',          'Pierre-feuille-ciseaux',                                  'Jeux',         '.rps [pierre|feuille|ciseaux]'),
  _Cmd('.topmembers',   'Classement des membres les plus actifs du groupe',        'Jeux',         '.topmembers'),

  // ──── FILTRES NATIONAUX ──────────────────────────────────────────────────
  _Cmd('.pies',         'Appliquer un filtre de drapeau sur une image',            'Filtres',      '.pies [pays]'),
  _Cmd('.china',        'Filtre drapeau Chine',                                    'Filtres',      '.china [répondre à image]'),
  _Cmd('.japan',        'Filtre drapeau Japon',                                    'Filtres',      '.japan [répondre à image]'),
  _Cmd('.korea',        'Filtre drapeau Corée',                                    'Filtres',      '.korea [répondre à image]'),
  _Cmd('.indonesia',    'Filtre drapeau Indonésie',                                'Filtres',      '.indonesia [répondre à image]'),
  _Cmd('.hijab',        'Filtre hijab sur une image',                              'Filtres',      '.hijab [répondre à image]'),
  _Cmd('.tonikawa',     'Filtre Tonikawa sur une image',                           'Filtres',      '.tonikawa [répondre à image]'),
  _Cmd('.lolice',       'Filtre Lolice sur une image',                             'Filtres',      '.lolice [répondre à image]'),
  _Cmd('.lgbt',         'Filtre drapeau LGBT sur une image',                       'Filtres',      '.lgbt [répondre à image]'),
  _Cmd('.its-so-stupid','Filtre "It\'s So Stupid"',                                'Filtres',      '.its-so-stupid [répondre à image]'),

  // ──── UTILITÉS ───────────────────────────────────────────────────────────
  _Cmd('.git',          'Lien GitHub du bot (alias: .github .sc .repo)',           'Utilitaires',  '.git'),
  _Cmd('.news',         'Afficher les dernières actualités',                       'Utilitaires',  '.news'),
  _Cmd('.weather',      'Météo d\'une ville',                                      'Utilitaires',  '.weather [ville]'),
  _Cmd('.emojimix',     'Mélanger deux emojis ensemble (alias: .emix)',            'Utilitaires',  '.emojimix [emoji1] [emoji2]'),
  _Cmd('.character',    'Deviner un personnage depuis une image',                  'Utilitaires',  '.character [répondre à image]'),
];

// Catégories
const _cats = [
  'Tout', 'Système', 'Admin', 'Médias', 'Téléchargements',
  'IA', 'Fun', 'Anime', 'Jeux', 'Filtres', 'Utilitaires',
];

// Couleurs par catégorie
const _catColors = <String, Color>{
  'Système':         Color(0xFF3498DB),
  'Admin':           Color(0xFFE74C3C),
  'Médias':          Color(0xFF9B59B6),
  'Téléchargements': Color(0xFFE67E22),
  'IA':              Color(0xFF1ABC9C),
  'Fun':             Color(0xFFF39C12),
  'Anime':           Color(0xFFE91E63),
  'Jeux':            Color(0xFF00BCD4),
  'Filtres':         Color(0xFF8BC34A),
  'Utilitaires':     Color(0xFF25D366),
};

class _Cmd {
  final String name, desc, cat, usage;
  const _Cmd(this.name, this.desc, this.cat, this.usage);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class CommandsScreen extends StatefulWidget {
  const CommandsScreen({super.key});
  @override
  State<CommandsScreen> createState() => _CommandsScreenState();
}

class _CommandsScreenState extends State<CommandsScreen> {
  String _search = '';
  String _cat    = 'Tout';

  List<_Cmd> get _filtered {
    var list = _cat == 'Tout'
        ? _allCommands
        : _allCommands.where((c) => c.cat == _cat).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((c) =>
          c.name.contains(q) ||
          c.desc.toLowerCase().contains(q) ||
          c.cat.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        // ── En-tête ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Commandes',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
                Text(
                  '${_allCommands.length} commandes · ${_filtered.length} affichées',
                  style: const TextStyle(color: _muted, fontSize: 13)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: _g.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _g.withOpacity(.25))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.terminal_rounded, size: 12, color: _g),
                  SizedBox(width: 4),
                  Text('WABOT', style: TextStyle(color: _g, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),

            // Recherche
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border)),
              child: Row(children: [
                const Icon(Icons.search_rounded, size: 16, color: _muted),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontSize: 13, color: _ink),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher une commande…',
                    hintStyle: TextStyle(color: _muted, fontSize: 13),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                )),
                if (_search.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _search = ''),
                    child: const Icon(Icons.close_rounded, size: 16, color: _muted),
                  ),
              ]),
            ),
            const SizedBox(height: 10),

            // Chips de catégories
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final sel = _cats[i] == _cat;
                  final col = _catColors[_cats[i]] ?? _g;
                  final count = _cats[i] == 'Tout'
                      ? _allCommands.length
                      : _allCommands.where((c) => c.cat == _cats[i]).length;
                  return GestureDetector(
                    onTap: () => setState(() => _cat = _cats[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? col : _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? col : _border),
                      ),
                      child: Text(
                        '${_cats[i]} $count',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : _muted,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ]),
        ),

        // ── Liste ─────────────────────────────────────────────────────────
        Expanded(
          child: list.isEmpty
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.search_off_rounded, color: _muted, size: 36),
                  SizedBox(height: 10),
                  Text('Aucune commande trouvée',
                      style: TextStyle(color: _muted, fontSize: 14)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (_, i) => _CmdTile(cmd: list[i]),
                ),
        ),
      ]),
    );
  }
}

// ─── Tuile commande ───────────────────────────────────────────────────────────
class _CmdTile extends StatelessWidget {
  final _Cmd cmd;
  const _CmdTile({required this.cmd});

  @override
  Widget build(BuildContext context) {
    final color = _catColors[cmd.cat] ?? _g;
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: cmd.name));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${cmd.name} copié !'),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.15)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icône catégorie
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(_catIcon(cmd.cat), size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Nom + badge catégorie
            Row(children: [
              Flexible(
                child: Text(cmd.name,
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800,
                        color: color, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withOpacity(.10),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(cmd.cat,
                    style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 3),
            // Description
            Text(cmd.desc,
                style: const TextStyle(fontSize: 12, color: _muted),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            // Usage
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFF1A1D21),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border)),
              child: Text(cmd.usage,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: _ink.withOpacity(.75),
                      fontFamily: 'monospace'),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ])),
          // Hint copie
          const SizedBox(width: 6),
          const Icon(Icons.copy_outlined, size: 13, color: _muted),
        ]),
      ),
    );
  }

  IconData _catIcon(String cat) {
    switch (cat) {
      case 'Système':         return Icons.settings_rounded;
      case 'Admin':           return Icons.admin_panel_settings_rounded;
      case 'Médias':          return Icons.image_rounded;
      case 'Téléchargements': return Icons.download_rounded;
      case 'IA':              return Icons.smart_toy_rounded;
      case 'Fun':             return Icons.emoji_emotions_rounded;
      case 'Anime':           return Icons.auto_awesome_rounded;
      case 'Jeux':            return Icons.sports_esports_rounded;
      case 'Filtres':         return Icons.filter_rounded;
      case 'Utilitaires':     return Icons.build_rounded;
      default:                return Icons.terminal_rounded;
    }
  }
}
