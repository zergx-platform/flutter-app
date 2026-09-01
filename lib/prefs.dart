import 'package:shared_preferences/shared_preferences.dart';

const _kBase = 'base_url';
const _kToken = 'token';
const _kDark = 'dark_mode';

class Prefs {
  final String? baseUrl;
  final String? token;
  final bool darkMode;
  const Prefs({this.baseUrl, this.token, this.darkMode = true});

  static Future<Prefs> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return Prefs(
        baseUrl: p.getString(_kBase),
        token: p.getString(_kToken),
        darkMode: p.getBool(_kDark) ?? true,
      );
    } catch (_) {
      return const Prefs();
    }
  }

  static Future<void> save(String base, String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBase, base);
    await p.setString(_kToken, token);
  }

  /// Log out: forget the saved gateway + token (locale & dark mode stay).
  static Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kBase);
      await p.remove(_kToken);
    } catch (_) {}
  }

  static Future<void> saveDarkMode(bool dark) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kDark, dark);
    } catch (_) {}
  }
}