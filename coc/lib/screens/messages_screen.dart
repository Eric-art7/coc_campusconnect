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

/// Opens (or creates) a conversation with [otherId] and shows it.
Future<void> openChatWith(BuildContext context, String otherId) async {
  final v = context.read<ViewerData>();
  try {
    final id = await Db.openConversation(v.me, otherId, mutual: v.isConnection(otherId));
    if (context.mounted) pushPage(context, ChatScreen(conversationId: id));
  } catch (e) {
    if (context.mounted) toastError(context, e);
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  Stream<List<Conversation>>? _stream;
  String? _uid;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    if (_uid != v.uid) {
      _uid = v.uid;
      _stream = Db.conversations(v.uid);
    }
    final q = _search.text.trim().toLowerCase();

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      ScreenTitle('Messages', 'Good conversations start here.',
          trailing: IconButton.filledTonal(
            tooltip: 'New message',
            onPressed: () => _newMessage(context),
            icon: const Icon(Icons.edit_outlined, size: 19),
          )),
      SearchField(controller: _search, hint: 'Search messages\u2026', onChanged: (_) => setState(() {})),
      StreamBuilder<List<Conversation>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorNote(friendlyError(snap.error!));
          if (!snap.hasData) return const Loading();
          var list = snap.data!;
          if (q.isNotEmpty) {
            list = list
                .where((c) => c.otherName(v.uid).toLowerCase().contains(q) || c.lastMessage.toLowerCase().contains(q))
                .toList();
          }
          if (list.isEmpty) {
            return EmptyState(
              title: q.isEmpty ? 'No conversations yet.' : 'No matches.',
              text: q.isEmpty ? 'Search for a campus member to start one.' : 'Try another name or word.',
              action: q.isEmpty
                  ? FilledButton(onPressed: () => _newMessage(context), child: const Text('Start a conversation'))
                  : null,
            );
          }
          return Column(children: [
            for (final c in list)
              PersonRow(
                initials: initialsOf(c.otherName(v.uid)),
                name: c.otherName(v.uid),
                detail: c.lastMessage.isEmpty
                    ? 'No messages yet'
                    : '${c.lastSenderId == v.uid ? 'You: ' : ''}${c.lastMessage}',
                trailing: Text(timeAgo(c.updatedAt), style: Txt.caption(context)),
                onTap: () => pushPage(context, ChatScreen(conversationId: c.id)),
              ),
          ]);
        },
      ),
    ]);
  }

  void _newMessage(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NewMessageSheet(),
    );
  }
}

class _NewMessageSheet extends StatefulWidget {
  const _NewMessageSheet();
  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  final _q = TextEditingController();
  List<AppUser> _people = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final v = context.read<ViewerData>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = _q.text.trim().isEmpty
          ? await Db.recentPeople(v.uid, v.isConnection)
          : await Db.searchPeople(_q.text, v.uid, v.isConnection);
      if (mounted) setState(() => _people = res);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text('New message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ),
          SearchField(controller: _q, hint: 'Find a student by name', onSubmitted: (_) => _run()),
          if (_error != null) ErrorNote(_error!),
          Expanded(
            child: _loading
                ? const Loading()
                : _people.isEmpty
                    ? const EmptyState(title: 'No people found.', text: 'Try another name.')
                    : ListView(children: [
                        for (final u in _people)
                          PersonRow(
                            initials: u.initials,
                            name: u.fullName,
                            detail: u.detail,
                            onTap: () {
                              final parent = nav.context;
                              nav.pop();
                              openChatWith(parent, u.id);
                            },
                          ),
                      ]),
          ),
        ]),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final Stream<List<Message>> _messages = Db.messages(widget.conversationId);
  late final Stream<Conversation?> _conv = FirebaseConversation.stream(widget.conversationId);
  final _input = TextEditingController();
  bool _busy = false;
  int _lastMarked = -1;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(Conversation c) async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _busy = true);
    try {
      await Db.sendMessage(context.read<ViewerData>().me, c, text);
    } catch (e) {
      if (mounted) {
        _input.text = text;
        toastError(context, e);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _call(Conversation c) async {
    final v = context.read<ViewerData>();
    try {
      final url = await Db.startCall(v.me, c);
      if (mounted) await openUrl(context, url);
    } catch (e) {
      if (mounted) toastError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    final p = context.pal;

    return StreamBuilder<Conversation?>(
      stream: _conv,
      builder: (context, cs) {
        final c = cs.data;
        if (cs.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Loading());
        }
        if (c == null) {
          return const PageScaffold(
              title: 'Chat', child: EmptyState(title: 'Conversation not found.', text: 'It may have been removed.'));
        }
        final other = c.otherName(v.uid);
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(children: [
              Avatar(initialsOf(other), radius: 16),
              const SizedBox(width: 10),
              Expanded(child: Text(other, overflow: TextOverflow.ellipsis)),
            ]),
            actions: [
              IconButton(
                tooltip: 'Voice call',
                icon: const Icon(Icons.call_outlined),
                onPressed: () => _call(c),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(children: [
              Expanded(
                child: StreamBuilder<List<Message>>(
                  stream: _messages,
                  builder: (context, ms) {
                    if (ms.hasError) return ErrorNote(friendlyError(ms.error!));
                    if (!ms.hasData) return const Loading();
                    final list = ms.data!;
                    final unread = list.where((m) => m.senderId != v.uid && m.readAt == null).length;
                    if (unread > 0 && unread != _lastMarked) {
                      _lastMarked = unread;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Db.markMessagesRead(c.id, v.uid).catchError((_) {});
                      });
                    }
                    if (list.isEmpty) {
                      return const EmptyState(title: 'No messages yet.', text: 'Say hello \u{1F44B}');
                    }
                    // newest first + reverse:true keeps the latest message at the bottom
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final m = list[i];
                            final mine = m.senderId == v.uid;
                            return Align(
                              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: mine ? p.tint : p.card,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: mine ? Colors.transparent : p.line),
                                      ),
                                      child: Text(m.body, style: Txt.body(context)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                                      child: Text(
                                        '${fmtTime(m.createdAt)}${mine ? (m.readAt != null ? ' \u00b7 Read' : ' \u00b7 Sent') : ''}',
                                        style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: InputBar(controller: _input, hint: 'Write a message\u2026', busy: _busy, onSend: () => _send(c)),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Small helper so the chat screen can watch a single conversation document.
class FirebaseConversation {
  static Stream<Conversation?> stream(String id) => Db.conversationStream(id);
}
