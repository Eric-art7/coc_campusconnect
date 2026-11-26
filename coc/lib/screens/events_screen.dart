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

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late final Stream<List<CampusEvent>> _events = Db.events();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PageScaffold(
      title: 'Events',
      actions: [
        TextButton.icon(
          onPressed: () => pushPage(context, const PublishEventScreen()),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Publish'),
        ),
      ],
      child: ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
        const ScreenTitle('Events for your campus', 'Official listings from verified universities and public bodies.'),
        PCard(
          tinted: true,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.shield_outlined, color: p.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('For verified organizations', style: Txt.h2(context)),
                const SizedBox(height: 2),
                Text('An administrator must verify a university or government account before it can publish.',
                    style: Txt.caption(context)),
              ]),
            ),
          ]),
        ),
        StreamBuilder<List<CampusEvent>>(
          stream: _events,
          builder: (context, snap) {
            if (snap.hasError) return ErrorNote(friendlyError(snap.error!));
            if (!snap.hasData) return const Loading();
            if (snap.data!.isEmpty) {
              return const EmptyState(
                  title: 'No official events yet.', text: 'Published listings will appear here.');
            }
            return Column(children: [for (final e in snap.data!) _EventCard(event: e)]);
          },
        ),
      ]),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final CampusEvent event;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${event.isGovernment ? 'Government entity' : 'University'} \u00b7 ${event.organization}',
            style: Txt.label(context)),
        const SizedBox(height: 8),
        Text(event.title, style: Txt.h2(context).copyWith(fontSize: 17)),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.event_outlined, size: 16, color: p.muted),
          const SizedBox(width: 6),
          Text(fmtDateTime(event.startsAt), style: Txt.caption(context)),
        ]),
        const SizedBox(height: 3),
        Row(children: [
          Icon(Icons.place_outlined, size: 16, color: p.muted),
          const SizedBox(width: 6),
          Expanded(child: Text(event.location, style: Txt.caption(context))),
        ]),
        if (event.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(event.description, style: Txt.body(context)),
        ],
        if (event.registrationUrl != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => openUrl(context, event.registrationUrl!),
              child: const Text('Event details and registration \u2192'),
            ),
          ),
      ]),
    );
  }
}

class PublishEventScreen extends StatefulWidget {
  const PublishEventScreen({super.key});
  @override
  State<PublishEventScreen> createState() => _PublishEventScreenState();
}

class _PublishEventScreenState extends State<PublishEventScreen> {
  static const _categories = ['Academic and research', 'Career and opportunity', 'Public service', 'Community and culture'];
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  final _url = TextEditingController();
  String? _category;
  DateTime? _starts, _ends;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _location.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? initial) async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: initial ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 730)));
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? now));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_starts == null) {
      setState(() => _error = 'Pick a start date and time.');
      return;
    }
    if (_ends != null && _ends!.isBefore(_starts!)) {
      setState(() => _error = 'The end time must be after the start.');
      return;
    }
    final link = _url.text.trim();
    if (link.isNotEmpty && !(link.startsWith('http://') || link.startsWith('https://'))) {
      setState(() => _error = 'The event link must start with http:// or https://');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Db.publishEvent(context.read<ViewerData>().me,
          title: _title.text,
          category: _category!,
          description: _desc.text,
          startsAt: _starts!,
          endsAt: _ends,
          location: _location.text,
          registrationUrl: link);
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, 'Event published.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required.' : null;

  @override
  Widget build(BuildContext context) {
    final me = context.watch<ViewerData>().me;
    if (!me.organizationVerified) {
      return const PageScaffold(
        title: 'Publish an event',
        child: EmptyState(
          title: 'Organization publishing',
          text: 'Ask an administrator to verify your university or government account before publishing events.',
        ),
      );
    }
    return PageScaffold(
      title: 'Share an official event',
      child: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(me.organizationName ?? me.fullName, style: Txt.h2(context)),
          const SizedBox(height: 12),
          TextFormField(controller: _title, maxLength: 180, decoration: const InputDecoration(labelText: 'Event title'), validator: _req),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [for (final c in _categories) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _category = v),
            validator: (v) => v == null ? 'Select a category.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(controller: _desc, maxLines: 4, maxLength: 10000, decoration: const InputDecoration(labelText: 'Description'), validator: _req),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await _pick(_starts);
              if (d != null) setState(() => _starts = d);
            },
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(_starts == null ? 'Starts \u2014 pick date and time' : 'Starts ${fmtDateTime(_starts!)}'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await _pick(_ends ?? _starts);
              if (d != null) setState(() => _ends = d);
            },
            icon: const Icon(Icons.event_available_outlined, size: 18),
            label: Text(_ends == null ? 'Ends (optional)' : 'Ends ${fmtDateTime(_ends!)}'),
          ),
          const SizedBox(height: 16),
          TextFormField(controller: _location, maxLength: 300, decoration: const InputDecoration(labelText: 'Venue or online location'), validator: _req),
          const SizedBox(height: 8),
          TextFormField(controller: _url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Official event or registration URL', hintText: 'https://')),
          if (_error != null) ErrorNote(_error!),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Publishing\u2026' : 'Publish event')),
        ]),
      ),
    );
  }
}
