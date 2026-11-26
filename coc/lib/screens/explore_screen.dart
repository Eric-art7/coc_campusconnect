import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/models.dart';
import '../services/db.dart';
import '../state/viewer.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

Future<void> toggleFollow(BuildContext context, ViewerData v, Person person) async {
  try {
    if (v.followingIds.contains(person.id)) {
      await Db.unfollow(v.uid, person.id);
    } else {
      await Db.follow(v.me, person);
    }
  } catch (e) {
    if (context.mounted) toastError(context, e);
  }
}

class FollowButton extends StatelessWidget {
  const FollowButton({super.key, required this.person});
  final Person person;

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    final following = v.followingIds.contains(person.id);
    return following
        ? OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
            onPressed: () => toggleFollow(context, v, person),
            child: const Text('Following'))
        : FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
            onPressed: () => toggleFollow(context, v, person),
            child: const Text('Follow'));
  }
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _q = TextEditingController();
  List<AppUser> _people = [];
  bool _loading = true;
  String? _error;
  String _searched = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final v = context.read<ViewerData>();
    final text = _q.text.trim();
    setState(() {
      _loading = true;
      _error = null;
      _searched = text;
    });
    try {
      final res = text.isEmpty
          ? await Db.recentPeople(v.uid, v.isConnection)
          : await Db.searchPeople(text, v.uid, v.isConnection);
      if (mounted) setState(() => _people = res);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Explore campus',
      child: ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
        SearchField(controller: _q, hint: 'Search students by name', onSubmitted: (_) => _run()),
        SectionHeader(_searched.isEmpty ? 'People on campus' : 'People matching \u201c$_searched\u201d'),
        if (_error != null) ErrorNote(_error!),
        if (_loading)
          const Loading()
        else if (_people.isEmpty && _error == null)
          const EmptyState(title: 'No people found.', text: 'Try another name.')
        else
          for (final u in _people)
            PersonRow(
              initials: u.initials,
              name: u.fullName,
              detail: u.detail,
              onTap: () => pushPage(context, PersonProfileScreen(userId: u.id)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Message',
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  onPressed: () => openChatWith(context, u.id),
                ),
                FollowButton(person: u.toPerson()),
              ]),
            ),
      ]),
    );
  }
}
