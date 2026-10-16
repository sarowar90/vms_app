import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with an instance created before `runApp`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(ref.watch(sharedPreferencesProvider)),
);

/// Persists the API bearer token.
class TokenStorage {
  TokenStorage(this._prefs);

  static const _key = 'auth_token';

  final SharedPreferences _prefs;

  String? read() => _prefs.getString(_key);

  Future<void> write(String token) => _prefs.setString(_key, token);

  Future<void> clear() => _prefs.remove(_key);
}
