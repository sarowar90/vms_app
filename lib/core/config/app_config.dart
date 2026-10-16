/// App-wide configuration.
///
/// Uses the live server by default. To test against local XAMPP instead:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.0.199/vms/external_api/`
class AppConfig {
  const AppConfig._();

  static const appName = 'VMS';

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://paprishop.com/vms/external_api/',
  );

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 30);

  /// The API returns server-relative paths (e.g. `/vms/uploads/x.jpg`) for files.
  static String? resolveUrl(String? path) =>
      path == null || path.isEmpty ? null : Uri.parse(apiBaseUrl).resolve(path).toString();
}
