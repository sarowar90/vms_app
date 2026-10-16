/// Client-side checks matching `external_api/core/Validator.php`.
/// The server validates again; these only give faster feedback.
abstract final class Validators {
  /// Digits only, with a leading `88` country code removed.
  static String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.startsWith('880') ? digits.substring(2) : digits;
  }

  static bool isBdPhone(String phone) => RegExp(r'^01[3-9]\d{8}$').hasMatch(normalizePhone(phone));

  static String? required(String? v, [String label = 'This field']) =>
      v == null || v.trim().isEmpty ? '$label is required' : null;

  static String? bdPhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Mobile number is required';
    return isBdPhone(v) ? null : 'Enter a valid mobile number (01XXXXXXXXX)';
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Enter a valid email';
  }
}
