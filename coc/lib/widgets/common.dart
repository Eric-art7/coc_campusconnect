import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/errors.dart';
import '../core/theme.dart';

void toast(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(content: Text(message)));
}

void toastError(BuildContext context, Object error) => toast(context, friendlyError(error));

Future<void> openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    toast(context, 'That link can\u2019t be opened.');
    return;
  }
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) toast(context, 'Could not open the link.');
  } catch (_) {
    if (context.mounted) toast(context, 'Could not open the link.');
  }
}

Future<bool> confirm(BuildContext context,
    {required String title, required String message, String action = 'Confirm', bool danger = false}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action, style: danger ? TextStyle(color: ctx.pal.danger) : null),
        ),
      ],
    ),
  );
  return res ?? false;
}

class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.radius = 18});
  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: context.pal.tint,
        child: Text(initials,
            style: TextStyle(
                fontSize: radius * 0.72, fontWeight: FontWeight.w700, color: context.pal.primary)),
      );
}

class TagChip extends StatelessWidget {
  const TagChip(this.text, {super.key, this.green = false});
  final String text;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: green ? p.success.withAlpha(28) : p.tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text.toUpperCase(),
          style: Txt.label(context).copyWith(color: green ? p.success : p.primary)),
    );
  }
}

class PCard extends StatelessWidget {
  const PCard({
    super.key,
    required this.child,
    this.tinted = false,
    this.dark = false,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.onTap,
  });
  final Widget child;
  final bool tinted, dark;
  final EdgeInsets padding, margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final color = dark ? p.deep : (tinted ? p.tint : p.card);
    return Padding(
      padding: margin,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: (tinted || dark) ? Colors.transparent : p.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, this.subtitle, {super.key, this.trailing});
  final String title, subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Txt.h1(context)),
                const SizedBox(height: 4),
                Text(subtitle, style: Txt.caption(context)),
              ]),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
        child: Row(children: [
          Expanded(child: Text(title, style: Txt.h2(context))),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.text, this.action});
  final String title, text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
        child: Column(children: [
          Icon(Icons.auto_awesome_outlined, size: 34, color: context.pal.primary),
          const SizedBox(height: 12),
          Text(title, style: Txt.h2(context), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(text, style: Txt.caption(context), textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      );
}

class ErrorNote extends StatelessWidget {
  const ErrorNote(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.pal.danger.withAlpha(24),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(message, style: TextStyle(color: context.pal.danger, fontSize: 13)),
        ),
      );
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
}

class PillTabs extends StatelessWidget {
  const PillTabs({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < labels.length; i++)
            ChoiceChip(
              label: Text(labels[i]),
              selected: i == index,
              onSelected: (_) => onChanged(i),
              showCheckmark: false,
              selectedColor: p.primary,
              backgroundColor: p.card,
              side: BorderSide(color: p.line),
              labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: i == index ? Colors.white : p.muted),
            ),
        ],
      ),
    );
  }
}

class InputBar extends StatelessWidget {
  const InputBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSend,
    this.busy = false,
    this.sendLabel = 'Send \u2192',
  });
  final TextEditingController controller;
  final String hint, sendLabel;
  final VoidCallback onSend;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 6),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: p.line),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              textInputAction: TextInputAction.send,
              maxLength: 4000,
              style: TextStyle(fontSize: 14, color: p.ink),
              decoration: InputDecoration(
                hintText: hint,
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          TextButton(onPressed: busy ? null : onSend, child: Text(sendLabel)),
        ]),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.controller, required this.hint, this.onChanged, this.onSubmitted});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(Icons.search, size: 19, color: context.pal.muted),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
}

/// Pushed screens (Profile, Settings, etc.) use this wrapper.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.title, required this.child, this.actions, this.scroll = true});
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool scroll;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: child),
          ),
        ),
      );
}

/// Post / campus images. `asset:name.jpg` loads a bundled image, anything else a URL.
class PostImage extends StatelessWidget {
  const PostImage(this.url, {super.key, this.height = 190});
  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget placeholder() => Container(
        height: height,
        color: p.tint,
        child: Center(child: Icon(Icons.image_outlined, color: p.muted)));
    final Widget image = url.startsWith('asset:')
        ? Image.asset('assets/images/${url.substring(6)}',
            height: height, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder())
        : Image.network(url,
            height: height, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder());
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: image);
  }
}

class PersonRow extends StatelessWidget {
  const PersonRow({super.key, required this.initials, required this.name, required this.detail, this.trailing, this.onTap});
  final String initials, name, detail;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => PCard(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        onTap: onTap,
        child: Row(children: [
          Avatar(initials, radius: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: Txt.h2(context)),
              Text(detail, style: Txt.caption(context)),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}
