import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/db.dart';
import '../state/viewer.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/post_card.dart';
import 'explore_screen.dart';
import 'messages_screen.dart';
import 'saved_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    final me = v.me;
    final p = context.pal;

    return PageScaffold(
      title: 'Profile',
      child: StreamBuilder<List<Post>>(
        stream: Db.userPosts(v.uid),
        builder: (context, snap) {
          final posts = snap.data ?? const <Post>[];
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            const ScreenTitle('Your campus story.', 'A little about the person behind the posts.'),
            PCard(
              tinted: true,
              padding: const EdgeInsets.all(18),
              child: Text('Curiosity connects us.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.primary)),
            ),
            PCard(
              child: Column(children: [
                Avatar(me.initials, radius: 36),
                const SizedBox(height: 12),
                Text(me.fullName, style: Txt.h1(context).copyWith(fontSize: 20)),
                const SizedBox(height: 2),
                Text(me.detail, style: Txt.caption(context)),
                const SizedBox(height: 4),
                Text(v.emailVerified ? v.email : '${v.email} \u00b7 not verified', style: Txt.caption(context)),
                if (me.bio != null) ...[
                  const SizedBox(height: 10),
                  Text(me.bio!, textAlign: TextAlign.center, style: Txt.body(context)),
                ],
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _Stat('${v.followerIds.length}', 'followers',
                      () => pushPage(context, const ConnectionsScreen(initialTab: 1))),
                  _Stat('${v.followingIds.length}', 'following',
                      () => pushPage(context, const ConnectionsScreen(initialTab: 0))),
                  _Stat('${posts.length}', 'posts', null),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                      onPressed: () => pushPage(context, const EditProfileScreen()), child: const Text('Edit profile')),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => pushPage(context, const SavedScreen()), child: const Text('Saved posts')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => pushPage(context, const ExploreScreen()), child: const Text('Find people')),
                  ),
                ]),
              ]),
            ),
            if (me.interests.isNotEmpty)
              PCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('A few things I\u2019m into', style: Txt.h2(context)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [for (final i in me.interests) TagChip(i)]),
                ]),
              ),
            const SectionHeader('Your posts'),
            if (posts.isEmpty)
              const EmptyState(title: 'No posts yet.', text: 'Share something from the feed to see it here.')
            else
              for (final post in posts) PostCard(key: ValueKey(post.id), post: post),
          ]);
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.onTap);
  final String value, label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.pal.primary)),
            Text(label, style: Txt.caption(context)),
          ]),
        ),
      );
}

class PersonProfileScreen extends StatelessWidget {
  const PersonProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    return PageScaffold(
      title: 'Profile',
      child: StreamBuilder<AppUser?>(
        stream: Db.userStream(userId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Loading();
          final u = snap.data;
          if (u == null) return const EmptyState(title: 'Profile not found.', text: 'This member may have left campus.');
          final hidden = u.profileVisibility == 'PRIVATE' ||
              (u.profileVisibility == 'CONNECTIONS' && !v.isConnection(u.id));
          if (hidden) {
            return EmptyState(
              title: u.fullName,
              text: u.profileVisibility == 'PRIVATE'
                  ? 'This profile is private.'
                  : 'Only connections can see this profile. Follow each other to connect.',
              action: FollowButton(person: u.toPerson()),
            );
          }
          return StreamBuilder<List<Post>>(
            stream: Db.userPosts(u.id),
            builder: (context, ps) {
              final posts = ps.data ?? const <Post>[];
              return ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
                PCard(
                  child: Column(children: [
                    Avatar(u.initials, radius: 36),
                    const SizedBox(height: 12),
                    Text(u.fullName, style: Txt.h1(context).copyWith(fontSize: 20)),
                    const SizedBox(height: 2),
                    Text(u.detail, style: Txt.caption(context)),
                    if (u.bio != null) ...[
                      const SizedBox(height: 10),
                      Text(u.bio!, textAlign: TextAlign.center, style: Txt.body(context)),
                    ],
                    if (u.interests.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                        for (final i in u.interests) TagChip(i),
                      ]),
                    ],
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: FollowButton(person: u.toPerson())),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => openChatWith(context, u.id),
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Message'),
                        ),
                      ),
                    ]),
                  ]),
                ),
                SectionHeader('Posts (${posts.length})'),
                if (posts.isEmpty)
                  const EmptyState(title: 'No posts yet.', text: 'Nothing shared yet.')
                else
                  for (final post in posts) PostCard(key: ValueKey(post.id), post: post),
              ]);
            },
          );
        },
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final AppUser _me = context.read<ViewerData>().me;
  late final _name = TextEditingController(text: _me.fullName);
  late final _field = TextEditingController(text: _me.fieldOfStudy ?? '');
  late final _bio = TextEditingController(text: _me.bio ?? '');
  late final _interests = TextEditingController(text: _me.interests.join(', '));
  late int? _year = _me.yearOfStudy;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _field.dispose();
    _bio.dispose();
    _interests.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Your name can\u2019t be empty.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final interests = _interests.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .take(8)
          .toList();
      await Db.updateProfile(_me.id,
          fullName: _name.text, fieldOfStudy: _field.text, yearOfStudy: _year, bio: _bio.text, interests: interests);
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, 'Profile saved.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Edit profile',
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _name, maxLength: 120, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 8),
          TextField(controller: _field, maxLength: 120, decoration: const InputDecoration(labelText: 'Field of study')),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: _year,
            decoration: const InputDecoration(labelText: 'Year of study'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Not specified')),
              for (var y = 1; y <= 12; y++) DropdownMenuItem<int?>(value: y, child: Text('Year $y')),
            ],
            onChanged: (v) => setState(() => _year = v),
          ),
          const SizedBox(height: 16),
          TextField(controller: _bio, maxLength: 160, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio', hintText: 'Building things, sharing ideas, finding my people.')),
          const SizedBox(height: 8),
          TextField(controller: _interests, decoration: const InputDecoration(labelText: 'Interests', hintText: 'Technology, Design, Music')),
          if (_error != null) ErrorNote(_error!),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving\u2026' : 'Save profile')),
        ]),
      );
}

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  late final String _uid = context.read<ViewerData>().uid;
  late final Stream<List<Person>> _following = Db.people(_uid, 'following');
  late final Stream<List<Person>> _followers = Db.people(_uid, 'followers');

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Connections'),
          actions: [
            TextButton(onPressed: () => pushPage(context, const ExploreScreen()), child: const Text('Find people')),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Following'), Tab(text: 'Followers')]),
        ),
        body: SafeArea(
          child: TabBarView(children: [
            _PeopleList(stream: _following, empty: 'You aren\u2019t following anyone yet.'),
            _PeopleList(stream: _followers, empty: 'No followers yet.'),
          ]),
        ),
      ),
    );
  }
}

class _PeopleList extends StatelessWidget {
  const _PeopleList({required this.stream, required this.empty});
  final Stream<List<Person>> stream;
  final String empty;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Person>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Loading();
          final list = snap.data!;
          if (list.isEmpty) return EmptyState(title: empty, text: 'Find campus members in Explore.');
          return ListView(padding: const EdgeInsets.only(top: 12), children: [
            for (final person in list)
              PersonRow(
                initials: person.initials,
                name: person.fullName,
                detail: person.detail,
                onTap: () => pushPage(context, PersonProfileScreen(userId: person.id)),
                trailing: FollowButton(person: person),
              ),
          ]);
        },
      );
}
