import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_screens.dart';
import 'screens/shell.dart';
import 'state/settings.dart';
import 'state/tab_nav.dart';
import 'state/viewer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController();
  await settings.load();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(SetupErrorApp(error: e.toString()));
    return;
  }
  runApp(ChangeNotifierProvider.value(value: settings, child: const CampusConnectApp()));
}

class CampusConnectApp extends StatelessWidget {
  const CampusConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final light = buildTheme(Brightness.light, s.highContrast);
    final dark = buildTheme(Brightness.dark, s.highContrast);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: light,
            home: const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        final user = snap.data;
        // The key rebuilds the whole app (and clears pushed screens) on sign in / out.
        return MultiProvider(
          key: ValueKey(user?.uid ?? 'signed-out'),
          providers: [
            ChangeNotifierProvider<TabNav>(create: (_) => TabNav()),
            if (user != null)
              ChangeNotifierProvider<ViewerData>(create: (_) => ViewerData(user)..start()),
          ],
          child: MaterialApp(
            title: 'CampusConnect',
            debugShowCheckedModeBanner: false,
            theme: light,
            darkTheme: dark,
            themeMode: s.themeMode,
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx)
                  .copyWith(textScaler: TextScaler.linear(s.largeText ? 1.15 : 1.0)),
              child: child!,
            ),
            home: user == null ? const AuthFlow() : const Shell(),
          ),
        );
      },
    );
  }
}

/// Shown when Firebase has not been configured yet.
class SetupErrorApp extends StatelessWidget {
  const SetupErrorApp({super.key, required this.error});
  final String error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light, true),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Almost there', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text(error.replaceFirst('Bad state: ', '')),
                ],
              ),
            ),
          ),
        ),
      );
}
