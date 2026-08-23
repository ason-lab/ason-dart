import 'error.dart';
import 'schema.dart';

const _kSpecial = <int>{
  0x20, // space
  0x2C, // ,
  0x40, // @
  0x28, // (
  0x29, // )
  0x5B, // [
  0x5D, // ]
  0x7B, // {
  0x7D, // }
  0x3A, // :
  0x3C, // <
  0x3E, // >
  0x2F, // /
  0x2A, // *
  0x22, // "
  0x5C, // \
  0x0A, // \n
  0x0D, // \r
  0x09, // \t
};

/// Encode a value to compact ASUN string (unannotated schema).
String encode(dynamic value) {
  final buf = StringBuffer();
  if (value is AsunSchema) {
    _encodeStruct(buf, value, false);
  } else if (value is List) {
    _encodeTopList(buf, value, false);
  } else if (value is Map) {
    throw AsunError.unsupportedMap;
  } else {
    _encodeValue(buf, value);
  }
  return buf.toString();
}

/// Encode a value to ASUN string with type-annotated schema.
String encodeTyped(dynamic value) {
  final buf = StringBuffer();
  if (value is AsunSchema) {
    _encodeStruct(buf, value, true);
  } else if (value is List) {
    _encodeTopList(buf, value, true);
  } else if (value is Map) {
    throw AsunError.unsupportedMap;
  } else {
    _encodeValue(buf, value);
  }
  return buf.toString();
}

void _encodeStruct(StringBuffer buf, AsunSchema obj, bool typed) {
  _writeSchema(buf, obj, typed);
  buf.write(':');
  _writeTuple(buf, obj.fieldValues);
}

void _writeSchema(StringBuffer buf, AsunSchema obj, bool typed) {
  final names = obj.fieldNames;
  final values = obj.fieldValues;
  final types = obj.fieldTypes;

  buf.write('{');
  for (int i = 0; i < names.length; i++) {
    if (i > 0) buf.write(',');
    final value = i < values.length ? values[i] : null;
    final declaredType = i < types.length ? types[i] : null;
    _writeFieldSchema(buf, names[i], value, declaredType, typed);
  }
  buf.write('}');
}

void _writeFieldSchema(
  StringBuffer buf,
  String name,
  dynamic value,
  String? declaredType,
  bool typed,
) {
  _writeSchemaFieldName(buf, name);

  if (value is Map) throw AsunError.unsupportedMap;

  if (value is AsunSchema) {
    buf.write('@');
    _writeSchema(buf, value, typed);
    return;
  }

  if (value is List) {
    _writeArrayTypeHeader(buf, value, declaredType, typed);
    return;
  }

  if (declaredType != null && _isStructuralType(declaredType)) {
    _writeDeclaredTypeHeader(buf, declaredType, typed);
    return;
  }

  if (typed) {
    final t = declaredType ?? _inferScalarType(value);
    if (t != null) {
      buf.write('@');
      buf.write(t);
    }
  }
}

bool _schemaFieldNameNeedsQuoting(String name) {
  if (name.isEmpty) return true;
  if (name == 'true' || name == 'false') return true;
  if (name.startsWith(' ') || name.endsWith(' ')) return true;
  bool couldBeNumber = true;
  final numStart = name.startsWith('-') ? 1 : 0;
  if (numStart >= name.length) couldBeNumber = false;
  for (int i = 0; i < name.length; i++) {
    final c = name.codeUnitAt(i);
    if (c <= 0x20 ||
        c == 0x2C ||
        c == 0x40 ||
        c == 0x3A ||
        c == 0x7B ||
        c == 0x7D ||
        c == 0x5B ||
        c == 0x5D ||
        c == 0x28 ||
        c == 0x29 ||
        c == 0x22 ||
        c == 0x5C) {
      return true;
    }
    if (couldBeNumber &&
        i >= numStart &&
        !((c >= 0x30 && c <= 0x39) || c == 0x2E)) {
      couldBeNumber = false;
    }
  }
  return couldBeNumber && name.length > numStart;
}

void _writeSchemaFieldName(StringBuffer buf, String name) {
  if (_schemaFieldNameNeedsQuoting(name)) {
    buf.write('"');
    final units = name.codeUnits;
    for (int i = 0; i < units.length; i++) {
      final c = units[i];
      switch (c) {
        case 0x22:
          buf.write(r'\"');
        case 0x5C:
          buf.write(r'\\');
        case 0x0A:
          buf.write(r'\n');
        case 0x0D:
          buf.write(r'\r');
        case 0x09:
          buf.write(r'\t');
        default:
          buf.writeCharCode(c);
      }
    }
    buf.write('"');
  } else {
    buf.write(name);
  }
}

void _writeArrayTypeHeader(
  StringBuffer buf,
  List list,
  String? declaredType,
  bool typed,
) {
  if (list.any((item) => item is Map)) throw AsunError.unsupportedMap;

  if (list.isNotEmpty && list.first is AsunSchema) {
    buf.write('@[');
    _writeSchema(buf, list.first as AsunSchema, typed);
    buf.write(']');
    return;
  }

  if (declaredType != null && _isStructuralType(declaredType)) {
    _writeDeclaredTypeHeader(buf, declaredType, typed);
    return;
  }

  buf.write('@[');
  if (typed) {
    final inner = list.isNotEmpty ? _inferScalarType(list.first) : null;
    if (inner != null) buf.write(inner);
  }
  buf.write(']');
}

void _writeDeclaredTypeHeader(
    StringBuffer buf, String declaredType, bool typed) {
  buf.write('@');
  if (typed) {
    buf.write(declaredType);
  } else {
    buf.write(_stripScalarAnnotations(declaredType));
  }
}

bool _isStructuralType(String type) =>
    type.startsWith('[') || type.startsWith('{');

String _stripScalarAnnotations(String type) {
  if (type.startsWith('[') && type.endsWith(']')) {
    final inner = type.substring(1, type.length - 1);
    if (inner.isEmpty) return '[]';
    if (inner.startsWith('{') || inner.startsWith('[')) {
      return '[${_stripScalarAnnotations(inner)}]';
    }
    return '[]';
  }

  final out = StringBuffer();
  int i = 0;
  while (i < type.length) {
    final ch = type.codeUnitAt(i);
    if (ch != 0x40) {
      out.writeCharCode(ch);
      i++;
      continue;
    }

    if (i + 1 < type.length) {
      final next = type.codeUnitAt(i + 1);
      if (next == 0x7B || next == 0x5B) {
        out.write('@');
        i++;
        continue;
      }
    }

    i++;
    while (i < type.length) {
      final c = type.codeUnitAt(i);
      if (c == 0x2C || c == 0x7D || c == 0x5D || c == 0x20 || c == 0x09) {
        break;
      }
      i++;
    }
  }
  return out.toString();
}

void _encodeTopList(StringBuffer buf, List list, bool typed) {
  if (list.any((item) => item is Map)) throw AsunError.unsupportedMap;

  if (list.isEmpty) {
    buf.write('[]');
    return;
  }

  final first = list.first;
  if (first is AsunSchema) {
    buf.write('[');
    _writeSchema(buf, first, typed);
    buf.write(']:');
    for (int i = 0; i < list.length; i++) {
      if (i > 0) buf.write(',');
      final obj = list[i] as AsunSchema;
      _writeTuple(buf, obj.fieldValues);
    }
    return;
  }

  buf.write('[');
  for (int i = 0; i < list.length; i++) {
    if (i > 0) buf.write(',');
    _encodeValue(buf, list[i]);
  }
  buf.write(']');
}

void _writeTuple(StringBuffer buf, List values) {
  buf.write('(');
  for (int i = 0; i < values.length; i++) {
    if (i > 0) buf.write(',');
    _encodeValue(buf, values[i]);
  }
  buf.write(')');
}

void _encodeValue(StringBuffer buf, dynamic v) {
  if (v == null) {
    // Untyped null: emit `()` (empty parens). The decoder accepts this as
    // null in any value position, including inside arrays.
    buf.write('()');
    return;
  }
  if (v is bool) {
    buf.write(v ? 'true' : 'false');
    return;
  }
  if (v is int) {
    buf.write(v.toString());
    return;
  }
  if (v is double) {
    _writeDouble(buf, v);
    return;
  }
  if (v is String) {
    _writeString(buf, v);
    return;
  }
  if (v is AsunSchema) {
    _writeTuple(buf, v.fieldValues);
    return;
  }
  if (v is List) {
    if (v.any((item) => item is Map)) throw AsunError.unsupportedMap;
    buf.write('[');
    for (int i = 0; i < v.length; i++) {
      if (i > 0) buf.write(',');
      final item = v[i];
      if (item is AsunSchema) {
        _writeTuple(buf, item.fieldValues);
      } else {
        _encodeValue(buf, item);
      }
    }
    buf.write(']');
    return;
  }
  if (v is Map) throw AsunError.unsupportedMap;
  _writeString(buf, v.toString());
}

bool _needsQuoting(String s) {
  if (s.isEmpty) return true;
  final units = s.codeUnits;
  // Leading/trailing ASCII whitespace forces quoting (SPEC §S2 trim).
  final first = units.first;
  final last = units.last;
  if (first == 0x20 || first == 0x09 || first == 0x0A || first == 0x0D) return true;
  if (last == 0x20 || last == 0x09 || last == 0x0A || last == 0x0D) return true;
  if (s == 'true' || s == 'false' || s == 'True' || s == 'False' || s == 'TRUE' || s == 'FALSE') {
    return true;
  }

  for (int i = 0; i < units.length; i++) {
    final c = units[i];
    if (c <= 0x1f || c == 0x7f) return true;
    if (_kSpecial.contains(c)) return true;
  }

  // Number-like prefix forces quoting: if the decoder would start parsing
  // this as a number, the string is ambiguous (e.g. "1.2.3", "123abc").
  final c0 = units[0];
  if (c0 >= 0x30 && c0 <= 0x39) return true; // leading digit
  if ((c0 == 0x2D || c0 == 0x2B) && units.length >= 2) {
    final c1 = units[1];
    if (c1 >= 0x30 && c1 <= 0x39) return true; // sign + digit
  }
  if (c0 == 0x2E && units.length >= 2) {
    final c1 = units[1];
    if (c1 >= 0x30 && c1 <= 0x39) return true; // .digit
  }

  return false;
}

void _writeString(StringBuffer buf, String s) {
  if (_needsQuoting(s)) {
    _writeEscaped(buf, s);
  } else {
    buf.write(s);
  }
}

void _writeEscaped(StringBuffer buf, String s) {
  buf.write('"');
  final units = s.codeUnits;
  for (int i = 0; i < units.length; i++) {
    final c = units[i];
    switch (c) {
      case 0x22:
        buf.write(r'\"');
      case 0x5C:
        buf.write(r'\\');
      case 0x0A:
        buf.write(r'\n');
      case 0x0D:
        buf.write(r'\r');
      case 0x09:
        buf.write(r'\t');
      case 0x08:
        buf.write(r'\b');
      case 0x0C:
        buf.write(r'\f');
      case 0x2C:
        buf.write(r'\,');
      case 0x28:
        buf.write(r'\(');
      case 0x29:
        buf.write(r'\)');
      case 0x5B:
        buf.write(r'\[');
      case 0x5D:
        buf.write(r'\]');
      default:
        if (c < 0x20 || c == 0x7F) {
          buf.write('\\u');
          buf.write(c.toRadixString(16).padLeft(4, '0'));
        } else {
          buf.writeCharCode(c);
        }
    }
  }
  buf.write('"');
}

void _writeDouble(StringBuffer buf, double v) {
  // Dart's double.toString() already produces the shortest representation that
  // round-trips (Grisu/Ryū) and preserves the sign of -0.0 ("-0.0"). The old
  // hand-rolled ×10/×100 fast paths broke shortest round-trip and the
  // integer-valued branch dropped the sign of -0.0 — both removed.
  final s = v.toString();
  buf.write(s);
  // Ensure a float always reads back as a float: append ".0" when toString()
  // produced a bare integer (no '.', exponent, or non-finite marker).
  if (v.isFinite &&
      !s.contains('.') &&
      !s.contains('e') &&
      !s.contains('E')) {
    buf.write('.0');
  }
}

String? _inferScalarType(dynamic v) {
  if (v == null) return null;
  if (v is bool) return 'bool';
  if (v is int) return 'int';
  if (v is double) return 'float';
  if (v is String) return 'str';
  return null;
}
