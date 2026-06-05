import 'package:flutter/material.dart';
import '../../../shared/widgets/dashboard_scaffold.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => const DashboardScaffold(
    stats: [
      DashStat(icon: Icons.phone_android_outlined, label: 'Sessions actives', value: '3'),
      DashStat(icon: Icons.chat_outlined,           label: 'Messages (24h)',   value: '1 247'),
      DashStat(icon: Icons.check_circle_outline,   label: 'Taux de succès',   value: '98.4%'),
      DashStat(icon: Icons.bolt_outlined,          label: 'Webhooks actifs',  value: '12'),
    ],
    sections: [
      DashSection(title: 'Sessions WhatsApp', count: '3 / 5', emptyText: 'Aucune session inactive',
        footerLabel: '3 CONNECTÉES · 2 DISPONIBLES', dotColor: Color(0xFF25D366), actionLabel: 'Ajouter'),
      DashSection(title: 'Webhooks', count: '12', emptyText: 'Tous les webhooks répondent',
        footerLabel: '12 ACTIFS · 0 EN ERREUR', dotColor: Color(0xFF34E07E), actionLabel: 'Gérer'),
    ],
    explore: [
      ExploreCard(icon: Icons.qr_code_rounded,        title: 'Scanner un QR',         description: 'Connectez un nouveau numéro WhatsApp en quelques secondes.', suggested: true),
      ExploreCard(icon: Icons.auto_fix_high_outlined, title: 'Créer une automation',  description: 'Répondez automatiquement aux messages avec des règles personnalisées.'),
      ExploreCard(icon: Icons.receipt_long_outlined,  title: 'Consulter les logs',    description: 'Historique complet des messages envoyés et reçus.'),
      ExploreCard(icon: Icons.key_outlined,           title: 'Gérer les clés API',    description: 'Créez et révoquez des clés pour vos intégrations.'),
    ],
  );
}
