import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-only preferences (theme, text size, contrast, education focus).
class SettingsController extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light;
  bool largeText = false;
  bool highContrast = true;
  bool educationOnly = false;
  SharedPreferences? _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final t = _p!.getString('themeMode');
    themeMode = t == 'dark' ? ThemeMode.dark : t == 'system' ? ThemeMode.system : ThemeMode.light;
    largeText = _p!.getBool('largeText') ?? false;
    highContrast = _p!.getBool('highContrast') ?? true;
    educationOnly = _p!.getBool('educationOnly') ?? false;
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await _p?.setString('themeMode', m == ThemeMode.dark ? 'dark' : m == ThemeMode.system ? 'system' : 'light');
    notifyListeners();
  }

  Future<void> setLargeText(bool v) async {
    largeText = v;
    await _p?.setBool('largeText', v);
    notifyListeners();
  }

  Future<void> setHighContrast(bool v) async {
    highContrast = v;
    await _p?.setBool('highContrast', v);
    notifyListeners();
  }

  Future<void> setEducationOnly(bool v) async {
    educationOnly = v;
    await _p?.setBool('educationOnly', v);
    notifyListeners();
  }
}

const educationTags = ['study', 'opportunity', 'education', 'course', 'research', 'career', 'scholarship', 'academic'];
bool isEducationTag(String? tag) => educationTags.contains((tag ?? '').trim().toLowerCase());
