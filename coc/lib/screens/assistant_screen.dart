import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/theme.dart';
import '../services/db.dart';
import '../state/viewer.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import 'events_screen.dart';
import 'groups_screen.dart';
import 'post_detail_screen.dart';
import 'study_screen.dart';

class _Hit {
  _Hit(this.kind, this.id, this.title, this.subtitle);
  final String kind, id, title, subtitle;
}

class _Turn {
  _Turn.user(this.text)
      : user = true,
        hits = const [],
        query = null,
        sources = 0;
  _Turn.assistant(this.text, {this.hits = const [], this.query, this.sources = 0}) : user = false;
  final bool user;
  final String text;
  final List<_Hit> hits;
  final String? query;
  final int sources;
}

const _stop = {
  'find', 'show', 'me', 'the', 'an', 'for', 'on', 'in', 'of', 'and', 'to', 'any', 'some', 'are', 'there',
  'is', 'what', 'where', 'can', 'my', 'about', 'with', 'near', 'campus', 'please', 'give', 'list', 'looking',
  'group', 'groups', 'club', 'clubs', 'society', 'circle', 'session', 'sessions', 'room', 'rooms', 'study',
  'post', 'posts', 'event', 'events', 'upcoming', 'meeting', 'meetings', 'i', 'a', 'need', 'want',
};

/// Searches campus data stored in Firestore (keyword matching) and offers
/// links for research beyond campus. No external AI service is called.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final List<_Turn> _turns = [];
  bool _thinking = false;

  static const _suggestions = [
    'Find computer science study groups',
    'Upcoming study sessions',
    'Posts about internships',
    'Events this week',
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _ask(String raw) async {
    final q = raw.trim();
    if (q.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _turns.add(_Turn.user(q));
      _thinking = true;
    });
    try {
      final index = await Db.campusIndex();
      final lower = q.toLowerCase();
      final tokens = RegExp(r'[a-z0-9+#]+')
          .allMatches(lower)
          .map((m) => m.group(0)!)
          .where((t) => t.length > 1 && !_stop.contains(t))
          .toList();

      final wantGroups = RegExp(r'group|club|society|circle').hasMatch(lower);
      final wantRooms = RegExp(r'session|study room|room|meeting|study').hasMatch(lower) && !wantGroups ||
          lower.contains('session');
      final wantPosts = lower.contains('post');
      final wantEvents = lower.contains('event');
      final any = !(wantGroups || wantRooms || wantPosts || wantEvents);

      int score(String hay) {
        if (tokens.isEmpty) return 1;
        final h = hay.toLowerCase();
        return tokens.where(h.contains).length;
      }

      List<_Hit> top<T>(Iterable<T> items, int Function(T) s, _Hit Function(T) toHit) {
        final scored = items.map((i) => MapEntry(i, s(i))).where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return scored.take(3).map((e) => toHit(e.key)).toList();
      }

      final hits = <_Hit>[
        if (wantGroups || any)
          ...top(index.groups, (g) => score('${g.name} ${g.category} ${g.description}'),
              (g) => _Hit('group', g.id, g.name, '${g.members} members \u00b7 ${g.category}')),
        if (wantRooms || any)
          ...top(index.rooms, (r) => score('${r.title} ${r.topic} ${r.location} ${r.agenda.join(' ')}'),
              (r) => _Hit('room', r.id, r.title, r.topic)),
        if (wantPosts || any)
          ...top(index.posts, (p) => score('${p.body} ${p.tag ?? ''} ${p.course} ${p.author}'),
              (p) => _Hit('post', p.id, p.body.length > 70 ? '${p.body.substring(0, 70)}\u2026' : p.body, 'by ${p.author}')),
        if (wantEvents || any)
          ...top(index.events, (e) => score('${e.title} ${e.description} ${e.organization} ${e.category}'),
              (e) => _Hit('event', e.id, e.title, e.organization)),
      ];

      if (!mounted) return;
      final sources = index.groups.length + index.rooms.length + index.posts.length + index.events.length;
      setState(() => _turns.add(hits.isEmpty
          ? _Turn.assistant(
              'I couldn\u2019t find anything on campus for that yet. Try different words, or look beyond campus below.',
              query: q)
          : _Turn.assistant('Here\u2019s a good place to start. These match what you asked for:',
              hits: hits, query: q, sources: sources)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _turns.add(_Turn.assistant(friendlyError(e), query: q)));
    }
    if (mounted) setState(() => _thinking = false);
  }

  void _open(_Hit h) {
    switch (h.kind) {
      case 'group':
        pushPage(context, GroupDetailScreen(groupId: h.id));
      case 'room':
        pushPage(context, StudyRoomScreen(roomId: h.id));
      case 'post':
        pushPage(context, PostDetailScreen(postId: h.id));
      default:
        pushPage(context, const EventsScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    final p = context.pal;
    final first = v.me.fullName.split(' ').first;

    final items = <Widget>[
      // Newest at the bottom: the list is reversed, so build in reverse order.
      if (_thinking)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text('Searching campus\u2026', style: Txt.caption(context)),
        ),
      for (final t in _turns.reversed) _bubble(context, t),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Campus assistant', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.primary)),
          const SizedBox(height: 6),
          Text('Hi $first! Ask about groups, study sessions, posts or events on your campus.',
              style: Txt.body(context)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in _suggestions)
              ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 12)),
                onPressed: () => _ask(s),
              ),
          ]),
        ]),
      ),
    ];

    return Column(children: [
      const Align(
          alignment: Alignment.centerLeft,
          child: ScreenTitle('A little help, right here.', 'Ask, discover, and connect the dots.')),
      Expanded(
        child: ListView(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: items,
        ),
      ),
      InputBar(controller: _input, hint: 'Ask about your campus\u2026', busy: _thinking, onSend: () => _ask(_input.text)),
    ]);
  }

  Widget _bubble(BuildContext context, _Turn t) {
    final p = context.pal;
    if (t.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(14)),
          child: Text(t.text, style: TextStyle(fontSize: 13.5, color: p.primary, fontWeight: FontWeight.w500)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Campus assistant', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.primary)),
        const SizedBox(height: 6),
        Text(t.text, style: Txt.body(context)),
        for (final h in t.hits)
          Container(
            margin: const EdgeInsets.only(top: 10),
            child: Material(
              color: p.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.line)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _open(h),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        TagChip(switch (h.kind) {
                          'group' => 'Group',
                          'room' => 'Study session',
                          'post' => 'Post',
                          _ => 'Event',
                        }),
                        const SizedBox(height: 8),
                        Text(h.title, style: Txt.h2(context), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(h.subtitle, style: Txt.caption(context)),
                      ]),
                    ),
                    Icon(Icons.arrow_forward, size: 17, color: p.ink),
                  ]),
                ),
              ),
            ),
          ),
        if (t.hits.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Based on ${t.sources} campus items, matched by keywords. Check the originals.',
              style: TextStyle(fontSize: 10.5, color: p.muted)),
        ],
        if (t.query != null) ...[
          const SizedBox(height: 10),
          Text('Research beyond campus', style: Txt.caption(context).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final (name, base) in const [
              ('Perplexity', 'https://www.perplexity.ai/search?q='),
              ('ChatGPT', 'https://chatgpt.com/?q='),
              ('Google Scholar', 'https://scholar.google.com/scholar?q='),
            ])
              ActionChip(
                avatar: const Icon(Icons.open_in_new, size: 14),
                label: Text(name, style: const TextStyle(fontSize: 12)),
                onPressed: () => openUrl(context, '$base${Uri.encodeQueryComponent(t.query!)}'),
              ),
          ]),
          const SizedBox(height: 4),
          Text('Your question is shared with a provider only when you open its link. Don\u2019t include passwords or personal details.',
              style: TextStyle(fontSize: 10.5, color: p.muted)),
        ],
      ]),
    );
  }
}
