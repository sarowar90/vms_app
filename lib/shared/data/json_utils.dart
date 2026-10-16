/// Helpers for PHP/PDO JSON, where numbers may arrive as strings
/// and dates as `YYYY-MM-DD HH:MM:SS` in server local time (Asia/Dhaka).
int? parseInt(Object? value) => value == null ? null : int.tryParse(value.toString());

DateTime? parseDateTime(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString().replaceFirst(' ', 'T'));

String? parseString(Object? value) {
  final s = value?.toString();
  return s == null || s.isEmpty ? null : s;
}
