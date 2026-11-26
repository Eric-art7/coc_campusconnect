import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../state/viewer.dart';
import '../../widgets/common.dart';
import '../../widgets/nav.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    if (!v.me.isAdmin) {
      return const PageScaffold(
          title: 'Administration',
          child: EmptyState(title: 'Administrators only.', text: 'You don\u2019t have access to this area.'));
    }
    return PageScaffold(
      title: 'Campus administration',
      child: ListView(padding: const EdgeInsets.only(top: 8), children: [
        StreamBuilder<List<AppUser>>(
          stream: Db.adminUsers(),
          builder: (context, us) => PCard(
            onTap: () => pushPage(context, const AdminUsersScreen()),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('User management', style: Txt.h2(context)),
                  Text('${us.data?.length ?? 0} accounts', style: Txt.caption(context)),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
        StreamBuilder<List<Report>>(
          stream: Db.reports(),
          builder: (context, rs) => PCard(
            onTap: () => pushPage(context, const AdminReportsScreen()),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Report review', style: Txt.h2(context)),
                  Text('${(rs.data ?? const <Report>[]).where((r) => r.isOpen).length} open reports',
                      style: Txt.caption(context)),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      ]),
    );
  }
}

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  Future<void> _verify(BuildContext context, AppUser u) async {
    final name = TextEditingController(text: u.organizationName ?? '');
    String type = u.organizationType ?? 'UNIVERSITY';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Verify ${u.fullName}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Organization type'),
              items: const [
                DropdownMenuItem(value: 'UNIVERSITY', child: Text('University')),
                DropdownMenuItem(value: 'GOVERNMENT', child: Text('Government entity')),
              ],
              onChanged: (x) => setS(() => type = x ?? type),
            ),
            const SizedBox(height: 12),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Organization name')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Verify')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await Db.verifyOrganization(u.id, type: type, name: name.text);
      if (context.mounted) toast(context, '${u.fullName} can now publish events.');
    } catch (e) {
      if (context.mounted) toastError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<ViewerData>().me;
    if (!me.isAdmin) {
      return const PageScaffold(title: 'Users', child: EmptyState(title: 'Administrators only.', text: ''));
    }
    return PageScaffold(
      title: 'User management',
      child: StreamBuilder<List<AppUser>>(
        stream: Db.adminUsers(),
        builder: (context, snap) {
          if (snap.hasError) return ErrorNote(friendlyError(snap.error!));
          if (!snap.hasData) return const Loading();
          return ListView(padding: const EdgeInsets.only(top: 12, bottom: 24), children: [
            for (final u in snap.data!)
              PersonRow(
                initials: u.initials,
                name: '${u.fullName}${u.isAdmin ? ' \u00b7 Admin' : ''}',
                detail: u.organizationVerified
                    ? 'Verified ${u.organizationType == 'GOVERNMENT' ? 'government' : 'university'}: ${u.organizationName}'
                    : u.detail,
                trailing: u.organizationVerified
                    ? TextButton(
                        onPressed: () async {
                          try {
                            await Db.revokeOrganization(u.id);
                          } catch (e) {
                            if (context.mounted) toastError(context, e);
                          }
                        },
                        child: const Text('Revoke'))
                    : TextButton(onPressed: () => _verify(context, u), child: const Text('Verify org')),
              ),
          ]);
        },
      ),
    );
  }
}

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  Future<void> _decide(BuildContext context, Report r, bool remove) async {
    try {
      await Db.reviewReport(r, remove: remove);
      if (context.mounted) toast(context, remove ? 'Post removed.' : 'Report dismissed.');
    } catch (e) {
      if (context.mounted) toastError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<ViewerData>().me;
    if (!me.isAdmin) {
      return const PageScaffold(title: 'Reports', child: EmptyState(title: 'Administrators only.', text: ''));
    }
    return PageScaffold(
      title: 'Report review',
      child: StreamBuilder<List<Report>>(
        stream: Db.reports(),
        builder: (context, snap) {
          if (snap.hasError) return ErrorNote(friendlyError(snap.error!));
          if (!snap.hasData) return const Loading();
          final reports = snap.data!;
          if (reports.isEmpty) return const EmptyState(title: 'No reports.', text: 'Nothing to review right now.');
          return ListView(padding: const EdgeInsets.only(top: 12, bottom: 24), children: [
            for (final r in reports)
              PCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    TagChip(r.status, green: r.status == 'APPROVED'),
                    const Spacer(),
                    Text(timeAgo(r.createdAt), style: Txt.caption(context)),
                  ]),
                  const SizedBox(height: 8),
                  Text(r.message, style: Txt.body(context)),
                  if (r.postId != null)
                    FutureBuilder<List<Post>>(
                      future: Db.postsByIds([r.postId!]),
                      builder: (context, ps) {
                        final post = (ps.data != null && ps.data!.isNotEmpty) ? ps.data!.first : null;
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: context.pal.tint, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                              post == null ? 'Post is no longer visible.' : '${post.author}: ${post.body}',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: Txt.caption(context)),
                        );
                      },
                    ),
                  if (r.isOpen) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () => _decide(context, r, false), child: const Text('Keep post'))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: context.pal.danger),
                          onPressed: () => _decide(context, r, true),
                          child: const Text('Remove post'),
                        ),
                      ),
                    ]),
                  ],
                ]),
              ),
          ]);
        },
      ),
    );
  }
}
