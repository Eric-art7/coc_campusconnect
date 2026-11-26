import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/db.dart';
import '../state/settings.dart';
import '../state/viewer.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import 'admin/admin_screens.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    final me = v.me;
    final p = context.pal;

    Widget row(String title, String subtitle, Widget page) => ListTile(
          onTap: () => pushPage(context, page),
          title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: Txt.caption(context)),
          trailing: Icon(Icons.chevron_right, color: p.muted),
        );

    return PageScaffold(
      title: 'Settings',
      child: ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
        const ScreenTitle('Make it your own.', 'Your preferences. Your boundaries.'),
        PCard(
          child: Row(children: [
            Avatar(me.initials, radius: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(me.fullName, style: Txt.h2(context)),
                Text(v.emailVerified ? 'Email verified' : 'Email not verified', style: Txt.caption(context)),
              ]),
            ),
          ]),
        ),
        PCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            row('Edit profile', 'Your bio, department & interests', const EditProfileScreen()),
            Divider(height: 1, color: p.line),
            row('Theme & accessibility', 'Appearance, text size and contrast', const AppearanceScreen()),
            Divider(height: 1, color: p.line),
            row('Content & focus', 'Education-focused feed', const ContentFocusScreen()),
            Divider(height: 1, color: p.line),
            row('Privacy & security', 'Your account, protected', const PrivacyScreen()),
            Divider(height: 1, color: p.line),
            row('Help & community guidelines', 'A kinder campus starts here', const GuidelinesScreen()),
            if (me.isAdmin) ...[
              Divider(height: 1, color: p.line),
              row('Administration', 'Users and moderation', const AdminScreen()),
            ],
          ]),
        ),
        PCard(
          padding: EdgeInsets.zero,
          onTap: () async {
            final ok = await confirm(context,
                title: 'Log out?', message: 'You\u2019ll need to sign in again to use CampusConnect.', action: 'Log out');
            if (ok) await AuthService.signOut();
          },
          child: const SizedBox(
            height: 50,
            child: Center(child: Text('Log out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          ),
        ),
      ]),
    );
  }
}

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    return PageScaffold(
      title: 'Theme & accessibility',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('App appearance', style: Txt.h2(context)),
        const SizedBox(height: 4),
        Text('Switch between light and dark, or follow your device setting.', style: Txt.caption(context)),
        const SizedBox(height: 12),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ButtonSegment(value: ThemeMode.system, label: Text('System')),
          ],
          selected: {s.themeMode},
          onSelectionChanged: (set) => s.setThemeMode(set.first),
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Larger text'),
          subtitle: const Text('Enlarge text a little throughout the app.'),
          value: s.largeText,
          onChanged: s.setLargeText,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('High contrast text'),
          subtitle: const Text('Stronger contrast for secondary text and labels.'),
          value: s.highContrast,
          onChanged: s.setHighContrast,
        ),
        const SizedBox(height: 8),
        Text('Saved on this device.', style: Txt.caption(context)),
      ]),
    );
  }
}

class ContentFocusScreen extends StatelessWidget {
  const ContentFocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    return PageScaffold(
      title: 'Content & focus',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Education-focused feed'),
          subtitle: const Text('Show study, course, research, career and opportunity posts only.'),
          value: s.educationOnly,
          onChanged: s.setEducationOnly,
        ),
        const SizedBox(height: 8),
        Text('Saved on this device.', style: Txt.caption(context)),
      ]),
    );
  }
}

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});
  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _save(ViewerData v, {String? visibility, String? requests, bool? searchable}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Db.updatePrivacy(v.uid,
          profileVisibility: visibility ?? v.me.profileVisibility,
          messageRequests: requests ?? v.me.messageRequests,
          searchable: searchable ?? v.me.searchable);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ViewerData>();
    final me = v.me;
    return PageScaffold(
      title: 'Privacy & security',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_error != null) ErrorNote(_error!),
        DropdownButtonFormField<String>(
          key: ValueKey(me.profileVisibility),
          initialValue: me.profileVisibility,
          decoration: const InputDecoration(labelText: 'Profile visibility', helperText: 'Choose who can find your profile.'),
          items: const [
            DropdownMenuItem(value: 'CAMPUS', child: Text('Everyone on campus')),
            DropdownMenuItem(value: 'CONNECTIONS', child: Text('Connections only')),
            DropdownMenuItem(value: 'PRIVATE', child: Text('Only me')),
          ],
          onChanged: _busy ? null : (x) => _save(v, visibility: x),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(me.messageRequests),
          initialValue: me.messageRequests,
          decoration: const InputDecoration(labelText: 'Message requests', helperText: 'Choose who can start a conversation.'),
          items: const [
            DropdownMenuItem(value: 'CAMPUS', child: Text('Everyone on campus')),
            DropdownMenuItem(value: 'CONNECTIONS', child: Text('Connections only')),
            DropdownMenuItem(value: 'NOBODY', child: Text('Nobody')),
          ],
          onChanged: _busy ? null : (x) => _save(v, requests: x),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Appear in campus search'),
          subtitle: const Text('Let other students find your profile in search.'),
          value: me.searchable,
          onChanged: _busy ? null : (x) => _save(v, searchable: x),
        ),
        const Divider(height: 32),
        Text('Account security', style: Txt.h2(context)),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.mark_email_read_outlined),
          title: Text(v.emailVerified ? 'Email verified' : 'Email not verified'),
          subtitle: Text(v.email),
          trailing: v.emailVerified
              ? null
              : TextButton(
                  onPressed: () async {
                    try {
                      await AuthService.resendVerification();
                      if (context.mounted) toast(context, 'Verification email sent.');
                    } catch (e) {
                      if (context.mounted) toastError(context, e);
                    }
                  },
                  child: const Text('Resend')),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_reset_outlined),
          title: const Text('Change password'),
          subtitle: const Text('We\u2019ll email you a secure reset link.'),
          onTap: () async {
            try {
              await AuthService.sendPasswordReset(v.email);
              if (context.mounted) toast(context, 'Password reset link sent to ${v.email}.');
            } catch (e) {
              if (context.mounted) toastError(context, e);
            }
          },
        ),
      ]),
    );
  }
}

class GuidelinesScreen extends StatelessWidget {
  const GuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Be kind', 'Treat every student with respect. Disagree with ideas, not people.'),
      ('Stay on campus topics', 'Share ideas, study help, events and opportunities that help your community.'),
      ('Protect privacy', 'Don\u2019t share anyone\u2019s personal details, and keep passwords to yourself.'),
      ('Report, don\u2019t escalate', 'Use Report on a post if something isn\u2019t right. Administrators review every report.'),
      ('Study honestly', 'Share notes to help others learn \u2014 not to cheat.'),
    ];
    return PageScaffold(
      title: 'Community guidelines',
      child: ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
        const ScreenTitle('A kinder campus starts here.', 'How we look after each other.'),
        for (final (t, d) in items)
          PCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: Txt.h2(context)),
              const SizedBox(height: 4),
              Text(d, style: Txt.body(context)),
            ]),
          ),
      ]),
    );
  }
}
