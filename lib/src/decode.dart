import 'error.dart';

// ---------------------------------------------------------------------------
// Schema cache — avoid re-parsing identical schema headers
// ---------------------------------------------------------------------------
// Keyed by the *original* schema substring itself, so a cache hit is an exact
// string match (no hashCode-collision poisoning). Bounded to avoid unbounded
// growth from untrusted input; cleared wholesale when the cap is reached.
final Map<String, List<String>> _schemaCache = {};
const int _maxCachedSchemas = 512;

// Maximum structural nesting depth. Untrusted input with deeper nesting is
// rejected before it can overflow the native stack.
const int _maxDepth = 128;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Decode an ASUN text string into a structured Dart value.
dynamic decode(String input) {
  final d = _Decoder(input);
  d._skipWsAndComments();
  final result = d._parseTop();
  d._skipWsAndComments();
  if (d._pos < d._len) {
    for (int i = d._pos; i < d._len; i++) {
      final c = input.codeUnitAt(i);
      if (c != 0x20 && c != 0x09 && c != 0x0A && c != 0x0D) {
        throw AsunError.trailingCharacters;
      }
    }
  }
  return result;
}

/// Decode ASUN text into a typed object using a field-bag factory function.
T decodeWith<T>(String input, T Function(Map<String, dynamic>) factory) {
  final raw = decode(input);
  if (raw is Map<String, dynamic>) {
    return factory(raw);
  }
  throw AsunError('expected struct, got ${raw.runtimeType}');
}

/// Decode ASUN text into a list of typed objects.
List<T> decodeListWith<T>(
    String input, T Function(Map<String, dynamic>) factory) {
  final d = _Decoder(input);
  d._skipWsAndComments();
  if (d._pos >= d._len) throw AsunError('empty input');

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
  throw AsunError('expected list, got ${raw.runtimeType}');
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
    if (_pos >= _len) throw AsunError.eof;
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
      return _parseSingleStruct(0);
    }
    // SPEC §8.3: bare `(...)` at top level is forbidden — tuples may only
    // follow a schema header. Exception: `()` is the untyped null marker.
    if (c == 0x28) {
      if (_pos + 1 < _len && _input.codeUnitAt(_pos + 1) == 0x29) {
        _pos += 2;
        return null;
      }
      throw AsunError('bare tuple at top level — schema required');
    }
    // Plain value
    return _parseValueFast(0);
  }

  // -- Schema parsing with caching ------------------------------------------

  List<String> _parseSchema(int depth) {
    if (depth > _maxDepth) throw AsunError.maxDepthExceeded;
    final schemaStart = _pos;
    if (_next() != 0x7B) throw AsunError.expectedOpenBrace;

    // Find end of schema. Scan is quote/escape-aware so a '}' inside a quoted
    // field name does not prematurely terminate the schema (P0-1).
    int braceDepth = 1;
    int scanPos = _pos;
    bool inString = false;
    while (scanPos < _len && braceDepth > 0) {
      final c = _input.codeUnitAt(scanPos);
      if (inString) {
        if (c == 0x5C) {
          scanPos++; // skip escaped char
        } else if (c == 0x22) {
          inString = false;
        }
      } else if (c == 0x22) {
        inString = true;
      } else if (c == 0x7B) {
        braceDepth++;
      } else if (c == 0x7D) {
        braceDepth--;
      }
      scanPos++;
    }
    // Cache key is the original schema substring itself — a hit is therefore an
    // exact string match, immune to hashCode collisions (P0-1).
    final key = _input.substring(schemaStart, scanPos);
    final cached = _schemaCache[key];
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
        if (_next() != 0x2C) throw AsunError.expectedComma;
        _skipWs();
      }
      final name = _peek() == 0x22 ? _parseQuotedString() : _parseSchemaBareName();
      _skipWs();

      // Validate and skip optional @type annotation or structural scaffold.
      if (_pos < _len && _input.codeUnitAt(_pos) == 0x40) {
        _pos++;
        _skipWs();
        _validateSchemaAnnotation(depth + 1);
      }
      fields.add(name);
    }
    // Bounded insert: clear wholesale at the cap (P1-6).
    if (_schemaCache.length >= _maxCachedSchemas) _schemaCache.clear();
    _schemaCache[key] = fields;
    return fields;
  }

  void _validateSchemaAnnotation(int depth) {
    if (depth > _maxDepth) throw AsunError.maxDepthExceeded;
    if (_pos >= _len) {
      throw AsunError("expected schema type after '@'");
    }
    final tc = _input.codeUnitAt(_pos);
    if (tc == 0x7B) {
      _parseSchema(depth + 1);
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
        _parseSchema(depth + 1);
      } else {
        _validateSchemaScalarType();
      }
      _skipWs();
      if (_pos >= _len || _input.codeUnitAt(_pos) != 0x5D) {
        throw AsunError("expected ']' in array type annotation");
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
      throw AsunError("expected schema type after '@'");
    }
    var token = _input.substring(start, _pos);
    if (token.endsWith('?')) token = token.substring(0, token.length - 1);
    if (token == 'int' || token == 'str' || token == 'float' || token == 'bool') {
      return;
    }
    throw AsunError("unsupported schema type '$token'; use int, str, float, or bool");
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
    throw AsunError.eof;
  }

  // -- Struct parsing -------------------------------------------------------

  Map<String, dynamic> _parseSingleStruct(int depth) {
    if (depth > _maxDepth) throw AsunError.maxDepthExceeded;
    final fields = _parseSchema(depth);
    _skipWsAndComments();
    if (_next() != 0x3A) throw AsunError.expectedColon;
    _skipWs();
    return _parseTupleAsMap(fields, depth);
  }

  List<dynamic> _parseVecStruct() {
    _pos++; // skip [
    final fields = _parseSchema(0);
    _skipWs();
    if (_next() != 0x5D) throw AsunError.expectedCloseBracket;
    _skipWs();
    if (_next() != 0x3A) throw AsunError.expectedColon;

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
      result.add(_parseTupleAsMap(fields, 0));
    }
    return result;
  }

  Map<String, dynamic> _parseTupleAsMap(List<String> fields, int depth) {
    if (depth > _maxDepth) throw AsunError.maxDepthExceeded;
    if (_next() != 0x28) throw AsunError.expectedOpenParen;
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
      map[fields[i]] = _parseValueFast(depth);
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
        throw AsunError.unsupportedMap;
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
        throw AsunError.unclosedString;
      default:
        while (_pos < _len) {
          final ch = _input.codeUnitAt(_pos);
          if (ch == 0x2C || ch == 0x29 || ch == 0x5D) break;
          _pos++;
        }
    }
  }

  // -- Value parsing — optimized branch order for typical ASUN data ----------

  dynamic _parseValueFast(int depth) {
    if (depth > _maxDepth) throw AsunError.maxDepthExceeded;
    if (_pos >= _len) return null;

    final c = _input.codeUnitAt(_pos);

    // Null — at delimiter
    if (c == 0x2C || c == 0x29 || c == 0x5D) return null;

    // Number first (most common in ASUN structured data)
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

    // `()` is the untyped null marker (matches dart/rust encoder convention).
    if (c == 0x28) {
      if (_pos + 1 < _len && _input.codeUnitAt(_pos + 1) == 0x29) {
        _pos += 2;
        return null;
      }
      return _parseTupleValue(depth + 1);
    }

    // Array
    if (c == 0x5B) return _parseArray(depth + 1);

    // Schema-prefixed nested struct
    if (c == 0x7B) return _parseSingleStruct(depth + 1);

    if (c == 0x3C) throw AsunError.unsupportedMap;

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
    if (digits == 0) {
      // No digits after '-' (e.g. "-foo", "- 5"). SPEC §8.7 / §8.1: this is
      // a plain string, not a number error.
      _pos = start;
      return _parsePlainValue();
    }

    if (_pos < _len && _input.codeUnitAt(_pos) == 0x2E) {
      _pos = start;
      try {
        return _parseFloat();
      } on FormatException {
        _pos = start;
        return _parsePlainValue();
      }
    }

    if (_pos < _len) {
      final e = _input.codeUnitAt(_pos);
      if (e == 0x65 || e == 0x45) {
        _pos = start;
        try {
          return _parseFloat();
        } on FormatException {
          _pos = start;
          return _parsePlainValue();
        }
      }
    }

    // SPEC §8.1: a value that doesn't terminate at a delimiter / EOF
    // (e.g. "123abc") is a plain string, not "trailing characters".
    if (_pos < _len && !_isDelimiter(_input.codeUnitAt(_pos))) {
      _pos = start;
      return _parsePlainValue();
    }

    return negative ? -intVal : intVal;
  }

  double _parseFloat() {
    final start = _pos;
    if (_pos < _len && _input.codeUnitAt(_pos) == 0x2D) _pos++;
    final intStart = _pos;
    while (_pos < _len &&
        _input.codeUnitAt(_pos) >= 0x30 &&
        _input.codeUnitAt(_pos) <= 0x39) {
      _pos++;
    }
    final intDigits = _pos - intStart;
    bool hasFracOrExp = false;
    // ABNF: fractional part requires ≥1 digit if '.' is present.
    if (_pos < _len && _input.codeUnitAt(_pos) == 0x2E) {
      final dot = _pos;
      _pos++;
      final fracStart = _pos;
      while (_pos < _len &&
          _input.codeUnitAt(_pos) >= 0x30 &&
          _input.codeUnitAt(_pos) <= 0x39) {
        _pos++;
      }
      if (_pos == fracStart) {
        _pos = dot; // "5." → not a number
      } else {
        hasFracOrExp = true;
      }
    }
    // ABNF: exponent requires ≥1 digit after optional sign.
    if (_pos < _len) {
      final e = _input.codeUnitAt(_pos);
      if (e == 0x65 || e == 0x45) {
        final mark = _pos;
        _pos++;
        if (_pos < _len) {
          final s = _input.codeUnitAt(_pos);
          if (s == 0x2B || s == 0x2D) _pos++;
        }
        final expStart = _pos;
        while (_pos < _len &&
            _input.codeUnitAt(_pos) >= 0x30 &&
            _input.codeUnitAt(_pos) <= 0x39) {
          _pos++;
        }
        if (_pos == expStart) {
          _pos = mark; // "1e" / "1e+" → not a number
        } else {
          hasFracOrExp = true;
        }
      }
    }
    // No integer digits, or no '.' / 'e' was actually consumed → not a float.
    // Throw an internal sentinel so the caller can fall back to plain-string.
    if (intDigits == 0 || !hasFracOrExp) {
      _pos = start;
      throw const FormatException('not a float');
    }
    final s = _input.substring(start, _pos);
    return double.parse(s);
  }

  // -- String parsing -------------------------------------------------------

  /// Decode exactly 4 hex digits starting at [at] in [src]; throws on a short
  /// or non-hex sequence.
  static int _decodeHex4(String src, int at) {
    if (at + 4 > src.length) throw AsunError.invalidUnicodeEscape;
    int cp = 0;
    for (int j = 0; j < 4; j++) {
      final h = src.codeUnitAt(at + j);
      int d;
      if (h >= 0x30 && h <= 0x39) {
        d = h - 0x30;
      } else if (h >= 0x61 && h <= 0x66) {
        d = 10 + h - 0x61;
      } else if (h >= 0x41 && h <= 0x46) {
        d = 10 + h - 0x41;
      } else {
        throw AsunError.invalidUnicodeEscape;
      }
      cp = (cp << 4) | d;
    }
    return cp;
  }

  /// Decode a `\uXXXX` escape (the `\u` already consumed, [at] pointing at the
  /// first hex digit) into a scalar code point, combining a UTF-16 surrogate
  /// pair `𐀀` when present. Returns (codePoint, hexUnitsConsumed):
  /// 4 for a lone BMP char, 10 for a combined surrogate pair. Lone/unpaired
  /// surrogates are rejected.
  static _UniEscape _decodeUnicodeEscape(String src, int at) {
    final hi = _decodeHex4(src, at);
    if (hi >= 0xD800 && hi <= 0xDBFF) {
      // High surrogate — must be followed by \uXXXX low surrogate.
      if (at + 6 + 4 > src.length ||
          src.codeUnitAt(at + 4) != 0x5C ||
          src.codeUnitAt(at + 5) != 0x75) {
        throw AsunError.invalidUnicodeEscape;
      }
      final lo = _decodeHex4(src, at + 6);
      if (lo < 0xDC00 || lo > 0xDFFF) throw AsunError.invalidUnicodeEscape;
      final cp = 0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00);
      return _UniEscape(cp, 10);
    }
    if (hi >= 0xDC00 && hi <= 0xDFFF) {
      // Lone low surrogate — invalid.
      throw AsunError.invalidUnicodeEscape;
    }
    return _UniEscape(hi, 4);
  }

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
        if (_pos >= _len) throw AsunError.unclosedString;
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
          case 0x62:
            buf.write('\b');
          case 0x66:
            buf.write('\f');
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
          case 0x75: // u — unicode escape (with surrogate-pair support)
            final u = _decodeUnicodeEscape(_input, _pos);
            buf.writeCharCode(u.codePoint);
            _pos += u.consumed;
          default:
            throw AsunError('invalid escape: \\${String.fromCharCode(esc)}');
        }
      } else {
        buf.writeCharCode(c);
        _pos++;
      }
    }
    throw AsunError.unclosedString;
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
    // Trim only ASCII whitespace (SPEC §S2). Do NOT use String.trim(), which
    // strips Unicode whitespace including U+FEFF BOM and would corrupt valid
    // string content.
    int s = start, e = _pos;
    while (s < e) {
      final c = _input.codeUnitAt(s);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        s++;
      } else {
        break;
      }
    }
    while (e > s) {
      final c = _input.codeUnitAt(e - 1);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        e--;
      } else {
        break;
      }
    }
    final raw = _input.substring(s, e);
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
        if (i >= units.length) throw AsunError.eof;
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
          case 0x72:
            buf.write('\r');
          case 0x62:
            buf.write('\b');
          case 0x66:
            buf.write('\f');
          case 0x75: // u (with surrogate-pair support)
            // units[i] is 'u'; hex begins at i+1.
            final u = _decodeUnicodeEscape(s, i + 1);
            buf.writeCharCode(u.codePoint);
            i += u.consumed;
          default:
            throw AsunError(
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

  dynamic _parseArray(int depth) {
    if (depth > _maxDepth) throw AsunError.maxDepthExceeded;
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
      items.add(_parseValueFast(depth));
    }
    _skipWs();
    if (_pos < _len && _input.codeUnitAt(_pos) == 0x5D) _pos++;
    return items;
  }

  // -- Tuple value ----------------------------------------------------------

  dynamic _parseTupleValue(int depth) {
    if (depth > _maxDepth) throw AsunError.maxDepthExceeded;
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
      items.add(_parseValueFast(depth));
    }
    return items;
  }
}

/// Result of decoding a `\uXXXX` escape: the scalar [codePoint] and how many
/// hex-sequence code units were consumed (4 for BMP, 10 for a surrogate pair).
class _UniEscape {
  final int codePoint;
  final int consumed;
  const _UniEscape(this.codePoint, this.consumed);
}
