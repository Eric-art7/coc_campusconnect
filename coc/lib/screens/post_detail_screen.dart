import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/db.dart';
import '../state/viewer.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/post_card.dart';
import 'profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final Stream<Post?> _post = Db.postStream(widget.postId);
  late final Stream<List<Comment>> _comments = Db.comments(widget.postId);
  final _input = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(Post post) async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await Db.addComment(context.read<ViewerData>().me, post, text);
      _input.clear();
    } catch (e) {
      if (mounted) toastError(context, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    return PageScaffold(
      title: 'Discussion',
      child: StreamBuilder<Post?>(
        stream: _post,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Loading();
          final post = snap.data;
          if (post == null) {
            return const EmptyState(title: 'This post is no longer available.', text: 'It may have been deleted.');
          }
          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.only(top: 4, bottom: 12), children: [
                PostCard(post: post, openDetail: false),
                const SectionHeader('Comments'),
                StreamBuilder<List<Comment>>(
                  stream: _comments,
                  builder: (context, cs) {
                    if (!cs.hasData) return const Loading();
                    final list = cs.data!;
                    if (list.isEmpty) {
                      return const EmptyState(title: 'No comments yet.', text: 'Be the first to join the conversation.');
                    }
                    return Column(children: [
                      for (final c in list)
                        PCard(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            GestureDetector(
                              onTap: () => pushPage(context,
                                  c.authorId == v.uid ? const ProfileScreen() : PersonProfileScreen(userId: c.authorId)),
                              child: Avatar(initialsOf(c.author), radius: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${c.author} \u00b7 ${timeAgo(c.createdAt)}', style: Txt.caption(context)),
                                const SizedBox(height: 3),
                                Text(c.body, style: Txt.body(context)),
                              ]),
                            ),
                          ]),
                        ),
                    ]);
                  },
                ),
              ]),
            ),
            InputBar(controller: _input, hint: 'Add a comment\u2026', busy: _busy, sendLabel: 'Post', onSend: () => _send(post)),
          ]);
        },
      ),
    );
  }
}
