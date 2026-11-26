import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/db.dart';
import '../state/viewer.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import 'messages_screen.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _tab = 0;

  IconData _icon(String kind) => switch (kind) {
        'MESSAGE' => Icons.chat_bubble_outline,
        'CALL' => Icons.call_outlined,
        'LIKE' => Icons.favorite_border,
        'COMMENT' => Icons.mode_comment_outlined,
        'FOLLOW' => Icons.person_add_alt_outlined,
        _ => Icons.notifications_none,
      };

  Future<void> _open(AppNotification n, ViewerData v) async {
    if (n.unread) {
      try {
        await Db.markNotificationRead(v.uid, n.id);
      } catch (e) {
        if (mounted) toastError(context, e);
      }
    }
    if (!mounted || n.targetId == null) return;
    switch (n.kind) {
      case 'MESSAGE':
      case 'CALL':
        pushPage(context, ChatScreen(conversationId: n.targetId!));
      case 'LIKE':
      case 'COMMENT':
        pushPage(context, PostDetailScreen(postId: n.targetId!));
      case 'FOLLOW':
        pushPage(context, PersonProfileScreen(userId: n.targetId!));
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    final p = context.pal;
    final unread = v.unreadCount;
    final list = _tab == 1 ? v.notifications.where((n) => n.unread).toList() : v.notifications;

    return PageScaffold(
      title: 'Notifications',
      actions: [
        if (unread > 0)
          TextButton(
            onPressed: () async {
              try {
                await Db.markAllNotificationsRead(v.uid, v.notifications);
              } catch (e) {
                if (context.mounted) toastError(context, e);
              }
            },
            child: const Text('Mark all read'),
          ),
      ],
      child: ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
        const ScreenTitle('You\u2019re in the loop.', 'Little updates. Meaningful connections.'),
        PillTabs(labels: ['All updates', 'Unread $unread'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
        if (list.isEmpty)
          const EmptyState(title: 'You\u2019re all caught up.', text: 'New activity will appear here.')
        else
          for (final n in list)
            PCard(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              onTap: () => _open(n, v),
              child: Row(children: [
                CircleAvatar(radius: 18, backgroundColor: p.tint, child: Icon(_icon(n.kind), size: 18, color: p.primary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.body,
                        style: TextStyle(fontSize: 13.5, fontWeight: n.unread ? FontWeight.w700 : FontWeight.w500, color: p.ink)),
                    const SizedBox(height: 2),
                    Text(timeAgo(n.createdAt), style: Txt.caption(context)),
                  ]),
                ),
                if (n.unread) Icon(Icons.circle, size: 9, color: p.primary),
              ]),
            ),
      ]),
    );
  }
}
