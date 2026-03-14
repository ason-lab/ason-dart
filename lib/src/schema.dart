/// Schema descriptor for ASON struct serialization.
///
/// Implement this on your data classes to enable schema-driven encoding.
/// Fields are serialized positionally — order must match [fieldNames].
abstract class AsonSchema {
  /// Field names in declaration order.
  List<String> get fieldNames;

  /// Optional type annotations for typed output.
  /// Return null entries for fields without type info.
  List<String?> get fieldTypes;

  /// Serialize field values in order into the value list.
  /// Return a list of raw Dart values (int, double, bool, String, List, null, or nested AsonSchema).
  List<dynamic> get fieldValues;
}

/// Type annotations for ASON schema.
class AsonType {
  static const int_ = 'int';
  static const float_ = 'float';
  static const str_ = 'str';
  static const bool_ = 'bool';

  /// Get ASON type string for a Dart value.
  static String? fromValue(dynamic v) {
    if (v is bool) return bool_;
    if (v is int) return int_;
    if (v is double) return float_;
    if (v is String) return str_;
    if (v is List) {
      if (v.isEmpty) return null;
      final inner = fromValue(v.first);
      return inner != null ? '[$inner]' : null;
    }
    return null;
  }
}
