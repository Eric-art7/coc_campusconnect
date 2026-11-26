import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/db.dart';
import '../state/viewer.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';

/// Joins the session (if needed) and opens the Jitsi video room.
Future<void> joinMeeting(BuildContext context, StudyRoom room, ViewerData v) async {
  try {
    if (!room.hasMember(v.uid)) await Db.setRoomMember(room.id, v.uid, true);
  } catch (_) {
    // Joining the meeting should still work even if membership could not be saved.
  }
  if (context.mounted) await openUrl(context, room.meetingUrl);
}

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});
  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late final Stream<List<StudyRoom>> _rooms = Db.studyRooms();

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    return StreamBuilder<List<StudyRoom>>(
      stream: _rooms,
      builder: (context, snap) {
        if (snap.hasError) return ListView(children: [ErrorNote(friendlyError(snap.error!))]);
        if (!snap.hasData) return const Loading();
        final upcoming = snap.data!.where((r) => !r.isPast).toList();
        final past = snap.data!.where((r) => r.isPast).toList().reversed.toList();

        StudyRoom? featured;
        for (final r in upcoming) {
          if (r.isLive && r.hasMember(v.uid)) { featured = r; break; }
        }
        featured ??= upcoming.where((r) => r.isLive).cast<StudyRoom?>().firstWhere((_) => true, orElse: () => null);
        featured ??= upcoming.where((r) => r.hasMember(v.uid)).cast<StudyRoom?>().firstWhere((_) => true, orElse: () => null);
        featured ??= upcoming.isEmpty ? null : upcoming.first;

        return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          ScreenTitle('Let\u2019s figure it out.', featured?.topic ?? 'Study together, online or on campus.',
              trailing: IconButton.filledTonal(
                tooltip: 'Schedule session',
                onPressed: () => pushPage(context, const ScheduleSessionScreen()),
                icon: const Icon(Icons.add, size: 20),
              )),
          if (featured == null)
            EmptyState(
              title: 'No study sessions yet.',
              text: 'Schedule a session to invite your campus community.',
              action: FilledButton(
                  onPressed: () => pushPage(context, const ScheduleSessionScreen()),
                  child: const Text('Schedule session')),
            )
          else ...[
            RoomHero(room: featured, onOpen: () => pushPage(context, StudyRoomScreen(roomId: featured!.id))),
            if (featured.agenda.isNotEmpty) AgendaCard(agenda: featured.agenda),
            PCard(
              child: Column(children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => pushPage(context, StudyRoomScreen(roomId: featured!.id)),
                    child: const Text('Open shared notes \u2192'),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Your notes save automatically for everyone.', style: Txt.caption(context)),
              ]),
            ),
          ],
          if (upcoming.length > 1 || past.isNotEmpty) const SectionHeader('All sessions'),
          for (final r in upcoming.where((r) => r.id != featured?.id)) _RoomRow(room: r),
          for (final r in past.take(5)) _RoomRow(room: r, faded: true),
        ]);
      },
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.room, this.faded = false});
  final StudyRoom room;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PCard(
      onTap: () => pushPage(context, StudyRoomScreen(roomId: room.id)),
      padding: const EdgeInsets.all(14),
      child: Opacity(
        opacity: faded ? 0.6 : 1,
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.menu_book_outlined, color: p.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(room.title, style: Txt.h2(context)),
              Text('${room.topic} \u00b7 ${fmtDateTime(room.startsAt)}', style: Txt.caption(context)),
              Text('${room.location} \u00b7 ${room.members} joined', style: Txt.caption(context)),
            ]),
          ),
          Icon(Icons.chevron_right, color: p.muted),
        ]),
      ),
    );
  }
}

/// Dark "live session" card from the Figma design.
class RoomHero extends StatelessWidget {
  const RoomHero({super.key, required this.room, this.onOpen});
  final StudyRoom room;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    final p = context.pal;
    return PCard(
      dark: true,
      padding: const EdgeInsets.all(18),
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, size: 7, color: room.isLive ? const Color(0xFF22C55E) : Colors.white70),
            const SizedBox(width: 6),
            Text(
              room.isLive ? 'LIVE \u00b7 ${room.members} STUDENTS' : 'UPCOMING \u00b7 ${room.members} JOINED',
              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Colors.white),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Text(room.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
        const SizedBox(height: 6),
        Text('${fmtDateTime(room.startsAt)} \u00b7 ${room.location}',
            style: const TextStyle(fontSize: 12, color: Color(0xFFC9C4F5))),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.primary),
            onPressed: () => joinMeeting(context, room, v),
            child: const Text('Join video meeting \u2192'),
          ),
        ),
      ]),
    );
  }
}

class AgendaCard extends StatelessWidget {
  const AgendaCard({super.key, required this.agenda});
  final List<String> agenda;

  @override
  Widget build(BuildContext context) => PCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today\u2019s game plan', style: Txt.h2(context)),
          const SizedBox(height: 10),
          for (var i = 0; i < agenda.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 28, child: Text((i + 1).toString().padLeft(2, '0'), style: Txt.caption(context))),
                Expanded(child: Text(agenda[i], style: Txt.body(context))),
              ]),
            ),
        ]),
      );
}

class ScheduleSessionScreen extends StatefulWidget {
  const ScheduleSessionScreen({super.key});
  @override
  State<ScheduleSessionScreen> createState() => _ScheduleSessionScreenState();
}

class _ScheduleSessionScreenState extends State<ScheduleSessionScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _topic = TextEditingController();
  final _location = TextEditingController(text: 'Online (Jitsi)');
  final _agenda = TextEditingController();
  DateTime? _when;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _topic.dispose();
    _location.dispose();
    _agenda.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: _when ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when ?? now.add(const Duration(hours: 1))));
    if (t == null) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_when == null) {
      setState(() => _error = 'Pick a date and time.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final agenda = _agenda.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final id = await Db.createStudyRoom(context.read<ViewerData>().me,
          title: _title.text, topic: _topic.text, startsAt: _when!, location: _location.text, agenda: agenda);
      if (!mounted) return;
      Navigator.pop(context);
      pushPage(context, StudyRoomScreen(roomId: id));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required.' : null;

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Schedule session',
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(controller: _title, maxLength: 180, decoration: const InputDecoration(labelText: 'Session title'), validator: _required),
            const SizedBox(height: 8),
            TextFormField(controller: _topic, maxLength: 180, decoration: const InputDecoration(labelText: 'Topic', hintText: 'e.g. CS Study Circle \u00b7 Data structures'), validator: _required),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickWhen,
              icon: const Icon(Icons.event_outlined, size: 19),
              label: Text(_when == null ? 'Pick date and time' : fmtDateTime(_when!)),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _location, maxLength: 300, decoration: const InputDecoration(labelText: 'Venue or online'), validator: _required),
            const SizedBox(height: 8),
            TextFormField(
              controller: _agenda,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Game plan (one item per line)', hintText: 'Binary tree warm-up\nWalk through DFS and BFS'),
            ),
            if (_error != null) ErrorNote(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Scheduling\u2026' : 'Schedule session')),
          ]),
        ),
      );
}

class StudyRoomScreen extends StatelessWidget {
  const StudyRoomScreen({super.key, required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    return PageScaffold(
      title: 'Study room',
      child: StreamBuilder<StudyRoom?>(
        stream: Db.studyRoomStream(roomId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Loading();
          final room = snap.data;
          if (room == null) {
            return const EmptyState(title: 'This session no longer exists.', text: 'It may have been removed.');
          }
          final joined = room.hasMember(v.uid);
          return ListView(padding: const EdgeInsets.only(top: 4, bottom: 24), children: [
            RoomHero(room: room),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: joined
                  ? (room.ownerId == v.uid
                      ? Text('You\u2019re hosting this session.', style: Txt.caption(context))
                      : OutlinedButton(
                          onPressed: () async {
                            try {
                              await Db.setRoomMember(room.id, v.uid, false);
                            } catch (e) {
                              if (context.mounted) toastError(context, e);
                            }
                          },
                          child: const Text('Leave session')))
                  : FilledButton(
                      onPressed: () async {
                        try {
                          await Db.setRoomMember(room.id, v.uid, true);
                        } catch (e) {
                          if (context.mounted) toastError(context, e);
                        }
                      },
                      child: const Text('Join session')),
            ),
            if (room.agenda.isNotEmpty) AgendaCard(agenda: room.agenda),
            SectionHeader('Shared notes',
                actionLabel: '+ Add note',
                onAction: () {
                  if (!joined) {
                    toast(context, 'Join the session to share notes.');
                    return;
                  }
                  _noteSheet(context, room.id, null);
                }),
            StreamBuilder<List<SharedNote>>(
              stream: Db.notes(room.id),
              builder: (context, ns) {
                if (ns.hasError) return ErrorNote(friendlyError(ns.error!));
                if (!ns.hasData) return const Loading();
                final notes = ns.data!;
                if (notes.isEmpty) {
                  return const EmptyState(title: 'No notes yet.', text: 'Add the first note for everyone in this session.');
                }
                return Column(children: [
                  for (final n in notes)
                    PCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(n.title, style: Txt.h2(context))),
                          if (n.authorId == v.uid)
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_horiz, color: context.pal.muted),
                              onSelected: (s) async {
                                if (s == 'edit') _noteSheet(context, room.id, n);
                                if (s == 'delete') {
                                  final ok = await confirm(context,
                                      title: 'Delete note?', message: 'This removes it for everyone.', action: 'Delete', danger: true);
                                  if (ok) await Db.deleteNote(room.id, n.id);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                        ]),
                        const SizedBox(height: 4),
                        Text(n.content, style: Txt.body(context)),
                        const SizedBox(height: 8),
                        Text('${n.author} \u00b7 ${timeAgo(n.updatedAt)}', style: Txt.caption(context)),
                      ]),
                    ),
                ]);
              },
            ),
          ]);
        },
      ),
    );
  }

  void _noteSheet(BuildContext context, String roomId, SharedNote? note) {
    final title = TextEditingController(text: note?.title ?? '');
    final content = TextEditingController(text: note?.content ?? '');
    final v = context.read<ViewerData>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        String? error;
        bool busy = false;
        return StatefulBuilder(builder: (ctx, setS) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(note == null ? 'Share a note' : 'Edit note', style: Txt.h2(ctx)),
              const SizedBox(height: 12),
              TextField(controller: title, maxLength: 180, decoration: const InputDecoration(labelText: 'Note title')),
              const SizedBox(height: 4),
              TextField(controller: content, maxLines: 7, maxLength: 20000, decoration: const InputDecoration(labelText: 'Note')),
              if (error != null) ErrorNote(error!),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (title.text.trim().isEmpty || content.text.trim().isEmpty) {
                          setS(() => error = 'Add a title and some content.');
                          return;
                        }
                        setS(() => busy = true);
                        try {
                          await Db.saveNote(v.me, roomId, noteId: note?.id, title: title.text, content: content.text);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setS(() {
                            error = friendlyError(e);
                            busy = false;
                          });
                        }
                      },
                child: Text(busy ? 'Saving\u2026' : 'Share notes'),
              ),
            ]),
          );
        });
      },
    );
  }
}
