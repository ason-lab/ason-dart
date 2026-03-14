import 'encode.dart';

const _kMaxWidth = 100;

/// Encode a value to pretty-formatted ASON string (unannotated).
String encodePretty(dynamic value) {
  final compact = encode(value);
  return prettyFormat(compact);
}

/// Encode a value to pretty-formatted ASON string with type annotations.
String encodePrettyTyped(dynamic value) {
  final compact = encodeTyped(value);
  return prettyFormat(compact);
}

/// Reformat compact ASON string with smart indentation.
///
/// Simple structures stay inline:
///   {name@str, age@int}:(Alice, 30)
///
/// Complex structures expand with 2-space indentation.
String prettyFormat(String src) {
  if (src.isEmpty) return '';
  final mat = _buildMatchTable(src);
  final f = _PrettyFmt(src, mat);
  f._writeTop();
  return f._out.toString();
}

// ---------------------------------------------------------------------------
// Match table: maps open brackets to their closing counterparts
// ---------------------------------------------------------------------------

List<int> _buildMatchTable(String src) {
  final n = src.length;
  final mat = List.filled(n, -1);
  final stack = <int>[];
  bool inQuote = false;
  int i = 0;
  while (i < n) {
    final c = src.codeUnitAt(i);
    if (inQuote) {
      if (c == 0x5C && i + 1 < n) {
        i += 2;
        continue;
      }
      if (c == 0x22) inQuote = false;
      i++;
      continue;
    }
    switch (c) {
      case 0x22:
        inQuote = true;
      case 0x7B: // {
      case 0x28: // (
      case 0x5B: // [
        stack.add(i);
      case 0x7D: // }
      case 0x29: // )
      case 0x5D: // ]
        if (stack.isNotEmpty) {
          final j = stack.removeLast();
          mat[j] = i;
          mat[i] = j;
        }
    }
    i++;
  }
  return mat;
}

// ---------------------------------------------------------------------------
// Pretty formatter
// ---------------------------------------------------------------------------

class _PrettyFmt {
  final String _src;
  final List<int> _mat;
  final StringBuffer _out = StringBuffer();
  int _pos = 0;
  int _depth = 0;

  _PrettyFmt(this._src, this._mat);

  int get _len => _src.length;

  void _writeTop() {
    if (_pos >= _len) return;
    final c = _src.codeUnitAt(_pos);
    if (c == 0x5B && _pos + 1 < _len && _src.codeUnitAt(_pos + 1) == 0x7B) {
      _writeArrayTop();
    } else if (c == 0x7B) {
      _writeObjectTop();
    } else {
      _out.write(_src.substring(_pos));
    }
  }

  void _writeObjectTop() {
    _writeGroup();
    if (_pos < _len && _src.codeUnitAt(_pos) == 0x3A) {
      // :
      _out.write(':');
      _pos++;
      if (_pos < _len) {
        final close = _mat[_pos];
        if (close >= 0 && close - _pos + 1 <= _kMaxWidth) {
          _writeInline(_pos, close + 1);
          _pos = close + 1;
        } else {
          _out.write('\n');
          _depth++;
          _writeIndent();
          _writeGroup();
          _depth--;
        }
      }
    }
  }

  void _writeArrayTop() {
    _out.write('[');
    _pos++;
    _writeGroup();
    if (_pos < _len && _src.codeUnitAt(_pos) == 0x5D) {
      _out.write(']');
      _pos++;
    }
    if (_pos < _len && _src.codeUnitAt(_pos) == 0x3A) {
      _out.write(':\n');
      _pos++;
    }

    _depth++;
    bool first = true;
    while (_pos < _len) {
      if (_src.codeUnitAt(_pos) == 0x2C) _pos++;
      if (_pos >= _len) break;
      if (!first) _out.write(',\n');
      first = false;
      _writeIndent();
      _writeGroup();
    }
    _out.write('\n');
    _depth--;
  }

  void _writeGroup() {
    if (_pos >= _len) return;
    final ch = _src.codeUnitAt(_pos);
    if (ch != 0x7B && ch != 0x28 && ch != 0x5B) {
      _writeValue();
      return;
    }

    // [{...}] array schema — fuse
    if (ch == 0x5B && _pos + 1 < _len && _src.codeUnitAt(_pos + 1) == 0x7B) {
      final closeBrace = _mat[_pos + 1];
      final closeBracket = _mat[_pos];
      if (closeBrace >= 0 &&
          closeBracket >= 0 &&
          closeBrace + 1 == closeBracket) {
        final width = closeBracket - _pos + 1;
        if (width <= _kMaxWidth) {
          _writeInline(_pos, closeBracket + 1);
          _pos = closeBracket + 1;
          return;
        }
        _out.write('[');
        _pos++;
        _writeGroup();
        _out.write(']');
        _pos++;
        return;
      }
    }

    final closePos = _mat[_pos];
    if (closePos < 0) {
      _out.writeCharCode(ch);
      _pos++;
      return;
    }
    final width = closePos - _pos + 1;
    if (width <= _kMaxWidth) {
      _writeInline(_pos, closePos + 1);
      _pos = closePos + 1;
      return;
    }

    // Expanded form
    final closeCh = _src.codeUnitAt(closePos);
    _out.writeCharCode(ch);
    _pos++;

    if (_pos >= closePos) {
      _out.writeCharCode(closeCh);
      _pos = closePos + 1;
      return;
    }

    _out.write('\n');
    _depth++;

    bool first = true;
    while (_pos < closePos) {
      if (_src.codeUnitAt(_pos) == 0x2C) _pos++;
      if (!first) _out.write(',\n');
      first = false;
      _writeIndent();
      _writeElement(closePos);
    }

    _out.write('\n');
    _depth--;
    _writeIndent();
    _out.writeCharCode(closeCh);
    _pos = closePos + 1;
  }

  void _writeElement(int boundary) {
    while (_pos < boundary && _src.codeUnitAt(_pos) != 0x2C) {
      final ch = _src.codeUnitAt(_pos);
      if (ch == 0x7B || ch == 0x28 || ch == 0x5B) {
        _writeGroup();
      } else if (ch == 0x22) {
        _writeQuoted();
      } else {
        _out.writeCharCode(ch);
        _pos++;
      }
    }
  }

  void _writeValue() {
    while (_pos < _len) {
      final ch = _src.codeUnitAt(_pos);
      if (ch == 0x2C || ch == 0x29 || ch == 0x7D || ch == 0x5D) break;
      if (ch == 0x22) {
        _writeQuoted();
      } else {
        _out.writeCharCode(ch);
        _pos++;
      }
    }
  }

  void _writeQuoted() {
    _out.write('"');
    _pos++;
    while (_pos < _len) {
      final ch = _src.codeUnitAt(_pos);
      _out.writeCharCode(ch);
      _pos++;
      if (ch == 0x5C && _pos < _len) {
        _out.writeCharCode(_src.codeUnitAt(_pos));
        _pos++;
      } else if (ch == 0x22) {
        break;
      }
    }
  }

  void _writeInline(int start, int end) {
    int depth = 0;
    bool inQuote = false;
    int i = start;
    while (i < end) {
      final ch = _src.codeUnitAt(i);
      if (inQuote) {
        _out.writeCharCode(ch);
        if (ch == 0x5C && i + 1 < end) {
          i++;
          _out.writeCharCode(_src.codeUnitAt(i));
        } else if (ch == 0x22) {
          inQuote = false;
        }
        i++;
        continue;
      }
      switch (ch) {
        case 0x22:
          inQuote = true;
          _out.writeCharCode(ch);
        case 0x7B:
        case 0x28:
        case 0x5B:
          depth++;
          _out.writeCharCode(ch);
        case 0x7D:
        case 0x29:
        case 0x5D:
          depth--;
          _out.writeCharCode(ch);
        case 0x2C:
          _out.write(',');
          if (depth == 1) _out.write(' ');
        default:
          _out.writeCharCode(ch);
      }
      i++;
    }
  }

  void _writeIndent() {
    for (int i = 0; i < _depth; i++) {
      _out.write('  ');
    }
  }
}
