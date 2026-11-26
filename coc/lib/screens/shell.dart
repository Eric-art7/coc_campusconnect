import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../state/tab_nav.dart';
import '../state/viewer.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import 'admin/admin_screens.dart';
import 'assistant_screen.dart';
import 'events_screen.dart';
import 'explore_screen.dart';
import 'feed_screen.dart';
import 'groups_screen.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'saved_screen.dart';
import 'settings_screen.dart';
import 'study_screen.dart';

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    if (v.profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const _ShellBody();
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon, activeIcon;
}

const _tabs = [
  _Tab('Feed', Icons.home_outlined, Icons.home_rounded),
  _Tab('Groups', Icons.groups_outlined, Icons.groups_rounded),
  _Tab('Chat', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
  _Tab('Study', Icons.menu_book_outlined, Icons.menu_book_rounded),
  _Tab('AI', Icons.auto_awesome_outlined, Icons.auto_awesome_rounded),
];

class _ShellBody extends StatelessWidget {
  const _ShellBody();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<TabNav>();
    final v = context.watch<ViewerData>();
    final p = context.pal;

    return Scaffold(
      drawer: const _AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 6),
            child: Row(children: [
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              Text('campusconnect', style: Txt.brandLarge(context)),
              const Spacer(),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => pushPage(context, const NotificationsScreen()),
                icon: Badge(
                  isLabelVisible: v.unreadCount > 0,
                  label: Text('${v.unreadCount}'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
              const SizedBox(width: 2),
              GestureDetector(
                onTap: () => pushPage(context, const ProfileScreen()),
                child: Avatar(v.me.initials, radius: 16),
              ),
            ]),
          ),
          if (!v.emailVerified)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(
                    child: Text('Verify your email to keep your account secure.',
                        style: TextStyle(fontSize: 12, color: p.ink))),
                TextButton(
                  onPressed: () async {
                    try {
                      await AuthService.resendVerification();
                      if (context.mounted) toast(context, 'Verification email sent.');
                    } catch (e) {
                      if (context.mounted) toastError(context, e);
                    }
                  },
                  child: const Text('Resend', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => v.reloadUser(),
                  child: const Text('I\u2019ve verified', style: TextStyle(fontSize: 12)),
                ),
              ]),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: IndexedStack(
                  index: nav.index,
                  children: const [
                    FeedScreen(),
                    GroupsScreen(),
                    MessagesScreen(),
                    StudyScreen(),
                    AssistantScreen(),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: _BottomNav(index: nav.index, onTap: nav.go),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.line))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    height: 2.5,
                    width: 24,
                    decoration: BoxDecoration(
                      color: i == index ? p.primary : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(i == index ? _tabs[i].activeIcon : _tabs[i].icon,
                      size: 22, color: i == index ? p.primary : p.muted),
                  const SizedBox(height: 2),
                  Text(_tabs[i].label,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: i == index ? p.primary : p.muted)),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    final me = v.me;

    Widget item(IconData icon, String label, Widget page, {int badge = 0}) => ListTile(
          leading: Badge(isLabelVisible: badge > 0, label: Text('$badge'), child: Icon(icon)),
          title: Text(label),
          onTap: () {
            Navigator.pop(context);
            pushPage(context, page);
          },
        );

    return Drawer(
      child: SafeArea(
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(children: [
              Avatar(me.initials, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(me.fullName, style: Txt.h2(context), overflow: TextOverflow.ellipsis),
                  Text(v.email, style: Txt.caption(context), overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
          ),
          const Divider(height: 1),
          item(Icons.person_outline_rounded, 'Profile', const ProfileScreen()),
          item(Icons.search_rounded, 'Explore people', const ExploreScreen()),
          item(Icons.event_outlined, 'Events', const EventsScreen()),
          item(Icons.bookmark_border_rounded, 'Saved posts', const SavedScreen()),
          item(Icons.notifications_none_rounded, 'Notifications', const NotificationsScreen(),
              badge: v.unreadCount),
          item(Icons.settings_outlined, 'Settings', const SettingsScreen()),
          if (me.isAdmin) item(Icons.shield_outlined, 'Administration', const AdminScreen()),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            onTap: () async {
              Navigator.pop(context);
              await AuthService.signOut();
            },
          ),
        ]),
      ),
    );
  }
}
