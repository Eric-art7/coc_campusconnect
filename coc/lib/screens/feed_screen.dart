import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/db.dart';
import '../state/settings.dart';
import '../state/tab_nav.dart';
import '../state/viewer.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/post_card.dart';
import 'compose_screen.dart';
import 'events_screen.dart';
import 'settings_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final Stream<List<Post>> _posts = Db.feed();
  late final Stream<List<CampusEvent>> _events = Db.events();
  int _tab = 0;

  List<Post> _order(List<Post> posts, ViewerData v) {
    final list = [...posts];
    if (_tab == 1) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
    double score(Post p) {
      final ageHours = DateTime.now().difference(p.createdAt).inMinutes / 60.0;
      return p.likeCount * 2 + p.commentCount * 3 +
          (v.followingIds.contains(p.authorId) ? 20 : 0) +
          (p.authorId == v.uid ? 5 : 0) -
          ageHours * 0.5;
    }
    list.sort((a, b) => score(b).compareTo(score(a)));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    final s = context.watch<SettingsController>();
    final p = context.pal;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const ScreenTitle('Your campus, closer.', 'Good ideas don\u2019t grow alone.'),
        PCard(
          tinted: true,
          padding: const EdgeInsets.all(18),
          onTap: () => context.read<TabNav>().go(1),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Find your people.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.primary)),
            const SizedBox(height: 4),
            Text('Explore groups and start something good \u2192', style: Txt.caption(context)),
          ]),
        ),
        StreamBuilder<List<CampusEvent>>(
          stream: _events,
          builder: (context, snap) {
            final events = snap.data ?? const <CampusEvent>[];
            if (events.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionHeader('Upcoming events',
                  actionLabel: 'All events \u2192', onAction: () => pushPage(context, const EventsScreen())),
              SizedBox(
                height: 132,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [for (final e in events.take(5)) _EventMini(event: e)],
                ),
              ),
              const SizedBox(height: 14),
            ]);
          },
        ),
        PCard(
          padding: const EdgeInsets.all(12),
          onTap: () => pushPage(context, const ComposeScreen()),
          child: Row(children: [
            Avatar(v.me.initials, radius: 17),
            const SizedBox(width: 12),
            Expanded(child: Text('Share something with your campus\u2026', style: Txt.caption(context).copyWith(fontSize: 13.5))),
            Icon(Icons.edit_outlined, size: 19, color: p.primary),
          ]),
        ),
        PillTabs(labels: const ['For you', 'Latest'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
        if (s.educationOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
            child: Row(children: [
              Icon(Icons.menu_book_outlined, size: 16, color: p.primary),
              const SizedBox(width: 6),
              Text('Education focus is on. ', style: Txt.caption(context)),
              GestureDetector(
                onTap: () => pushPage(context, const SettingsScreen()),
                child: Text('Change settings',
                    style: TextStyle(fontSize: 12, color: p.primary, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        StreamBuilder<List<Post>>(
          stream: _posts,
          builder: (context, snap) {
            if (snap.hasError) return ErrorNote(friendlyMessage(snap.error!));
            if (!snap.hasData) return const Loading();
            var posts = _order(snap.data!, v);
            if (s.educationOnly) posts = posts.where((x) => isEducationTag(x.tag)).toList();
            if (posts.isEmpty) {
              return EmptyState(
                title: 'No campus posts yet.',
                text: 'Posts will appear here when your campus community shares them.',
                action: kDebugMode
                    ? OutlinedButton(
                        onPressed: () async {
                          try {
                            await Db.seedDemo(v.me);
                          } catch (e) {
                            if (context.mounted) toastError(context, e);
                          }
                        },
                        child: const Text('Add demo content (debug only)'),
                      )
                    : null,
              );
            }
            return Column(children: [for (final post in posts) PostCard(key: ValueKey(post.id), post: post)]);
          },
        ),
      ],
    );
  }
}

String friendlyMessage(Object e) => friendlyErrorText(e);

class _EventMini extends StatelessWidget {
  const _EventMini({required this.event});
  final CampusEvent event;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${event.isGovernment ? 'Government' : 'University'} \u00b7 ${event.organization}',
            style: Txt.label(context), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Text(event.title, style: Txt.h2(context), maxLines: 2, overflow: TextOverflow.ellipsis),
        const Spacer(),
        Text(fmtDateTime(event.startsAt), style: Txt.caption(context)),
        Text(event.location, style: Txt.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
