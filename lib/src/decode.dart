import 'error.dart';

// ---------------------------------------------------------------------------
// Schema cache — avoid re-parsing identical schema headers
// ---------------------------------------------------------------------------
final Map<int, List<String>> _schemaCache = {};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Decode an ASON text string into a structured Dart value.
dynamic decode(String input) {
  final d = _Decoder(input);
  d._skipWsAndComments();
  final result = d._parseTop();
  d._skipWsAndComments();
  if (d._pos < d._len) {
    for (int i = d._pos; i < d._len; i++) {
      final c = input.codeUnitAt(i);
      if (c != 0x20 && c != 0x09 && c != 0x0A && c != 0x0D) {
        throw AsonError.trailingCharacters;
      }
    }
  }
  return result;
}

/// Decode ASON text into a typed object using a field-bag factory function.
T decodeWith<T>(String input, T Function(Map<String, dynamic>) factory) {
  final raw = decode(input);
  if (raw is Map<String, dynamic>) {
    return factory(raw);
  }
  throw AsonError('expected struct, got ${raw.runtimeType}');
}

/// Decode ASON text into a list of typed objects.
List<T> decodeListWith<T>(
    String input, T Function(Map<String, dynamic>) factory) {
  final d = _Decoder(input);
  d._skipWsAndComments();
  if (d._pos >= d._len) throw AsonError('empty input');

  // Fast path: detect vec struct pattern [{...}]:
  final c = d._peek();
  if (c == 0x5B &&
      d._pos + 1 < d._len &&
      input.codeUnitAt(d._pos + 1) == 0x7B) {
    final maps = d._parseVecStruct();
    final result = <T>[];
    for (final m in maps) {
      result.add(factory(m as Map<String, dynamic>));
    }
    return result;
  }

  // Fallback
  final raw = d._parseTop();
  if (raw is List) {
    return raw.map((e) => factory(e as Map<String, dynamic>)).toList();
  }
  throw AsonError('expected list, got ${raw.runtimeType}');
}

// ---------------------------------------------------------------------------
// Internal decoder — optimized for small-dataset hot loops
// ---------------------------------------------------------------------------

class _Decoder {
  final String _input;
  final int _len;
  int _pos = 0;

  _Decoder(this._input) : _len = _input.length;

  // -- Peek / advance -------------------------------------------------------

  int _peek() {
    if (_pos >= _len) return -1;
    return _input.codeUnitAt(_pos);
  }

  int _next() {
    if (_pos >= _len) throw AsonError.eof;
    return _input.codeUnitAt(_pos++);
  }

  // -- Whitespace -----------------------------------------------------------

  void _skipWs() {
    while (_pos < _len) {
      final c = _input.codeUnitAt(_pos);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        _pos++;
      } else {
        break;
      }
    }
  }

  void _skipWsAndComments() {
    for (;;) {
      _skipWs();
      if (_pos + 1 < _len &&
          _input.codeUnitAt(_pos) == 0x2F &&
          _input.codeUnitAt(_pos + 1) == 0x2A) {
        _pos += 2;
        while (_pos + 1 < _len) {
          if (_input.codeUnitAt(_pos) == 0x2A &&
              _input.codeUnitAt(_pos + 1) == 0x2F) {
            _pos += 2;
            break;
          }
          _pos++;
        }
      } else {
        break;
      }
    }
  }

  // -- Top-level parse ------------------------------------------------------

  dynamic _parseTop() {
    _skipWs();
    if (_pos >= _len) return null;

    final c = _peek();
    // [{schema}]:(v1),(v2) — vec of structs
    if (c == 0x5B && _pos + 1 < _len && _input.codeUnitAt(_pos + 1) == 0x7B) {
      return _parseVecStruct();
    }
    // {schema}:(values) — single struct
    if (c == 0x7B) {
      return _parseSingleStruct();
    }
    // Plain value
    return _parseValueFast();
  }

  // -- Schema parsing with caching ------------------------------------------

  List<String> _parseSchema() {
    final schemaStart = _pos;
    if (_next() != 0x7B) throw AsonError.expectedOpenBrace;

    // Find end of schema to compute cache key
    int braceDepth = 1;
    int scanPos = _pos;
    while (scanPos < _len && braceDepth > 0) {
      final c = _input.codeUnitAt(scanPos);
      if (c == 0x7B)
        braceDepth++;
      else if (c == 0x7D) braceDepth--;
      scanPos++;
    }
    final hash = _input.substring(schemaStart, scanPos).hashCode;
    final cached = _schemaCache[hash];
    if (cached != null) {
      _pos = scanPos;
      return cached;
    }

    // Parse schema fields normally
    _pos = schemaStart + 1; // back to after '{'
    final fields = <String>[];
    for (;;) {
      _skipWs();
      if (_peek() == 0x7D) {
        _pos++;
        break;
      }
      if (fields.isNotEmpty) {
        if (_next() != 0x2C) throw AsonError.expectedComma;
        _skipWs();
      }
      final name = _peek() == 0x22 ? _parseQuotedString() : _parseSchemaBareName();
      _skipWs();

      // Validate and skip optional @type annotation or structural scaffold.
      if (_pos < _len && _input.codeUnitAt(_pos) == 0x40) {
        _pos++;
        _skipWs();
        _validateSchemaAnnotation();
      }
      fields.add(name);
    }
    _schemaCache[hash] = fields;
    return fields;
  }

  void _validateSchemaAnnotation() {
    if (_pos >= _len) {
      throw AsonError("expected schema type after '@'");
    }
    final tc = _input.codeUnitAt(_pos);
    if (tc == 0x7B) {
      _parseSchema();
      return;
    }
    if (tc == 0x5B) {
      _pos++;
      _skipWs();
      if (_pos < _len && _input.codeUnitAt(_pos) == 0x5D) {
        _pos++;
        return;
      }
      if (_pos < _len && _input.codeUnitAt(_pos) == 0x7B) {
        _parseSchema();
      } else {
        _validateSchemaScalarType();
      }
      _skipWs();
      if (_pos >= _len || _input.codeUnitAt(_pos) != 0x5D) {
        throw AsonError("expected ']' in array type annotation");
      }
      _pos++;
      return;
    }
    _validateSchemaScalarType();
  }

  void _validateSchemaScalarType() {
    final start = _pos;
    while (_pos < _len) {
      final c = _input.codeUnitAt(_pos);
      if (c == 0x2C || c == 0x7D || c == 0x5D || c == 0x20 || c == 0x09) {
        break;
      }
      _pos++;
    }
    if (start == _pos) {
      throw AsonError("expected schema type after '@'");
    }
    var token = _input.substring(start, _pos);
    if (token.endsWith('?')) token = token.substring(0, token.length - 1);
    if (token == 'int' || token == 'str' || token == 'float' || token == 'bool') {
      return;
    }
    throw AsonError("unsupported schema type '$token'; use int, str, float, or bool");
  }

  String _parseSchemaBareName() {
    final start = _pos;
    while (_pos < _len) {
      final c = _input.codeUnitAt(_pos);
      if (c == 0x2C || c == 0x7D || c == 0x40 || c == 0x20 || c == 0x09) {
        break;
      }
      _pos++;
    }
    return _input.substring(start, _pos);
  }

  void _skipBalanced(int open, int close) {
    int depth = 0;
    while (_pos < _len) {
      final c = _input.codeUnitAt(_pos);
      _pos++;
      if (c == open) {
        depth++;
      } else if (c == close) {
        depth--;
        if (depth == 0) return;
      }
    }
    throw AsonError.eof;
  }

  // -- Struct parsing -------------------------------------------------------

  Map<String, dynamic> _parseSingleStruct() {
    final fields = _parseSchema();
    _skipWsAndComments();
    if (_next() != 0x3A) throw AsonError.expectedColon;
    _skipWs();
    return _parseTupleAsMap(fields);
  }

  List<dynamic> _parseVecStruct() {
    _pos++; // skip [
    final fields = _parseSchema();
    _skipWs();
    if (_next() != 0x5D) throw AsonError.expectedCloseBracket;
    _skipWs();
    if (_next() != 0x3A) throw AsonError.expectedColon;

    final result = <Map<String, dynamic>>[];
    // Reuse a single map and copy into new maps to reduce allocation
    for (;;) {
      _skipWs();
      if (_pos >= _len) break;
      final c = _peek();
      if (c == 0x2C) {
        _pos++;
        _skipWs();
        if (_pos >= _len || _peek() != 0x28) break;
      }
      if (_peek() != 0x28) break;
      result.add(_parseTupleAsMap(fields));
    }
    return result;
  }

  Map<String, dynamic> _parseTupleAsMap(List<String> fields) {
    if (_next() != 0x28) throw AsonError.expectedOpenParen;
    final map = <String, dynamic>{};
    final fieldCount = fields.length;
    for (int i = 0; i < fieldCount; i++) {
      _skipWs();
      final c = _input.codeUnitAt(_pos);
      if (c == 0x29) break;
      if (i > 0) {
        if (c == 0x2C) {
          _pos++;
          _skipWs();
          if (_input.codeUnitAt(_pos) == 0x29) {
            map[fields[i]] = null;
            continue;
          }
        } else {
          break;
        }
      }
      map[fields[i]] = _parseValueFast();
    }
    _skipRemainingTuple();
    _skipWs();
    if (_pos < _len && _input.codeUnitAt(_pos) == 0x29) _pos++;
    return map;
  }

  void _skipRemainingTuple() {
    _skipWs();
    while (_pos < _len && _input.codeUnitAt(_pos) != 0x29) {
      if (_input.codeUnitAt(_pos) == 0x2C) {
        _pos++;
        _skipWs();
        if (_pos < _len && _input.codeUnitAt(_pos) == 0x29) break;
      }
      if (_pos < _len && _input.codeUnitAt(_pos) != 0x29) {
        _skipValue();
        _skipWs();
      }
    }
  }

  void _skipValue() {
    if (_pos >= _len) return;
    final c = _input.codeUnitAt(_pos);
    switch (c) {
      case 0x28:
        _skipBalanced(0x28, 0x29);
      case 0x5B:
        _skipBalanced(0x5B, 0x5D);
      case 0x3C:
        throw AsonError.unsupportedMap;
      case 0x22:
        _pos++;
        while (_pos < _len) {
          final ch = _input.codeUnitAt(_pos);
          if (ch == 0x5C) {
            _pos += 2;
          } else if (ch == 0x22) {
            _pos++;
            return;
          } else {
            _pos++;
          }
        }
        throw AsonError.unclosedString;
      default:
        while (_pos < _len) {
          final ch = _input.codeUnitAt(_pos);
          if (ch == 0x2C || ch == 0x29 || ch == 0x5D) break;
          _pos++;
        }
    }
  }

  // -- Value parsing — optimized branch order for typical ASON data ----------

  dynamic _parseValueFast() {
    if (_pos >= _len) return null;

    final c = _input.codeUnitAt(_pos);

    // Null — at delimiter
    if (c == 0x2C || c == 0x29 || c == 0x5D) return null;

    // Number first (most common in ASON structured data)
    if ((c >= 0x30 && c <= 0x39) || c == 0x2D) return _parseNumber();

    // Quoted string
    if (c == 0x22) return _parseQuotedString();

    // Bool — inline char checks, no substring
    if (c == 0x74 && _pos + 3 < _len) {
      if (_input.codeUnitAt(_pos + 1) == 0x72 &&
          _input.codeUnitAt(_pos + 2) == 0x75 &&
          _input.codeUnitAt(_pos + 3) == 0x65) {
        if (_pos + 4 >= _len || _isDelimiter(_input.codeUnitAt(_pos + 4))) {
          _pos += 4;
          return true;
        }
      }
    }
    if (c == 0x66 && _pos + 4 < _len) {
      if (_input.codeUnitAt(_pos + 1) == 0x61 &&
          _input.codeUnitAt(_pos + 2) == 0x6C &&
          _input.codeUnitAt(_pos + 3) == 0x73 &&
          _input.codeUnitAt(_pos + 4) == 0x65) {
        if (_pos + 5 >= _len || _isDelimiter(_input.codeUnitAt(_pos + 5))) {
          _pos += 5;
          return false;
        }
      }
    }

    // Nested tuple
    if (c == 0x28) return _parseTupleValue();

    // Array
    if (c == 0x5B) return _parseArray();

    // Schema-prefixed nested struct
    if (c == 0x7B) return _parseSingleStruct();

    if (c == 0x3C) throw AsonError.unsupportedMap;

    // Plain string value
    return _parsePlainValue();
  }

  bool _isDelimiter(int c) =>
      c == 0x2C ||
      c == 0x29 ||
      c == 0x5D ||
      c == 0x20 ||
      c == 0x09 ||
      c == 0x0A ||
      c == 0x0D;

  // -- Number parsing — direct, no intermediate string ----------------------

  dynamic _parseNumber() {
    final start = _pos;
    bool negative = false;
    if (_input.codeUnitAt(_pos) == 0x2D) {
      negative = true;
      _pos++;
    }

    int intVal = 0;
    int digits = 0;
    while (_pos < _len) {
      final d = _input.codeUnitAt(_pos) - 0x30;
      if (d < 0 || d > 9) break;
      intVal = intVal * 10 + d;
      _pos++;
      digits++;
    }
    if (digits == 0) throw AsonError.invalidNumber;

    if (_pos < _len && _input.codeUnitAt(_pos) == 0x2E) {
      _pos = start;
      return _parseFloat();
    }

    if (_pos < _len) {
      final e = _input.codeUnitAt(_pos);
      if (e == 0x65 || e == 0x45) {
        _pos = start;
        return _parseFloat();
      }
    }

    return negative ? -intVal : intVal;
  }

  double _parseFloat() {
    final start = _pos;
    if (_pos < _len && _input.codeUnitAt(_pos) == 0x2D) _pos++;
    while (_pos < _len &&
        _input.codeUnitAt(_pos) >= 0x30 &&
        _input.codeUnitAt(_pos) <= 0x39) {
      _pos++;
    }
    if (_pos < _len && _input.codeUnitAt(_pos) == 0x2E) {
      _pos++;
      while (_pos < _len &&
          _input.codeUnitAt(_pos) >= 0x30 &&
          _input.codeUnitAt(_pos) <= 0x39) {
        _pos++;
      }
    }
    if (_pos < _len) {
      final e = _input.codeUnitAt(_pos);
      if (e == 0x65 || e == 0x45) {
        _pos++;
        if (_pos < _len) {
          final s = _input.codeUnitAt(_pos);
          if (s == 0x2B || s == 0x2D) _pos++;
        }
        while (_pos < _len &&
            _input.codeUnitAt(_pos) >= 0x30 &&
            _input.codeUnitAt(_pos) <= 0x39) {
          _pos++;
        }
      }
    }
    final s = _input.substring(start, _pos);
    return double.parse(s);
  }

  // -- String parsing -------------------------------------------------------

  String _parseQuotedString() {
    _pos++; // skip "
    final start = _pos;

    // Fast scan: look for " or \ without escapes
    int scan = _pos;
    while (scan < _len) {
      final c = _input.codeUnitAt(scan);
      if (c == 0x22) {
        // " — no escapes, zero-copy substring
        final result = _input.substring(start, scan);
        _pos = scan + 1;
        return result;
      }
      if (c == 0x5C) break; // \ — need slow path
      scan++;
    }

    // Slow path: build string with escapes
    final buf = StringBuffer();
    if (scan > start) {
      buf.write(_input.substring(start, scan));
    }
    _pos = scan;

    while (_pos < _len) {
      final c = _input.codeUnitAt(_pos);
      if (c == 0x22) {
        _pos++;
        return buf.toString();
      }
      if (c == 0x5C) {
        _pos++;
        if (_pos >= _len) throw AsonError.unclosedString;
        final esc = _input.codeUnitAt(_pos);
        _pos++;
        switch (esc) {
          case 0x22:
            buf.write('"');
          case 0x5C:
            buf.write(r'\');
          case 0x6E:
            buf.write('\n');
          case 0x74:
            buf.write('\t');
          case 0x72:
            buf.write('\r');
          case 0x2C:
            buf.write(',');
          case 0x28:
            buf.write('(');
          case 0x29:
            buf.write(')');
          case 0x5B:
            buf.write('[');
          case 0x5D:
            buf.write(']');
          case 0x75: // u — unicode escape
            if (_pos + 4 > _len) throw AsonError.invalidUnicodeEscape;
            final hex = _input.substring(_pos, _pos + 4);
            final cp = int.tryParse(hex, radix: 16);
            if (cp == null) throw AsonError.invalidUnicodeEscape;
            buf.writeCharCode(cp);
            _pos += 4;
          default:
            throw AsonError('invalid escape: \\${String.fromCharCode(esc)}');
        }
      } else {
        buf.writeCharCode(c);
        _pos++;
      }
    }
    throw AsonError.unclosedString;
  }

  String _parsePlainValue() {
    final start = _pos;
    while (_pos < _len) {
      final c = _input.codeUnitAt(_pos);
      if (c == 0x2C || c == 0x29 || c == 0x5D) break;
      if (c == 0x5C) {
        _pos += 2;
      } else {
        _pos++;
      }
    }
    final raw = _input.substring(start, _pos).trim();
    if (raw.contains(r'\')) {
      return _unescapePlain(raw);
    }
    return raw;
  }

  String _unescapePlain(String s) {
    final buf = StringBuffer();
    final units = s.codeUnits;
    int i = 0;
    while (i < units.length) {
      if (units[i] == 0x5C) {
        i++;
        if (i >= units.length) throw AsonError.eof;
        switch (units[i]) {
          case 0x2C:
            buf.write(',');
          case 0x28:
            buf.write('(');
          case 0x29:
            buf.write(')');
          case 0x5B:
            buf.write('[');
          case 0x5D:
            buf.write(']');
          case 0x22:
            buf.write('"');
          case 0x5C:
            buf.write(r'\');
          case 0x6E:
            buf.write('\n');
          case 0x74:
            buf.write('\t');
          case 0x75: // u
            if (i + 4 >= units.length) throw AsonError.invalidUnicodeEscape;
            final hex = s.substring(i + 1, i + 5);
            final cp = int.tryParse(hex, radix: 16);
            if (cp == null) throw AsonError.invalidUnicodeEscape;
            buf.writeCharCode(cp);
            i += 4;
          default:
            throw AsonError(
                'invalid escape: \\${String.fromCharCode(units[i])}');
        }
      } else {
        buf.writeCharCode(units[i]);
      }
      i++;
    }
    return buf.toString();
  }

  // -- Array parsing --------------------------------------------------------

  dynamic _parseArray() {
    _pos++; // skip [
    _skipWs();
    if (_pos < _len && _input.codeUnitAt(_pos) == 0x5D) {
      _pos++;
      return <dynamic>[];
    }

    final items = <dynamic>[];
    bool first = true;
    while (_pos < _len) {
      _skipWs();
      if (_peek() == 0x5D) {
        _pos++;
        return items;
      }
      if (!first) {
        if (_input.codeUnitAt(_pos) == 0x2C) {
          _pos++;
          _skipWs();
          if (_pos < _len && _input.codeUnitAt(_pos) == 0x5D) {
            _pos++;
            return items;
          }
        } else {
          break;
        }
      }
      first = false;
      items.add(_parseValueFast());
    }
    _skipWs();
    if (_pos < _len && _input.codeUnitAt(_pos) == 0x5D) _pos++;
    return items;
  }

  // -- Tuple value ----------------------------------------------------------

  dynamic _parseTupleValue() {
    _pos++; // skip (
    final items = <dynamic>[];
    bool first = true;
    while (_pos < _len) {
      _skipWs();
      if (_peek() == 0x29) {
        _pos++;
        break;
      }
      if (!first) {
        if (_input.codeUnitAt(_pos) == 0x2C) {
          _pos++;
          _skipWs();
          if (_peek() == 0x29) {
            _pos++;
            break;
          }
        } else {
          break;
        }
      }
      first = false;
      items.add(_parseValueFast());
    }
    return items;
  }
}
