import 'error.dart';
import 'schema.dart';

const _kSpecial = <int>{
  0x2C, // ,
  0x28, // (
  0x29, // )
  0x5B, // [
  0x5D, // ]
  0x7B, // {
  0x7D, // }
  0x3A, // :
  0x22, // "
  0x5C, // \
  0x0A, // \n
  0x0D, // \r
  0x09, // \t
};

/// Encode a value to compact ASON string (unannotated schema).
String encode(dynamic value) {
  final buf = StringBuffer();
  if (value is AsonSchema) {
    _encodeStruct(buf, value, false);
  } else if (value is List) {
    _encodeTopList(buf, value, false);
  } else if (value is Map) {
    throw AsonError.unsupportedMap;
  } else {
    _encodeValue(buf, value);
  }
  return buf.toString();
}

/// Encode a value to ASON string with type-annotated schema.
String encodeTyped(dynamic value) {
  final buf = StringBuffer();
  if (value is AsonSchema) {
    _encodeStruct(buf, value, true);
  } else if (value is List) {
    _encodeTopList(buf, value, true);
  } else if (value is Map) {
    throw AsonError.unsupportedMap;
  } else {
    _encodeValue(buf, value);
  }
  return buf.toString();
}

void _encodeStruct(StringBuffer buf, AsonSchema obj, bool typed) {
  _writeSchema(buf, obj, typed);
  buf.write(':');
  _writeTuple(buf, obj.fieldValues);
}

void _writeSchema(StringBuffer buf, AsonSchema obj, bool typed) {
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
  buf.write(name);

  if (value is Map) throw AsonError.unsupportedMap;

  if (value is AsonSchema) {
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

void _writeArrayTypeHeader(
  StringBuffer buf,
  List list,
  String? declaredType,
  bool typed,
) {
  if (list.any((item) => item is Map)) throw AsonError.unsupportedMap;

  if (list.isNotEmpty && list.first is AsonSchema) {
    buf.write('@[');
    _writeSchema(buf, list.first as AsonSchema, typed);
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
  if (list.any((item) => item is Map)) throw AsonError.unsupportedMap;

  if (list.isEmpty) {
    buf.write('[]');
    return;
  }

  final first = list.first;
  if (first is AsonSchema) {
    buf.write('[');
    _writeSchema(buf, first, typed);
    buf.write(']:');
    for (int i = 0; i < list.length; i++) {
      if (i > 0) buf.write(',');
      final obj = list[i] as AsonSchema;
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
  if (v == null) return;
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
  if (v is AsonSchema) {
    _writeTuple(buf, v.fieldValues);
    return;
  }
  if (v is List) {
    if (v.any((item) => item is Map)) throw AsonError.unsupportedMap;
    buf.write('[');
    for (int i = 0; i < v.length; i++) {
      if (i > 0) buf.write(',');
      final item = v[i];
      if (item is AsonSchema) {
        _writeTuple(buf, item.fieldValues);
      } else {
        _encodeValue(buf, item);
      }
    }
    buf.write(']');
    return;
  }
  if (v is Map) throw AsonError.unsupportedMap;
  _writeString(buf, v.toString());
}

bool _needsQuoting(String s) {
  if (s.isEmpty) return true;
  final units = s.codeUnits;
  if (units.first == 0x20 || units.last == 0x20) return true;
  if (s == 'true' || s == 'false') return true;

  for (int i = 0; i < units.length; i++) {
    if (_kSpecial.contains(units[i])) return true;
  }

  int start = 0;
  if (units.isNotEmpty && units[0] == 0x2D) start = 1;
  if (start < units.length) {
    bool couldBeNumber = true;
    for (int i = start; i < units.length; i++) {
      final c = units[i];
      if (!((c >= 0x30 && c <= 0x39) || c == 0x2E)) {
        couldBeNumber = false;
        break;
      }
    }
    if (couldBeNumber) return true;
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
        buf.writeCharCode(c);
    }
  }
  buf.write('"');
}

void _writeDouble(StringBuffer buf, double v) {
  if (v.isFinite && v == v.truncateToDouble()) {
    buf.write(v.toInt().toString());
    buf.write('.0');
    return;
  }
  if (v.isFinite) {
    final v10 = v * 10;
    if (v10 == v10.truncateToDouble() && v10.abs() < 1e15) {
      final vi = v10.toInt();
      final intPart = vi.abs() ~/ 10;
      final frac = vi.abs() % 10;
      if (vi < 0) buf.write('-');
      buf.write(intPart.toString());
      buf.write('.');
      buf.write(frac.toString());
      return;
    }
    final v100 = v * 100;
    if (v100 == v100.truncateToDouble() && v100.abs() < 1e15) {
      final vi = v100.toInt();
      final intPart = vi.abs() ~/ 100;
      final frac = vi.abs() % 100;
      if (vi < 0) buf.write('-');
      buf.write(intPart.toString());
      buf.write('.');
      if (frac < 10) buf.write('0');
      final d1 = frac ~/ 10;
      final d2 = frac % 10;
      buf.write(d1.toString());
      if (d2 != 0) buf.write(d2.toString());
      return;
    }
  }
  buf.write(v.toString());
}

String? _inferScalarType(dynamic v) {
  if (v == null) return null;
  if (v is bool) return 'bool';
  if (v is int) return 'int';
  if (v is double) return 'float';
  if (v is String) return 'str';
  return null;
}
