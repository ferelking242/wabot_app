import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _g      = Color(0xFF25D366);
const _gd     = Color(0xFF128C7E);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF8A9199);
const _border = Color(0xFF1E2128);
const _card   = Color(0xFF111316);
const _bg     = Color(0xFF0D0E11);

class CommandsScreen extends StatefulWidget {
  const CommandsScreen({super.key});
  @override
  State<CommandsScreen> createState() => _CommandsScreenState();
}

class _CommandsScreenState extends State<CommandsScreen> {
  String _search = '';
  String _cat    = 'Tout';

  static const _cats = ['Tout', 'Utilitaires', 'Media', 'Groupes', 'Fun', 'Info', 'Admin'];

  static const _commands = [
    // UTILITAIRES
    _Cmd('.ping',      'Vérifie si le bot est en ligne',              'Utilitaires', '.ping'),
    _Cmd('.help',      'Affiche l\'aide et les commandes disponibles', 'Utilitaires', '.help'),
    _Cmd('.menu',      'Alias de .help',                               'Utilitaires', '.menu'),
    _Cmd('.tts',       'Texte vers audio : .tts Bonjour',              'Utilitaires', '.tts [texte]'),
    _Cmd('.translate', 'Traduit un texte : .translate fr Bonjour',     'Utilitaires', '.translate [lang] [texte]'),
    _Cmd('.sticker',   'Convertit une image/vidéo en sticker',         'Utilitaires', '.sticker'),
    _Cmd('.toimg',     'Convertit un sticker en image',                'Utilitaires', '.toimg'),
    _Cmd('.weather',   'Météo d\'une ville : .weather Brazzaville',    'Utilitaires', '.weather [ville]'),
    _Cmd('.qr',        'Génère un QR code : .qr https://...',          'Utilitaires', '.qr [texte/url]'),
    _Cmd('.calc',      'Calcul : .calc 10*5+2',                        'Utilitaires', '.calc [expression]'),
    _Cmd('.time',      'Heure actuelle dans une ville',                 'Utilitaires', '.time [ville]'),
    // MEDIA
    _Cmd('.dvo',       'Révèle un média vue unique (répondre au msg)', 'Media', '.dvo | .dvo h | .dvo save'),
    _Cmd('.vv',        'Alias de .dvo',                                'Media', '.vv'),
    _Cmd('.yt',        'Télécharge un audio YouTube',                  'Media', '.yt [url]'),
    _Cmd('.ytv',       'Télécharge une vidéo YouTube',                 'Media', '.ytv [url]'),
    _Cmd('.tiktok',    'Télécharge une vidéo TikTok',                  'Media', '.tiktok [url]'),
    _Cmd('.play',      'Joue de la musique : .play Rihanna',           'Media', '.play [titre]'),
    // GROUPES
    _Cmd('.kick',      'Exclure un membre (répondre au msg)',           'Groupes', '.kick'),
    _Cmd('.add',       'Ajouter un membre : .add +242...',              'Groupes', '.add [numéro]'),
    _Cmd('.promote',   'Promouvoir en admin (répondre)',                'Groupes', '.promote'),
    _Cmd('.demote',    'Rétrograder un admin (répondre)',               'Groupes', '.demote'),
    _Cmd('.mute',      'Activer le mode silencieux',                    'Groupes', '.mute'),
    _Cmd('.unmute',    'Désactiver le mode silencieux',                 'Groupes', '.unmute'),
    _Cmd('.link',      'Obtenir le lien d\'invitation du groupe',       'Groupes', '.link'),
    _Cmd('.groupinfo', 'Informations sur le groupe',                    'Groupes', '.groupinfo'),
    // FUN
    _Cmd('.joke',      'Envoie une blague aléatoire',                  'Fun', '.joke'),
    _Cmd('.fact',      'Envoie un fait aléatoire',                     'Fun', '.fact'),
    _Cmd('.simp',      'Vérifie si quelqu\'un est un simp',             'Fun', '.simp | .simp @user'),
    _Cmd('.rate',      'Évalue quelque chose : .rate Messi',           'Fun', '.rate [texte]'),
    _Cmd('.ship',      'Calcule la compatibilité entre deux personnes', 'Fun', '.ship @user1 @user2'),
    _Cmd('.roast',     'Critique une personne (fun) : .roast @user',   'Fun', '.roast @user'),
    // INFO
    _Cmd('.profil',    'Affiche le profil d\'un utilisateur',           'Info', '.profil | .profil @user'),
    _Cmd('.getpp',     'Télécharge la photo de profil',                 'Info', '.getpp | .getpp @user'),
    _Cmd('.bio',       'Définir sa bio : .bio [texte]',                'Info', '.bio [texte]'),
    // ADMIN
    _Cmd('.ban',       'Bannir un utilisateur du bot',                  'Admin', '.ban @user'),
    _Cmd('.unban',     'Débannir un utilisateur',                       'Admin', '.unban @user'),
    _Cmd('.broadcast', 'Diffuser un message à tous les groupes',        'Admin', '.broadcast [msg]'),
    _Cmd('.restart',   'Redémarrer le bot',                             'Admin', '.restart'),
    _Cmd('.status',    'Statut détaillé du bot',                        'Admin', '.status'),
  ];

  List<_Cmd> get _filtered {
    var list = _cat == 'Tout' ? _commands : _commands.where((c) => c.cat == _cat).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((c) => c.name.contains(q) || c.desc.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Commandes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
                Text('${_commands.length} commandes disponibles', style: const TextStyle(color: _muted, fontSize: 13)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _g.withOpacity(.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _g.withOpacity(.25))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.terminal_rounded, size: 12, color: _g),
                  SizedBox(width: 4),
                  Text('WABOT', style: TextStyle(color: _g, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            // Search bar
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
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontSize: 13, color: _ink),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher une commande…',
                    hintStyle: TextStyle(color: _muted, fontSize: 13),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                )),
              ]),
            ),
            const SizedBox(height: 12),
            // Category chips
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final sel = _cats[i] == _cat;
                  return GestureDetector(
                    onTap: () => setState(() => _cat = _cats[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? _g : _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? _g : _border),
                      ),
                      child: Text(_cats[i], style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : _muted)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ]),
        ),
        Expanded(
          child: list.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off_rounded, color: _muted, size: 36),
                SizedBox(height: 10),
                Text('Aucune commande trouvée', style: TextStyle(color: _muted, fontSize: 14)),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _CmdTile(cmd: list[i]),
              ),
        ),
      ]),
    );
  }
}

class _Cmd {
  final String name, desc, cat, usage;
  const _Cmd(this.name, this.desc, this.cat, this.usage);
}

final _catColors = <String, Color>{
  'Utilitaires': Color(0xFF3498DB),
  'Media':       Color(0xFF9B59B6),
  'Groupes':     Color(0xFF1ABC9C),
  'Fun':         Color(0xFFE67E22),
  'Info':        Color(0xFF25D366),
  'Admin':       Color(0xFFE74C3C),
};

class _CmdTile extends StatelessWidget {
  final _Cmd cmd;
  const _CmdTile({required this.cmd});

  @override
  Widget build(BuildContext context) {
    final color = _catColors[cmd.cat] ?? const Color(0xFF25D366);
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: cmd.name));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${cmd.name} copié !'),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.18)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.terminal_rounded, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(cmd.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(20)),
                child: Text(cmd.cat, style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 3),
            Text(cmd.desc, style: const TextStyle(fontSize: 12.5, color: _muted)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D21),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Text(cmd.usage, style: TextStyle(fontSize: 11, color: _ink.withOpacity(.8), fontFamily: 'monospace')),
            ),
          ])),
        ]),
      ),
    );
  }
}
