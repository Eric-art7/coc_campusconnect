import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/db.dart';
import '../state/viewer.dart';
import '../screens/post_detail_screen.dart';
import '../screens/profile_screen.dart';
import 'common.dart';
import 'nav.dart';

/// Deletes a post and offers a 10 second Undo, like the web app.
Future<void> deleteWithUndo(BuildContext context, Post post) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Db.deletePost(post.id);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 10),
      content: const Text('Post deleted'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          try {
            await Db.undoDelete(post.id);
          } catch (_) {
            messenger.showSnackBar(const SnackBar(content: Text('The post could not be restored.')));
          }
        },
      ),
    ));
  } catch (e) {
    if (context.mounted) toastError(context, e);
  }
}

Future<void> reportPostDialog(BuildContext context, AppUser me, Post post) async {
  final c = TextEditingController();
  final send = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Report this post'),
      content: TextField(
        controller: c,
        maxLines: 3,
        maxLength: 500,
        decoration: const InputDecoration(hintText: 'What\u2019s wrong with it?'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send report')),
      ],
    ),
  );
  if (send != true) return;
  try {
    await Db.reportPost(me, post.id, c.text);
    if (context.mounted) toast(context, 'Thanks \u2014 an administrator will review it.');
  } catch (e) {
    if (context.mounted) toastError(context, e);
  }
}

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.openDetail = true});
  final Post post;
  final bool openDetail;

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    final p = context.pal;
    final liked = v.likedIds.contains(post.id);
    final saved = v.savedIds.contains(post.id);
    final mine = post.authorId == v.uid;

    Future<void> toggleLike() async {
      try {
        await Db.setLike(v.me, post, !liked);
      } catch (e) {
        if (context.mounted) toastError(context, e);
      }
    }

    Future<void> toggleSave() async {
      try {
        await Db.setSaved(v.uid, post.id, !saved);
        if (context.mounted) toast(context, saved ? 'Removed from saved posts' : 'Saved');
      } catch (e) {
        if (context.mounted) toastError(context, e);
      }
    }

    return PCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => pushPage(context, mine ? const ProfileScreen() : PersonProfileScreen(userId: post.authorId)),
            child: Avatar(post.initials, radius: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.author, style: Txt.h2(context)),
              Text('${post.course} \u00b7 ${timeAgo(post.createdAt)}', style: Txt.caption(context)),
            ]),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(Icons.more_horiz, color: p.muted),
            onSelected: (s) {
              if (s == 'delete') deleteWithUndo(context, post);
              if (s == 'report') reportPostDialog(context, v.me, post);
            },
            itemBuilder: (_) => [
              if (mine) const PopupMenuItem(value: 'delete', child: Text('Delete post')),
              if (!mine) const PopupMenuItem(value: 'report', child: Text('Report post')),
            ],
          ),
        ]),
        if (post.tag != null && post.tag!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: TagChip(post.tag!)),
        ],
        const SizedBox(height: 10),
        Text(post.body, style: Txt.body(context)),
        if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
          const SizedBox(height: 12),
          PostImage(post.imageUrl!),
        ],
        const SizedBox(height: 8),
        Row(children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: toggleLike,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(children: [
                Icon(liked ? Icons.favorite : Icons.favorite_border,
                    size: 19, color: liked ? p.danger : p.muted),
                const SizedBox(width: 5),
                Text('${post.likeCount}', style: Txt.caption(context)),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: openDetail ? () => pushPage(context, PostDetailScreen(postId: post.id)) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(children: [
                Icon(Icons.chat_bubble_outline, size: 18, color: p.muted),
                const SizedBox(width: 5),
                Text('${post.commentCount} comments', style: Txt.caption(context)),
              ]),
            ),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: saved ? 'Remove saved post' : 'Save post',
            onPressed: toggleSave,
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border,
                size: 21, color: saved ? p.primary : p.muted),
          ),
        ]),
      ]),
    );
  }
}
