import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/theme.dart';
import '../services/db.dart';
import '../state/viewer.dart';
import '../widgets/common.dart';

const postTags = ['Community', 'Study', 'Education', 'Opportunity', 'Research', 'Career', 'Events'];

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _body = TextEditingController();
  final _image = TextEditingController();
  String? _tag;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final v = context.read<ViewerData>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final img = _image.text.trim();
      if (img.isNotEmpty && !(img.startsWith('http://') || img.startsWith('https://'))) {
        throw AppException('Image links must start with http:// or https://');
      }
      await Db.createPost(v.me, body: _body.text, tag: _tag, imageUrl: img);
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, 'Posted to your campus.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    return PageScaffold(
      title: 'Create post',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 18)),
            onPressed: (_busy || _body.text.trim().isEmpty) ? null : _post,
            child: Text(_busy ? 'Posting\u2026' : 'Post'),
          ),
        ),
      ],
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Avatar(v.me.initials, radius: 19),
          const SizedBox(width: 10),
          Text(v.me.fullName, style: Txt.h2(context)),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _body,
          maxLines: 8,
          minLines: 5,
          maxLength: 10000,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Share something with your campus\u2026'),
        ),
        const SizedBox(height: 8),
        Text('Topic', style: Txt.h2(context)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in postTags)
            ChoiceChip(
              label: Text(t),
              selected: _tag == t,
              showCheckmark: false,
              onSelected: (sel) => setState(() => _tag = sel ? t : null),
            ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _image,
          keyboardType: TextInputType.url,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
              labelText: 'Image link (optional)', hintText: 'https://\u2026', prefixIcon: Icon(Icons.image_outlined)),
        ),
        if (_image.text.trim().startsWith('http')) ...[
          const SizedBox(height: 12),
          PostImage(_image.text.trim(), height: 160),
        ],
        const SizedBox(height: 12),
        if (_error != null) ErrorNote(_error!),
      ]),
    );
  }
}
