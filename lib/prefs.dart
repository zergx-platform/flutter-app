import 'package:shared_preferences/shared_preferences.dart';

const _kBase = 'base_url';
const _kToken = 'token';

class Prefs {
  final String? baseUrl;
  final String? token;
  const Prefs({this.baseUrl, this.token});

  static Future<Prefs> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return Prefs(baseUrl: p.getString(_kBase), token: p.getString(_kToken));
    } catch (_) {
      return const Prefs();
    }
  }

  static Future<void> save(String base, String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBase, base);
    await p.setString(_kToken, token);
  }
}