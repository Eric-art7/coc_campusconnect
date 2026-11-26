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

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _p?.setString('themeMode', m == ThemeMode.dark ? 'dark' : m == ThemeMode.system ? 'system' : 'light');
    notifyListeners();
  }

  void setLargeText(bool v) {
    largeText = v;
    _p?.setBool('largeText', v);
    notifyListeners();
  }

  void setHighContrast(bool v) {
    highContrast = v;
    _p?.setBool('highContrast', v);
    notifyListeners();
  }

  void setEducationOnly(bool v) {
    educationOnly = v;
    _p?.setBool('educationOnly', v);
    notifyListeners();
  }
}

const educationTags = ['study', 'opportunity', 'education', 'course', 'research', 'career', 'scholarship', 'academic'];
bool isEducationTag(String? tag) => educationTags.contains((tag ?? '').trim().toLowerCase());
