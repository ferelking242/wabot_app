import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../theme/app_colors.dart';

class AutomationScreen extends StatelessWidget {
  const AutomationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          PageHeader(
            title: 'Automation',
            subtitle: 'Create automated workflows for your bot',
            actions: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Flow'),
                onPressed: () => _showNewFlowDialog(context),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Flows', style: theme.textTheme.titleMedium).animate().fadeIn(),
                  const SizedBox(height: 12),
                  ..._sampleFlows.asMap().entries.map((e) => _FlowCard(flow: e.value, index: e.key)),
                  const SizedBox(height: 24),
                  Text('Templates', style: theme.textTheme.titleMedium).animate(delay: 200.ms).fadeIn(),
                  const SizedBox(height: 12),
                  ..._templates.asMap().entries.map((e) => _TemplateCard(template: e.value, index: e.key)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewFlowDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create New Flow'),
        content: const Text('Visual flow editor coming soon. Configure triggers, conditions, and actions to automate your bot.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Create')),
        ],
      ),
    );
  }

  static final _sampleFlows = [
    _Flow('Welcome New Members', 'Trigger: Join Group → Send welcome message', true, Icons.waving_hand_outlined),
    _Flow('Auto Reply Keywords', 'Trigger: Message contains keyword → Reply with custom text', true, Icons.reply_outlined),
    _Flow('Spam Filter', 'Trigger: Link detected → Warn and kick if admin', false, Icons.shield_outlined),
  ];

  static final _templates = [
    _Template('Scheduled Broadcast', 'Send scheduled messages to groups', Icons.schedule_outlined),
    _Template('Anti-Profanity', 'Automatically delete messages with bad words', Icons.block_outlined),
    _Template('Poll Creator', 'Create polls based on command trigger', Icons.poll_outlined),
    _Template('Birthday Wisher', 'Send birthday messages to members', Icons.cake_outlined),
  ];
}

class _Flow {
  final String name, description;
  final bool active;
  final IconData icon;
  const _Flow(this.name, this.description, this.active, this.icon);
}

class _Template {
  final String name, description;
  final IconData icon;
  const _Template(this.name, this.description, this.icon);
}

class _FlowCard extends StatefulWidget {
  final _Flow flow;
  final int index;
  const _FlowCard({required this.flow, required this.index});

  @override
  State<_FlowCard> createState() => _FlowCardState();
}

class _FlowCardState extends State<_FlowCard> {
  late bool _active;

  @override
  void initState() {
    super.initState();
    _active = widget.flow.active;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _active ? AppColors.accentBorder : AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _active ? AppColors.accentSurface : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.flow.icon, size: 18, color: _active ? AppColors.accent : AppColors.textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.flow.name, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(widget.flow.description, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 18),
            color: AppColors.textSecondary,
            onPressed: () {},
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: 60 * widget.index))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.03, end: 0, duration: 300.ms);
  }
}

class _TemplateCard extends StatefulWidget {
  final _Template template;
  final int index;
  const _TemplateCard({required this.template, required this.index});

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: 150.ms,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceHover : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            Icon(widget.template.icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.template.name, style: theme.textTheme.titleSmall),
                  Text(widget.template.description, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            TextButton(onPressed: () {}, child: const Text('Use Template')),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 60 * widget.index + 200))
        .fadeIn(duration: 300.ms);
  }
}
