import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/models.dart';
import '../services/db.dart';
import '../state/viewer.dart';
import '../widgets/common.dart';
import '../widgets/post_card.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  Future<List<Post>>? _future;
  String _key = '';

  @override
  Widget build(BuildContext context) {
    final ids = context.watch<ViewerData>().savedIds;
    final key = (ids.toList()..sort()).join(',');
    if (_future == null || key != _key) {
      _key = key;
      _future = Db.postsByIds(ids);
    }
    return PageScaffold(
      title: 'Saved posts',
      child: FutureBuilder<List<Post>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorNote(friendlyMessageOf(snap.error!));
          if (!snap.hasData) return const Loading();
          final posts = snap.data!;
          if (posts.isEmpty) {
            return const EmptyState(
                title: 'Nothing saved yet.', text: 'Tap the bookmark on a post to keep it here.');
          }
          return ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [for (final p in posts) PostCard(key: ValueKey(p.id), post: p)]);
        },
      ),
    );
  }
}

String friendlyMessageOf(Object e) => friendlyErrorText(e);
