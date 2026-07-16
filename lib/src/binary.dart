import 'dart:typed_data';
import 'error.dart';
import 'schema.dart';

// ============================================================================
// Public API
// ============================================================================

/// Encode a value to ASUN binary format.
///
/// Wire format (LEB128 varint; matches the Rust reference):
/// - bool: 1 byte (0x00=false, 0x01=true)
/// - int: zigzag + LEB128 varint (i64)
/// - double: 8 bytes LE (IEEE 754 bit-cast)
/// - String: uvarint length + UTF-8 bytes
/// - null (Option None): u8 tag 0
/// - Some(T): u8 tag 1 + T payload
/// - List<T>: uvarint count + elements
/// - struct (AsunSchema): fields in declaration order
Uint8List encodeBinary(dynamic value) {
  final w = _BinaryWriter(256);
  _writeBinaryValue(w, value);
  return w.toBytes();
}

/// Decode ASUN binary bytes into structured Dart value.
///
/// Returns Map<String, dynamic> for structs, List for arrays, etc.
/// Use [decodeBinaryWith] for typed decoding.
///
/// For struct decoding, you must provide field names via [fields] parameter.
dynamic decodeBinary(Uint8List data, {List<String>? fields}) {
  final r = _BinaryReader(data);
  if (fields != null) {
    return r._readStruct(fields);
  }
  // Without schema info, we can't decode binary (not self-describing)
  throw AsunError('ASUN binary format is not self-describing; provide fields');
}

/// Decode ASUN binary into typed object using factory.
T decodeBinaryWith<T>(
  Uint8List data,
  List<String> fields,
  List<_FieldType> types,
  T Function(Map<String, dynamic>) factory,
) {
  final r = _BinaryReader(data);
  final map = <String, dynamic>{};
  for (int i = 0; i < fields.length; i++) {
    map[fields[i]] = r._readTyped(types[i]);
  }
  return factory(map);
}

/// Decode a list of structs from ASUN binary.
List<T> decodeBinaryListWith<T>(
  Uint8List data,
  List<String> fields,
  List<_FieldType> types,
  T Function(Map<String, dynamic>) factory,
) {
  final r = _BinaryReader(data);
  final count = r._readUvarint();
  final result = <T>[];
  for (int c = 0; c < count; c++) {
    final map = <String, dynamic>{};
    for (int i = 0; i < fields.length; i++) {
      map[fields[i]] = r._readTyped(types[i]);
    }
    result.add(factory(map));
  }
  return result;
}

/// Field type descriptors for binary decoding.
enum _FieldType {
  bool_,
  int_,
  double_,
  string_,
  optionalInt,
  optionalDouble,
  optionalString,
  optionalBool,
  listInt,
  listDouble,
  listString,
  listBool,
}

// Expose as public typedef
typedef FieldType = _FieldType;

// ============================================================================
// BinaryWriter — high-performance, pre-allocated buffer
// ============================================================================

class _BinaryWriter {
  Uint8List _buf;
  ByteData _view;
  int _pos = 0;

  _BinaryWriter(int initialCapacity)
      : _buf = Uint8List(initialCapacity),
        _view = ByteData(0) {
    _view = ByteData.sublistView(_buf);
  }

  void _ensureCapacity(int extra) {
    if (_pos + extra <= _buf.length) return;
    int newLen = _buf.length * 2;
    while (newLen < _pos + extra) {
      newLen *= 2;
    }
    final newBuf = Uint8List(newLen);
    newBuf.setRange(0, _pos, _buf);
    _buf = newBuf;
    _view = ByteData.sublistView(_buf);
  }

  void writeU8(int v) {
    _ensureCapacity(1);
    _buf[_pos++] = v;
  }

  void writeU16(int v) {
    _ensureCapacity(2);
    _view.setUint16(_pos, v, Endian.little);
    _pos += 2;
  }

  void writeU32(int v) {
    _ensureCapacity(4);
    _view.setUint32(_pos, v, Endian.little);
    _pos += 4;
  }

  /// LEB128 unsigned varint (v treated as unsigned 64-bit).
  void writeUvarint(int v) {
    _ensureCapacity(10);
    // Use unsigned shift (>>>) so the high bit does not sign-extend.
    while ((v & ~0x7F) != 0) {
      _buf[_pos++] = (v & 0x7F) | 0x80;
      v >>>= 7;
    }
    _buf[_pos++] = v & 0x7F;
  }

  /// zigzag + LEB128 signed varint.
  void writeIvarint(int v) {
    writeUvarint((v << 1) ^ (v >> 63));
  }

  void writeF64(double v) {
    _ensureCapacity(8);
    _view.setFloat64(_pos, v, Endian.little);
    _pos += 8;
  }

  void writeBool(bool v) {
    writeU8(v ? 1 : 0);
  }

  /// Write string: u32 length + UTF-8 bytes. SIMD-like bulk copy.
  void writeString(String s) {
    // Encode to UTF-8 bytes
    // Fast path: ASCII-only strings (common case)
    final units = s.codeUnits;
    bool allAscii = true;
    for (int i = 0; i < units.length; i++) {
      if (units[i] > 0x7F) {
        allAscii = false;
        break;
      }
    }

    if (allAscii) {
      writeUvarint(units.length);
      _ensureCapacity(units.length);
      for (int i = 0; i < units.length; i++) {
        _buf[_pos++] = units[i];
      }
    } else {
      // Full UTF-8 encoding
      final bytes = _encodeUtf8(s);
      writeUvarint(bytes.length);
      _ensureCapacity(bytes.length);
      _buf.setRange(_pos, _pos + bytes.length, bytes);
      _pos += bytes.length;
    }
  }

  void writeBytes(Uint8List data) {
    writeUvarint(data.length);
    _ensureCapacity(data.length);
    _buf.setRange(_pos, _pos + data.length, data);
    _pos += data.length;
  }

  /// Get placeholder position for u32 count; returns position.
  int writePlaceholderU32() {
    _ensureCapacity(4);
    final p = _pos;
    _pos += 4;
    return p;
  }

  void fixU32(int pos, int value) {
    _view.setUint32(pos, value, Endian.little);
  }

  Uint8List toBytes() => Uint8List.sublistView(_buf, 0, _pos);

  static Uint8List _encodeUtf8(String s) {
    final codeUnits = s.codeUnits;
    final bytes = <int>[];
    for (int i = 0; i < codeUnits.length; i++) {
      int cu = codeUnits[i];
      // Handle surrogate pairs
      if (cu >= 0xD800 && cu <= 0xDBFF && i + 1 < codeUnits.length) {
        final next = codeUnits[i + 1];
        if (next >= 0xDC00 && next <= 0xDFFF) {
          final cp = 0x10000 + ((cu - 0xD800) << 10) + (next - 0xDC00);
          bytes.add(0xF0 | (cp >> 18));
          bytes.add(0x80 | ((cp >> 12) & 0x3F));
          bytes.add(0x80 | ((cp >> 6) & 0x3F));
          bytes.add(0x80 | (cp & 0x3F));
          i++;
          continue;
        }
      }
      if (cu <= 0x7F) {
        bytes.add(cu);
      } else if (cu <= 0x7FF) {
        bytes.add(0xC0 | (cu >> 6));
        bytes.add(0x80 | (cu & 0x3F));
      } else {
        bytes.add(0xE0 | (cu >> 12));
        bytes.add(0x80 | ((cu >> 6) & 0x3F));
        bytes.add(0x80 | (cu & 0x3F));
      }
    }
    return Uint8List.fromList(bytes);
  }
}

// ============================================================================
// Binary value writer
// ============================================================================

void _writeBinaryValue(_BinaryWriter w, dynamic v) {
  if (v == null) {
    w.writeU8(0); // None tag
    return;
  }
  if (v is bool) {
    w.writeBool(v);
    return;
  }
  if (v is int) {
    w.writeIvarint(v);
    return;
  }
  if (v is double) {
    w.writeF64(v);
    return;
  }
  if (v is String) {
    w.writeString(v);
    return;
  }
  if (v is AsunSchema) {
    // Struct: write fields in order, no length prefix
    final values = v.fieldValues;
    for (final fv in values) {
      _writeBinaryValue(w, fv);
    }
    return;
  }
  if (v is List) {
    if (v.isNotEmpty && v.first is AsunSchema) {
      // Vec<Struct>: uvarint count + each struct
      w.writeUvarint(v.length);
      for (final item in v) {
        final obj = item as AsunSchema;
        final values = obj.fieldValues;
        for (final fv in values) {
          _writeBinaryValue(w, fv);
        }
      }
    } else {
      // Plain list: uvarint count + elements
      w.writeUvarint(v.length);
      for (final item in v) {
        _writeBinaryValue(w, item);
      }
    }
    return;
  }
  if (v is Map) throw AsunError.unsupportedMap;
  // Fallback: write as string
  w.writeString(v.toString());
}

// ============================================================================
// BinaryReader — zero-copy reading from Uint8List
// ============================================================================

class _BinaryReader {
  final Uint8List _data;
  final ByteData _view;
  int _pos = 0;

  _BinaryReader(this._data) : _view = ByteData.sublistView(_data);

  void _ensure(int n) {
    if (_pos + n > _data.length) throw AsunError.eof;
  }

  int _readU8() {
    _ensure(1);
    return _data[_pos++];
  }

  /// LEB128 unsigned varint.
  int _readUvarint() {
    int result = 0;
    int shift = 0;
    while (true) {
      if (_pos >= _data.length) throw AsunError.eof;
      final b = _data[_pos++];
      if (shift >= 64) throw AsunError('binary decode: varint overflow');
      result |= (b & 0x7F) << shift;
      if (b & 0x80 == 0) return result;
      shift += 7;
    }
  }

  /// zigzag + LEB128 signed varint.
  int _readIvarint() {
    final v = _readUvarint();
    return (v >>> 1) ^ -(v & 1);
  }

  double _readF64() {
    _ensure(8);
    final v = _view.getFloat64(_pos, Endian.little);
    _pos += 8;
    return v;
  }

  bool _readBool() => _readU8() != 0;

  /// Zero-copy string read: returns substring from decoded UTF-8 bytes.
  String _readString() {
    final len = _readUvarint();
    _ensure(len);
    // Fast path: decode UTF-8
    final bytes = Uint8List.sublistView(_data, _pos, _pos + len);
    _pos += len;
    return String.fromCharCodes(
        bytes); // TODO: proper UTF-8 decode for multi-byte
  }

  /// Read a struct given field names — returns Map.
  Map<String, dynamic> _readStruct(List<String> fields) {
    final map = <String, dynamic>{};
    for (final _ in fields) {
      // Without type info, we can't know what to read
      throw AsunError(
          'binary struct decode requires type info; use decodeBinaryWith');
    }
    return map;
  }

  /// Read a typed field value.
  dynamic _readTyped(_FieldType type) {
    switch (type) {
      case _FieldType.bool_:
        return _readBool();
      case _FieldType.int_:
        return _readIvarint();
      case _FieldType.double_:
        return _readF64();
      case _FieldType.string_:
        return _readString();
      case _FieldType.optionalInt:
        return _readU8() == 0 ? null : _readIvarint();
      case _FieldType.optionalDouble:
        return _readU8() == 0 ? null : _readF64();
      case _FieldType.optionalString:
        return _readU8() == 0 ? null : _readString();
      case _FieldType.optionalBool:
        return _readU8() == 0 ? null : _readBool();
      case _FieldType.listInt:
        final count = _readUvarint();
        return List.generate(count, (_) => _readIvarint());
      case _FieldType.listDouble:
        final count = _readUvarint();
        return List.generate(count, (_) => _readF64());
      case _FieldType.listString:
        final count = _readUvarint();
        return List.generate(count, (_) => _readString());
      case _FieldType.listBool:
        final count = _readUvarint();
        return List.generate(count, (_) => _readBool());
    }
  }
}
