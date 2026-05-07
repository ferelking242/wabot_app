import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../services/api_service.dart';
import '../../../shared/models/bot_status.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../theme/app_colors.dart';

final chatsProvider = FutureProvider<List<ChatPreview>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getChats();
  return data.map(ChatPreview.fromJson).toList();
});

final chatSearchProvider = StateProvider<String>((ref) => '');

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsProvider);
    final search = ref.watch(chatSearchProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Chats',
            subtitle: 'All conversations managed by the bot',
            actions: [
              chatsAsync.whenOrNull(
                data: (c) => Text('${c.length} chats', style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
              ) ?? const SizedBox.shrink(),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: () => ref.invalidate(chatsProvider),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => ref.read(chatSearchProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 12),
          Expanded(
            child: chatsAsync.when(
              data: (chats) {
                final filtered = search.isEmpty
                    ? chats
                    : chats.where((c) => c.name.toLowerCase().contains(search.toLowerCase())).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _ChatTile(chat: filtered[i], index: i),
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                itemCount: 10,
                itemBuilder: (_, i) => _ChatTileSkeleton(index: i),
              ),
              error: (_, __) => const Center(child: Text('Could not load chats', style: TextStyle(color: AppColors.textTertiary))),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _ChatTile extends StatefulWidget {
  final ChatPreview chat;
  final int index;

  const _ChatTile({required this.chat, required this.index});

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chat = widget.chat;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: 150.ms,
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceHover : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: _avatarColor(chat.name),
            child: Text(
              chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  chat.name,
                  style: theme.textTheme.titleSmall?.copyWith(color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (chat.isGroup) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${chat.participants}', style: const TextStyle(color: AppColors.info, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          subtitle: Text(
            chat.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeago.format(chat.lastMessageTime, locale: 'en_short'),
                style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
              ),
              if (chat.unreadCount > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                  child: Text('${chat.unreadCount}', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 30 * widget.index))
        .fadeIn(duration: 250.ms)
        .slideX(begin: 0.05, end: 0, duration: 250.ms);
  }

  Color _avatarColor(String name) {
    final colors = [
      AppColors.accent, AppColors.info, AppColors.idle, AppColors.error, const Color(0xFFEB459E),
    ];
    return colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];
  }
}

class _ChatTileSkeleton extends StatelessWidget {
  final int index;
  const _ChatTileSkeleton({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
    ).animate(delay: Duration(milliseconds: 30 * index)).fadeIn(duration: 250.ms)
     .animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: AppColors.surfaceHover);
  }
}
