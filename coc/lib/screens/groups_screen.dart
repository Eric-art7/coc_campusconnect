import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/db.dart';
import '../state/viewer.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';

const groupCategories = ['Academic', 'Community', 'Career', 'Technology', 'Arts', 'Sports', 'Wellbeing'];

Future<void> toggleMembership(BuildContext context, Group g, ViewerData v) async {
  final joined = g.hasMember(v.uid);
  try {
    await Db.setGroupMember(g.id, v.uid, !joined);
    if (context.mounted) toast(context, joined ? 'You left ${g.name}.' : 'Welcome to ${g.name}!');
  } catch (e) {
    if (context.mounted) toastError(context, e);
  }
}

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final Stream<List<Group>> _groups = Db.groups();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      const ScreenTitle('Find your circle.', 'There\u2019s a community for your kind of curious.'),
      PillTabs(
        labels: const ['Discover', 'My groups', '+ Create'],
        index: _tab,
        onChanged: (i) {
          if (i == 2) {
            pushPage(context, const CreateGroupScreen());
          } else {
            setState(() => _tab = i);
          }
        },
      ),
      StreamBuilder<List<Group>>(
        stream: _groups,
        builder: (context, snap) {
          if (snap.hasError) return ErrorNote(friendlyError(snap.error!));
          if (!snap.hasData) return const Loading();
          final all = snap.data!;
          final list = _tab == 1 ? all.where((g) => g.hasMember(v.uid)).toList() : all;
          if (list.isEmpty) {
            return EmptyState(
              title: _tab == 1 ? 'You haven\u2019t joined a group yet.' : 'No campus groups yet.',
              text: 'Create a group to bring people together.',
              action: FilledButton(
                  onPressed: () => pushPage(context, const CreateGroupScreen()), child: const Text('Create group')),
            );
          }
          return Column(children: [
            for (final g in list)
              PCard(
                onTap: () => pushPage(context, GroupDetailScreen(groupId: g.id)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TagChip(g.category, green: g.category == 'Community'),
                  const SizedBox(height: 10),
                  Text(g.name, style: Txt.h2(context)),
                  const SizedBox(height: 2),
                  Text('${g.members} members \u00b7 Public', style: Txt.caption(context)),
                  if (g.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(g.description, style: Txt.caption(context), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: g.hasMember(v.uid)
                        ? TextButton(
                            onPressed: () => pushPage(context, GroupDetailScreen(groupId: g.id)),
                            child: const Text('Open \u2192'))
                        : TextButton(
                            onPressed: () => toggleMembership(context, g, v), child: const Text('Join \u2192')),
                  ),
                ]),
              ),
          ]);
        },
      ),
    ]);
  }
}

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    return PageScaffold(
      title: 'Group',
      child: StreamBuilder<Group?>(
        stream: Db.groupStream(groupId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Loading();
          final g = snap.data;
          if (g == null) {
            return const EmptyState(title: 'This group no longer exists.', text: 'It may have been deleted by its owner.');
          }
          final joined = g.hasMember(v.uid);
          final canManage = g.ownerId == v.uid || v.me.isAdmin;
          return ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
            PCard(
              tinted: true,
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TagChip(g.category, green: g.category == 'Community'),
                const SizedBox(height: 12),
                Text(g.name, style: Txt.h1(context)),
                const SizedBox(height: 6),
                Text('${g.members} members \u00b7 Public', style: Txt.caption(context)),
              ]),
            ),
            PCard(child: Text(g.description.isEmpty ? 'No description yet.' : g.description, style: Txt.body(context))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                if (g.ownerId != v.uid)
                  Expanded(
                    child: joined
                        ? OutlinedButton(onPressed: () => toggleMembership(context, g, v), child: const Text('Leave group'))
                        : FilledButton(onPressed: () => toggleMembership(context, g, v), child: const Text('Join group')),
                  )
                else
                  Expanded(child: Text('You created this group.', style: Txt.caption(context))),
                if (canManage) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                      onPressed: () => pushPage(context, ManageGroupScreen(group: g)), child: const Text('Manage')),
                ],
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String _category = groupCategories.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await Db.createGroup(context.read<ViewerData>().me,
          name: _name.text, category: _category, description: _desc.text);
      if (!mounted) return;
      Navigator.pop(context);
      pushPage(context, GroupDetailScreen(groupId: id));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Create group',
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              controller: _name,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Group name'),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Use at least 3 characters.' : null,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in groupCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _desc,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'What is this group about?'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a short description.' : null,
            ),
            if (_error != null) ErrorNote(_error!),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Creating\u2026' : 'Create group')),
          ]),
        ),
      );
}

class ManageGroupScreen extends StatefulWidget {
  const ManageGroupScreen({super.key, required this.group});
  final Group group;
  @override
  State<ManageGroupScreen> createState() => _ManageGroupScreenState();
}

class _ManageGroupScreenState extends State<ManageGroupScreen> {
  late final _name = TextEditingController(text: widget.group.name);
  late final _desc = TextEditingController(text: widget.group.description);
  late String _category = groupCategories.contains(widget.group.category) ? widget.group.category : groupCategories.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 3) {
      setState(() => _error = 'Use at least 3 characters for the name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Db.updateGroup(widget.group.id, name: _name.text, category: _category, description: _desc.text);
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, 'Group updated.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    final ok = await confirm(context,
        title: 'Delete group?',
        message: 'Delete \u201c${widget.group.name}\u201d? This cannot be undone.',
        action: 'Delete',
        danger: true);
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Db.deleteGroup(widget.group.id);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      toast(context, 'Group deleted.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Manage group',
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _name, maxLength: 120, decoration: const InputDecoration(labelText: 'Group name')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [for (final c in groupCategories) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 16),
          TextField(
              controller: _desc, maxLines: 5, maxLength: 2000, decoration: const InputDecoration(labelText: 'Description')),
          if (_error != null) ErrorNote(_error!),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Save changes')),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _delete,
            style: OutlinedButton.styleFrom(foregroundColor: context.pal.danger),
            child: const Text('Delete group'),
          ),
        ]),
      );
}
