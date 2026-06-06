import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _g      = Color(0xFF25D366);
const _gd     = Color(0xFF128C7E);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF8A9199);
const _border = Color(0xFF1E2128);
const _card   = Color(0xFF111316);
const _bg     = Color(0xFF0D0E11);

// ─── Modèle ──────────────────────────────────────────────────────────────────
class _Cmd {
  final String name;
  final String desc;
  final String usage;
  final String? example;
  final bool adminOnly;
  const _Cmd(this.name, this.desc, {String? usage, this.example, this.adminOnly = false})
      : usage = usage ?? '.$name';
}

class _Cat {
  final String label;
  final IconData icon;
  final Color color;
  final List<_Cmd> cmds;
  const _Cat({required this.label, required this.icon, required this.color, required this.cmds});
}

// ─── Données ─────────────────────────────────────────────────────────────────
const List<_Cat> _kCats = [
  _Cat(label: 'Système', icon: Icons.settings_rounded, color: Color(0xFF25D366), cmds: [
    _Cmd('ping',    'Vérifie si le bot est actif et mesure la latence', example: '.ping'),
    _Cmd('alive',   'Affiche le statut complet du bot (uptime, version)', example: '.alive'),
    _Cmd('help',    'Liste toutes les commandes disponibles', usage: '.help [commande]', example: '.help play'),
    _Cmd('cmd',     'Alias de .help — liste toutes les commandes', example: '.cmd'),
    _Cmd('lang',    'Change la langue du bot', usage: '.lang <fr|en|es>', example: '.lang fr'),
    _Cmd('alias',   'Crée un alias personnalisé pour une commande', usage: '.alias <cmd> <alias>', example: '.alias help aide'),
    _Cmd('owner',   'Affiche les infos du propriétaire du bot', example: '.owner'),
    _Cmd('git',     'Affiche le lien GitHub du bot', example: '.git'),
    _Cmd('connect', 'Reconnecte le bot à WhatsApp', example: '.connect', adminOnly: true),
    _Cmd('update',  'Vérifie et installe les mises à jour', example: '.update', adminOnly: true),
    _Cmd('changelog','Affiche le journal des modifications', example: '.changelog'),
    _Cmd('autotyping','Active/désactive l\'indicateur de frappe automatique', usage: '.autotyping <on|off>', adminOnly: true),
    _Cmd('autoread', 'Active/désactive la lecture automatique des messages', usage: '.autoread <on|off>', adminOnly: true),
    _Cmd('cleartmp', 'Nettoie les fichiers temporaires du bot', example: '.cleartmp', adminOnly: true),
    _Cmd('jid',     'Affiche le JID (identifiant) WhatsApp du chat', example: '.jid'),
  ]),
  _Cat(label: 'Médias', icon: Icons.photo_library_rounded, color: Color(0xFF57B6FF), cmds: [
    _Cmd('sticker', 'Convertit une image/vidéo en sticker', usage: '.sticker', example: 'Envoie une image puis .sticker'),
    _Cmd('attp',    'Transforme du texte en sticker animé', usage: '.attp <texte>', example: '.attp WABOT'),
    _Cmd('tts',     'Convertit du texte en message vocal', usage: '.tts <texte>', example: '.tts Bonjour tout le monde'),
    _Cmd('dvo',     'Convertit un vocal en texte (transcription)', example: 'Reply à un vocal + .dvo'),
    _Cmd('vv',      'Rend visible un message "view-once"', example: 'Reply à un view-once + .vv'),
    _Cmd('blur',    'Applique un flou artistique à une image', example: 'Reply à une image + .blur'),
    _Cmd('crop',    'Recadre une image', example: 'Reply à une image + .crop'),
    _Cmd('removebg','Supprime le fond d\'une image', example: 'Reply à une image + .removebg'),
    _Cmd('remini',  'Améliore la qualité d\'une photo floue', example: 'Reply à une image + .remini'),
    _Cmd('imagine', 'Génère une image par IA', usage: '.imagine <description>', example: '.imagine paysage futuriste'),
    _Cmd('circle',  'Met une image en forme circulaire', example: 'Reply à une image + .circle'),
    _Cmd('tweet',   'Génère une fausse capture Twitter/X', usage: '.tweet <texte>', example: '.tweet Je suis le meilleur bot'),
    _Cmd('ytcomment','Génère une fausse capture YouTube', usage: '.ytcomment <texte>', example: '.ytcomment Super vidéo !'),
    _Cmd('emojimix','Mélange deux emojis en une image unique', usage: '.emojimix <emoji1><emoji2>', example: '.emojimix 🐱🔥'),
    _Cmd('ss',      'Capture d\'écran d\'un site web', usage: '.ss <url>', example: '.ss https://google.com'),
    _Cmd('simage',  'Envoie une image sauvegardée', example: 'Reply à une image + .simage'),
    _Cmd('svideo',  'Envoie une vidéo sauvegardée', example: 'Reply à une vidéo + .svideo'),
  ]),
  _Cat(label: 'Musique & Vidéo', icon: Icons.music_note_rounded, color: Color(0xFFFF6B9D), cmds: [
    _Cmd('play',      'Télécharge de la musique depuis YouTube', usage: '.play <titre ou artiste>', example: '.play Stromae Alors on danse'),
    _Cmd('music',     'Alias de .play', usage: '.music <titre>', example: '.music Drake'),
    _Cmd('video',     'Télécharge une vidéo YouTube', usage: '.video <titre>', example: '.video How to code'),
    _Cmd('tiktok',    'Télécharge une vidéo TikTok sans filigrane', usage: '.tiktok <url>', example: '.tiktok https://tiktok.com/...'),
    _Cmd('instagram', 'Télécharge une vidéo/photo Instagram', usage: '.instagram <url>', example: '.instagram https://instagram.com/...'),
    _Cmd('fb',        'Télécharge une vidéo Facebook', usage: '.fb <url>', example: '.fb https://facebook.com/...'),
    _Cmd('yta',       'Télécharge l\'audio d\'une vidéo YouTube', usage: '.yta <url>', example: '.yta https://youtu.be/...'),
    _Cmd('ytsearch',  'Recherche des vidéos sur YouTube', usage: '.ytsearch <requête>', example: '.ytsearch tutoriel Flutter'),
    _Cmd('lyrics',    'Affiche les paroles d\'une chanson', usage: '.lyrics <titre - artiste>', example: '.lyrics Bohemian Rhapsody Queen'),
    _Cmd('transcribe','Transcrit un message vocal en texte', example: 'Reply à un vocal + .transcribe'),
  ]),
  _Cat(label: 'IA & Traduction', icon: Icons.psychology_rounded, color: Color(0xFF9B59B6), cmds: [
    _Cmd('gpt',       'Pose une question à l\'IA (ChatGPT)', usage: '.gpt <question>', example: '.gpt Qu\'est-ce que l\'univers ?'),
    _Cmd('chatbot',   'Active/désactive le mode chatbot IA dans le groupe', usage: '.chatbot <on|off>', adminOnly: true),
    _Cmd('translate', 'Traduit un texte dans la langue souhaitée', usage: '.translate <langue> <texte>', example: '.translate en Bonjour monde'),
    _Cmd('tg',        'Traduit en français', usage: '.tg <texte>', example: '.tg Hello world'),
    _Cmd('tss',       'Traduit en espagnol', usage: '.tss <texte>', example: '.tss Good morning'),
    _Cmd('ts',        'Traduit automatiquement', usage: '.ts <texte>'),
    _Cmd('weather',   'Affiche la météo d\'une ville', usage: '.weather <ville>', example: '.weather Brazzaville'),
    _Cmd('news',      'Affiche les dernières actualités', example: '.news'),
    _Cmd('bug',       'Signale un bug au développeur', usage: '.bug <description>', example: '.bug La commande .play plante'),
    _Cmd('suggest',   'Envoie une suggestion au développeur', usage: '.suggest <idée>', example: '.suggest Ajoute la commande .radio'),
  ]),
  _Cat(label: 'Administration', icon: Icons.admin_panel_settings_rounded, color: Color(0xFFE74C3C), cmds: [
    _Cmd('ban',          'Bannit et expulse un membre du groupe', usage: '.ban @membre', example: '.ban @Jean', adminOnly: true),
    _Cmd('unban',        'Lève le bannissement d\'un membre', usage: '.unban @membre', adminOnly: true),
    _Cmd('kick',         'Expulse un membre sans bannissement', usage: '.kick @membre', example: '.kick @Jean', adminOnly: true),
    _Cmd('mute',         'Met le groupe en lecture seule', usage: '.mute [durée en min]', example: '.mute 30', adminOnly: true),
    _Cmd('unmute',       'Réactive les messages dans le groupe', adminOnly: true),
    _Cmd('warn',         'Avertit un membre (3 = ban auto)', usage: '.warn @membre [raison]', example: '.warn @Jean spam', adminOnly: true),
    _Cmd('warnings',     'Voir les avertissements d\'un membre', usage: '.warnings @membre', adminOnly: true),
    _Cmd('promote',      'Promeut un membre en admin', usage: '.promote @membre', adminOnly: true),
    _Cmd('demote',       'Retire les droits admin d\'un membre', usage: '.demote @membre', adminOnly: true),
    _Cmd('tagall',       'Mentionne tous les membres du groupe', example: '.tagall Message important !', adminOnly: true),
    _Cmd('antilink',     'Active/désactive la suppression des liens', usage: '.antilink <on|off>', adminOnly: true),
    _Cmd('antitag',      'Protection contre les tags en masse', usage: '.antitag <on|off>', adminOnly: true),
    _Cmd('antibadword',  'Filtre les mots interdits automatiquement', usage: '.antibadword <on|off>', adminOnly: true),
    _Cmd('antidelete',   'Détecte les messages supprimés', usage: '.antidelete <on|off>', adminOnly: true),
    _Cmd('welcome',      'Personnalise le message de bienvenue', usage: '.welcome <message>', adminOnly: true),
    _Cmd('goodbye',      'Personnalise le message d\'au revoir', usage: '.goodbye <message>', adminOnly: true),
    _Cmd('setname',      'Change le nom du groupe', usage: '.setname <nouveau nom>', adminOnly: true),
    _Cmd('setdesc',      'Change la description du groupe', usage: '.setdesc <texte>', adminOnly: true),
    _Cmd('seticon',      'Change l\'icône du groupe', example: 'Envoie une image + .seticon', adminOnly: true),
    _Cmd('groupsetting', 'Gère les paramètres du groupe', usage: '.groupsetting <option>', adminOnly: true),
    _Cmd('resetlink',    'Réinitialise le lien d\'invitation', adminOnly: true),
    _Cmd('leave',        'Fait quitter le bot du groupe', adminOnly: true),
    _Cmd('sudo',         'Commande réservée au propriétaire du bot', adminOnly: true),
    _Cmd('setpp',        'Change la photo de profil du bot', adminOnly: true),
  ]),
  _Cat(label: 'Groupe & Social', icon: Icons.groups_rounded, color: Color(0xFF1ABC9C), cmds: [
    _Cmd('tag',         'Mentionne des membres avec un message', usage: '.tag @membre <message>', example: '.tag @Jean Viens voir ça'),
    _Cmd('topmembers',  'Classement des membres les plus actifs', example: '.topmembers'),
    _Cmd('groupinfo',   'Affiche les informations détaillées du groupe', example: '.groupinfo'),
    _Cmd('staff',       'Affiche la liste des admins du groupe', example: '.staff'),
    _Cmd('jid',         'Affiche le JID WhatsApp du chat/membre', example: '.jid'),
    _Cmd('flirt',       'Envoie un message flirty à quelqu\'un', usage: '.flirt @membre'),
    _Cmd('ship',        'Calcule la compatibilité entre deux membres', usage: '.ship @membre1 @membre2'),
    _Cmd('simp',        'Taquine quelqu\'un en mode simp', usage: '.simp @membre'),
    _Cmd('compliment',  'Envoie un compliment à quelqu\'un', usage: '.compliment @membre'),
    _Cmd('insult',      'Envoie une taquinerie à quelqu\'un', usage: '.insult @membre'),
    _Cmd('goodnight',   'Envoie un message bonne nuit au groupe', example: '.goodnight'),
    _Cmd('companion',   'Gère les bots compagnons du bot principal', usage: '.companion <option>', adminOnly: true),
    _Cmd('notify',      'Envoie une notification au groupe', usage: '.notify <message>', adminOnly: true),
  ]),
  _Cat(label: 'Jeux & Fun', icon: Icons.sports_esports_rounded, color: Color(0xFFE67E22), cmds: [
    _Cmd('meme',     'Envoie un mème aléatoire', example: '.meme'),
    _Cmd('joke',     'Envoie une blague aléatoire', example: '.joke'),
    _Cmd('quote',    'Envoie une citation inspirante', example: '.quote'),
    _Cmd('fact',     'Envoie un fait insolite ou scientifique', example: '.fact'),
    _Cmd('dare',     'Défi aléatoire (jeu vérité ou défi)', example: '.dare'),
    _Cmd('truth',    'Question vérité aléatoire', example: '.truth'),
    _Cmd('8ball',    'Boule magique — répond oui/non à tes questions', usage: '.8ball <question>', example: '.8ball Est-ce que je vais réussir ?'),
    _Cmd('roulette', 'Jeu de roulette russe', example: '.roulette'),
    _Cmd('coinflip', 'Lance une pièce (pile ou face)', example: '.coinflip'),
    _Cmd('rps',      'Pierre, papier, ciseaux contre le bot', usage: '.rps <pierre|papier|ciseaux>', example: '.rps pierre'),
    _Cmd('trivia',   'Pose une question de culture générale', example: '.trivia'),
    _Cmd('answer',   'Répond à une question de trivia en cours', usage: '.answer <réponse>', example: '.answer Paris'),
    _Cmd('hangman',  'Jeu du pendu', example: '.hangman'),
    _Cmd('guess',    'Devine la lettre dans le jeu du pendu', usage: '.guess <lettre>', example: '.guess a'),
    _Cmd('riddle',   'Envoie une devinette', example: '.riddle'),
    _Cmd('ttt',      'Lance une partie de Tic-Tac-Toe', example: '.ttt @adversaire'),
    _Cmd('move',     'Joue un coup dans le Tic-Tac-Toe', usage: '.move <1-9>', example: '.move 5'),
  ]),
  _Cat(label: 'Texte Stylisé', icon: Icons.text_fields_rounded, color: Color(0xFFFF9F43), cmds: [
    _Cmd('metallic',   'Texte stylisé effet métal brillant', usage: '.metallic <texte>', example: '.metallic WABOT'),
    _Cmd('ice',        'Texte stylisé effet glace cristalline', usage: '.ice <texte>', example: '.ice WABOT'),
    _Cmd('impressive', 'Texte stylisé effet impressionnant', usage: '.impressive <texte>'),
    _Cmd('matrix',     'Texte stylisé effet Matrix vert', usage: '.matrix <texte>', example: '.matrix Neo'),
    _Cmd('christmas',  'Texte stylisé thème Noël', usage: '.christmas <texte>'),
    _Cmd('cyber',      'Texte stylisé effet cyberpunk', usage: '.cyber <texte>'),
    _Cmd('graffiti',   'Texte stylisé effet graffiti urbain', usage: '.graffiti <texte>'),
    _Cmd('water',      'Texte stylisé effet eau', usage: '.water <texte>'),
    _Cmd('electric',   'Texte stylisé effet électrique', usage: '.electric <texte>'),
    _Cmd('lava',       'Texte stylisé effet lave volcanique', usage: '.lava <texte>'),
    _Cmd('wooden',     'Texte stylisé effet bois', usage: '.wooden <texte>'),
    _Cmd('glass',      'Texte stylisé effet verre', usage: '.glass <texte>'),
    _Cmd('comic',      'Texte stylisé effet bande dessinée', usage: '.comic <texte>'),
  ]),
  _Cat(label: 'Sondages', icon: Icons.how_to_vote_rounded, color: Color(0xFF3498DB), cmds: [
    _Cmd('poll',        'Crée un sondage dans le groupe', usage: '.poll <question> | <option1> | <option2>', example: '.poll Meilleur bot ? | WABOT | Autres'),
    _Cmd('vote',        'Vote pour une option d\'un sondage actif', usage: '.vote <numéro>', example: '.vote 1'),
    _Cmd('pollresults', 'Affiche les résultats du sondage en cours', example: '.pollresults'),
    _Cmd('endpoll',     'Termine le sondage et affiche les résultats finals', example: '.endpoll', adminOnly: true),
    _Cmd('polls',       'Liste les sondages récents du groupe', example: '.polls'),
  ]),
];

// ─── Écran principal ─────────────────────────────────────────────────────────
class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});
  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  String _search     = '';
  int    _catIndex   = -1; // -1 = toutes les catégories
  _Cmd?  _expanded;

  List<_Cat> get _filtered {
    if (_search.isEmpty && _catIndex < 0) return _kCats;
    var cats = _catIndex >= 0 ? [_kCats[_catIndex]] : _kCats;
    if (_search.isEmpty) return cats;
    final q = _search.toLowerCase();
    return cats.map((c) {
      final cmds = c.cmds.where((cmd) =>
          cmd.name.contains(q) ||
          cmd.desc.toLowerCase().contains(q) ||
          cmd.usage.contains(q)).toList();
      return cmds.isEmpty ? null : _Cat(label: c.label, icon: c.icon, color: c.color, cmds: cmds);
    }).whereType<_Cat>().toList();
  }

  int get _totalFiltered => _filtered.fold(0, (s, c) => s + c.cmds.length);

  @override
  Widget build(BuildContext context) {
    final cats = _filtered;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        // ── Top bar ──
        Container(
          color: const Color(0xFF0A0C0F),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Documentation', style: TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w800, color: _ink)),
                const SizedBox(height: 2),
                Text('$_totalFiltered commandes disponibles',
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _g.withOpacity(.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _g.withOpacity(.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.book_rounded, size: 13, color: _g),
                  SizedBox(width: 5),
                  Text('v2.0', style: TextStyle(color: _g, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),

            // Barre de recherche
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(children: [
                const Icon(Icons.search_rounded, size: 16, color: _muted),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  onChanged: (v) => setState(() { _search = v; _expanded = null; }),
                  style: const TextStyle(fontSize: 13, color: _ink),
                  decoration: const InputDecoration(
                    hintText: 'Chercher une commande…',
                    hintStyle: TextStyle(color: _muted, fontSize: 13),
                    border: InputBorder.none, isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                )),
                if (_search.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() { _search = ''; _expanded = null; }),
                    child: const Icon(Icons.close_rounded, size: 16, color: _muted)),
              ]),
            ),
            const SizedBox(height: 10),

            // Chips catégories
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _Chip(label: 'Tout', selected: _catIndex < 0,
                    color: _g, onTap: () => setState(() => _catIndex = -1)),
                  ...List.generate(_kCats.length, (i) => _Chip(
                    label: _kCats[i].label,
                    selected: _catIndex == i,
                    color: _kCats[i].color,
                    onTap: () => setState(() {
                      _catIndex = _catIndex == i ? -1 : i;
                      _expanded = null;
                    }),
                  )),
                ],
              ),
            ),
          ]),
        ),

        // ── Liste des commandes ──
        Expanded(
          child: cats.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off_rounded, color: _muted.withOpacity(.4), size: 48),
                const SizedBox(height: 12),
                Text('Aucune commande pour "$_search"',
                    style: const TextStyle(color: _muted, fontSize: 14)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
                itemCount: cats.length,
                itemBuilder: (_, ci) {
                  final cat = cats[ci];
                  return _CatSection(
                    cat:      cat,
                    expanded: _expanded,
                    onToggle: (cmd) => setState(() =>
                        _expanded = _expanded?.name == cmd.name ? null : cmd),
                  );
                },
              ),
        ),
      ]),
    );
  }
}

// ─── Section catégorie ────────────────────────────────────────────────────────
class _CatSection extends StatelessWidget {
  final _Cat cat;
  final _Cmd? expanded;
  final ValueChanged<_Cmd> onToggle;
  const _CatSection({required this.cat, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // En-tête catégorie
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: cat.color.withOpacity(.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(cat.icon, size: 14, color: cat.color),
          ),
          const SizedBox(width: 8),
          Text(cat.label.toUpperCase(), style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: cat.color, letterSpacing: 1.2)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cat.color.withOpacity(.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${cat.cmds.length}',
                style: TextStyle(fontSize: 9, color: cat.color, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),

      // Commandes
      ...cat.cmds.map((cmd) => _CmdTile(
        cmd: cmd, catColor: cat.color,
        isExpanded: expanded?.name == cmd.name,
        onTap: () => onToggle(cmd),
      )),
      const SizedBox(height: 4),
    ]);
  }
}

// ─── Tuile commande ───────────────────────────────────────────────────────────
class _CmdTile extends StatelessWidget {
  final _Cmd cmd;
  final Color catColor;
  final bool isExpanded;
  final VoidCallback onTap;
  const _CmdTile({required this.cmd, required this.catColor, required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isExpanded ? catColor.withOpacity(.07) : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpanded ? catColor.withOpacity(.35) : _border,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Ligne principale
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              // Badge commande
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: catColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: catColor.withOpacity(.2)),
                ),
                child: Text('.${cmd.name}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                        color: catColor, fontFamily: 'monospace')),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(cmd.desc,
                  style: const TextStyle(fontSize: 12.5, color: _ink),
                  maxLines: isExpanded ? 10 : 1,
                  overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              if (cmd.adminOnly)
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE74C3C).withOpacity(.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_rounded, size: 10, color: Color(0xFFE74C3C)),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: isExpanded ? catColor : _muted),
              ),
            ]),
          ),

          // Détails (expanded)
          if (isExpanded) ...[
            Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 14),
                color: catColor.withOpacity(.15)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Usage
                _DetailRow(
                  icon: Icons.code_rounded,
                  label: 'Syntaxe',
                  child: GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: cmd.usage));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Copié : ${cmd.usage}'),
                            backgroundColor: catColor, duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF080A0C),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: catColor.withOpacity(.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(cmd.usage,
                            style: TextStyle(fontSize: 12, color: catColor,
                                fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 11, color: catColor.withOpacity(.6)),
                      ]),
                    ),
                  ),
                ),

                // Exemple
                if (cmd.example != null) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.lightbulb_outline_rounded,
                    label: 'Exemple',
                    child: Text(cmd.example!,
                        style: TextStyle(fontSize: 12, color: _muted,
                            fontFamily: 'monospace')),
                  ),
                ],

                // Admin only badge
                if (cmd.adminOnly) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE74C3C).withOpacity(.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE74C3C).withOpacity(.2)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.shield_rounded, size: 12, color: Color(0xFFE74C3C)),
                      SizedBox(width: 5),
                      Text('Admin uniquement',
                          style: TextStyle(fontSize: 11, color: Color(0xFFE74C3C),
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _DetailRow({required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 13, color: _muted),
      const SizedBox(width: 6),
      Text('$label : ', style: const TextStyle(fontSize: 11, color: _muted)),
      Flexible(child: child),
    ],
  );
}

// ─── Chip filtre ──────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(.15) : _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color.withOpacity(.5) : _border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(label, style: TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w600,
          color: selected ? color : _muted)),
    ),
  );
}
