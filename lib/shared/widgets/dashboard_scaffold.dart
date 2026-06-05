import 'package:flutter/material.dart';
import 'surface.dart';

const _green  = Color(0xFF25D366);
const _greenDk = Color(0xFF128C7E);
const _accent = Color(0xFF34E07E);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF8A9199);
const _border = Color(0xFF1E2128);
const _white  = Colors.white;
const _bg     = Color(0xFF0D0E11);
const _card   = Color(0xFF111316);

class DashboardScaffold extends StatelessWidget {
  final List<DashStat> stats;
  final List<DashSection> sections;
  final List<ExploreCard>? explore;
  const DashboardScaffold({super.key, required this.stats, required this.sections, this.explore});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _PeriodBar(),
          const SizedBox(height: 16),
          _StatsGrid(stats: stats),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (_, c) {
            if (c.maxWidth > 720 && sections.length > 1) {
              return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, mainAxisExtent: 182),
                itemCount: sections.length, itemBuilder: (_, i) => _SectionCard(section: sections[i]));
            }
            return Column(children: [for (final s in sections) ...[_SectionCard(section: s), const SizedBox(height: 14)]]);
          }),
          if (explore != null && explore!.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('Explorer la plateforme',
              style: TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w800))),
            _ExploreGrid(cards: explore!),
          ],
        ]),
      ),
    );
  }
}

class _PeriodBar extends StatefulWidget { @override State<_PeriodBar> createState() => _PBState(); }
class _PBState extends State<_PeriodBar> {
  int _sel = 0;
  final _chips = ["Aujourd'hui", '7 jours', '30 jours', 'Ce mois'];
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
      Container(height: 34, padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
        child: const Row(children: [
          Icon(Icons.calendar_today_outlined, size: 13, color: _muted),
          SizedBox(width: 6),
          Text('Période', style: TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.w500)),
          SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 14, color: _muted),
        ])),
      const SizedBox(width: 8),
      for (int i = 0; i < _chips.length; i++) ...[
        GestureDetector(onTap: () => setState(() => _sel = i),
          child: AnimatedContainer(duration: const Duration(milliseconds: 180), height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center,
            decoration: _sel == i
              ? BoxDecoration(gradient: const LinearGradient(colors: [_greenDk, _green], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: _green.withOpacity(.28), blurRadius: 10, offset: const Offset(0, 4))])
              : BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
            child: Text(_chips[i], style: TextStyle(fontSize: 12, color: _sel == i ? _white : _muted, fontWeight: _sel == i ? FontWeight.w700 : FontWeight.w500)),
          )),
        if (i < _chips.length - 1) const SizedBox(width: 6),
      ],
    ]));
  }
}

class _StatsGrid extends StatelessWidget {
  final List<DashStat> stats;
  const _StatsGrid({required this.stats});
  static const _colors = [_green, _accent, Color(0xFFF59E0B), _greenDk];
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 980 ? 4 : 2;
      return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 96),
        itemCount: stats.length, itemBuilder: (_, i) => _StatCard(stat: stats[i], color: _colors[i % _colors.length]));
    });
  }
}

class _StatCard extends StatelessWidget {
  final DashStat stat; final Color color;
  const _StatCard({required this.stat, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    decoration: WabotSurface.accent(color: color, radius: 14),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 30, height: 30, decoration: BoxDecoration(color: color.withOpacity(.18), borderRadius: BorderRadius.circular(9)),
          child: Icon(stat.icon, size: 15, color: color)),
        const SizedBox(width: 8),
        Expanded(child: Text(stat.label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: color.withOpacity(.75), fontWeight: FontWeight.w600))),
      ]),
      const Spacer(),
      Text(stat.value, style: TextStyle(fontSize: 24, color: color, fontWeight: FontWeight.w900)),
    ]),
  );
}

class _SectionCard extends StatelessWidget {
  final DashSection section;
  const _SectionCard({required this.section});
  @override
  Widget build(BuildContext context) {
    final dot = section.dotColor ?? _green;
    return Container(
      decoration: WabotSurface.card(radius: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(section.title, style: const TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(section.count, style: const TextStyle(fontSize: 26, color: _green, fontWeight: FontWeight.w900)),
          ])),
          if (section.actionLabel != null)
            GestureDetector(onTap: section.onAction, child: Container(height: 32, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [_greenDk, _green], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(9),
                boxShadow: [BoxShadow(color: _green.withOpacity(.28), blurRadius: 8, offset: const Offset(0, 3))]),
              child: Text(section.actionLabel!, style: const TextStyle(color: _white, fontSize: 12, fontWeight: FontWeight.w700)))),
        ]),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12), decoration: WabotSurface.inner(radius: 10),
          child: Center(child: Text(section.emptyText, style: const TextStyle(fontSize: 12.5, color: _muted)))),
        const SizedBox(height: 12),
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: dot.withOpacity(.4), blurRadius: 4, offset: const Offset(0, 1))])),
          const SizedBox(width: 6),
          Text(section.footerLabel, style: const TextStyle(fontSize: 11.5, color: _muted, fontWeight: FontWeight.w700, letterSpacing: .5)),
          const Spacer(),
          Text('Voir détails', style: TextStyle(fontSize: 11.5, color: _green.withOpacity(.8), fontWeight: FontWeight.w600)),
          const Icon(Icons.chevron_right_rounded, size: 14, color: _muted),
        ]),
      ]),
    );
  }
}

class _ExploreGrid extends StatelessWidget {
  final List<ExploreCard> cards;
  const _ExploreGrid({required this.cards});
  static const _colors = [_green, _accent, Color(0xFFF59E0B), _greenDk];
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 720 ? 2 : 1;
      return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 90),
        itemCount: cards.length, itemBuilder: (_, i) => _ExploreItem(card: cards[i], color: _colors[i % _colors.length]));
    });
  }
}

class _ExploreItem extends StatelessWidget {
  final ExploreCard card; final Color color;
  const _ExploreItem({required this.card, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    decoration: WabotSurface.card(radius: 14), padding: const EdgeInsets.all(14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(.15), color.withOpacity(.25)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(10)),
        child: Icon(card.icon, size: 18, color: color)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(card.title, style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w700)),
          if (card.suggested) ...[const SizedBox(width: 6), Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(color: _accent.withOpacity(.15), borderRadius: BorderRadius.circular(99)),
            child: const Text('Suggéré', style: TextStyle(fontSize: 9.5, color: _accent, fontWeight: FontWeight.w800)))],
        ]),
        const SizedBox(height: 3),
        Text(card.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: _muted, height: 1.35)),
      ])),
    ]),
  );
}

class DashStat  { final IconData icon; final String label, value; const DashStat({required this.icon, required this.label, required this.value}); }
class DashSection {
  final String title, count, emptyText, footerLabel; final Color? dotColor; final String? actionLabel; final VoidCallback? onAction;
  const DashSection({required this.title, required this.count, required this.emptyText, required this.footerLabel, this.dotColor, this.actionLabel, this.onAction});
}
class ExploreCard { final IconData icon; final String title, description; final bool suggested; const ExploreCard({required this.icon, required this.title, required this.description, this.suggested = false}); }
