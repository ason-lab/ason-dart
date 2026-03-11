# ason

[![Pub Version](https://img.shields.io/pub/v/ason.svg)](https://pub.dev/packages/ason)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A high-performance [ASON](https://github.com/ason-lab/ason) (Array-Schema Object Notation) encoder/decoder for Dart — a token-efficient, schema-driven data format designed for LLM interactions and large-scale data transmission.

[中文文档](README_CN.md)

## What is ASON?

ASON separates **schema** from **data**, eliminating repetitive keys found in JSON. The schema is declared once, and data rows carry only values:

```text
JSON (100 tokens):
{"users":[{"id":1,"name":"Alice","active":true},{"id":2,"name":"Bob","active":false}]}

ASON (~35 tokens, 65% saving):
[{id:int, name:str, active:bool}]:(1,Alice,true),(2,Bob,false)
```

| Aspect              | JSON         | ASON             |
| ------------------- | ------------ | ---------------- |
| Token efficiency    | 100%         | 30–70% ✓         |
| Key repetition      | Every object | Declared once ✓  |
| Human readable      | Yes          | Yes ✓            |
| Nested structs      | ✓            | ✓                |
| Type annotations    | No           | Optional ✓       |
| Serialization speed | 1x           | **~1.7–2.6x faster** ✓ |
| Data size           | 100%         | **40–55%** ✓     |

## Quick Start

Add to your `pubspec.yaml`:

```yaml
dependencies:
  ason: ^0.1.0
```

### Serialize & Deserialize a Struct

```dart
import 'package:ason/ason.dart';

class User implements AsonSchema {
  final int id;
  final String name;
  final bool active;

  User({required this.id, required this.name, required this.active});

  @override List<String> get fieldNames => ['id', 'name', 'active'];
  @override List<String?> get fieldTypes => ['int', 'str', 'bool'];
  @override List<dynamic> get fieldValues => [id, name, active];

  factory User.fromMap(Map<String, dynamic> m) => User(
    id: m['id'] as int, name: m['name'] as String, active: m['active'] as bool,
  );
}

void main() {
  final user = User(id: 1, name: 'Alice', active: true);

  // Serialize
  final s = encode(user);
  assert(s == '{id,name,active}:(1,Alice,true)');

  // Deserialize
  final user2 = decodeWith(s, User.fromMap);
  assert(user2.id == 1 && user2.name == 'Alice');
}
```

### Serialize with Type Annotations

Use `encodeTyped` to output a type-annotated schema — useful for documentation, LLM prompts, and cross-language exchange:

```dart
final s = encodeTyped(user);
// Output: {id:int,name:str,active:bool}:(1,Alice,true)

// Deserializer accepts both annotated and unannotated schemas
final user2 = decodeWith(s, User.fromMap);
```

### Serialize & Deserialize a List (Schema-Driven)

For `List<AsonSchema>`, ASON writes the schema **once** and emits each element as a compact tuple — the key advantage over JSON:

```dart
final users = [
  User(id: 1, name: 'Alice', active: true),
  User(id: 2, name: 'Bob', active: false),
];

// Unannotated schema
final s = encode(users);
// Output: [{id,name,active}]:(1,Alice,true),(2,Bob,false)

// Type-annotated schema
final s2 = encodeTyped(users);
// Output: [{id:int,name:str,active:bool}]:(1,Alice,true),(2,Bob,false)

// Deserialize — accepts both forms
final users2 = decodeListWith(s, User.fromMap);
```

## Supported Types

| Type           | ASON Representation   | Example                  |
| -------------- | --------------------- | ------------------------ |
| int            | Plain number          | `42`, `-100`             |
| double         | Decimal number        | `3.14`, `-0.5`           |
| bool           | Literal               | `true`, `false`          |
| String         | Unquoted or quoted    | `Alice`, `"Carol Smith"` |
| null           | Empty (blank)         | _(blank)_ for null       |
| List           | `[v1,v2,v3]`          | `[rust,go,python]`       |
| Map            | `<k1:v1, k2:v2>`      | `<age:30, score:95>`     |
| Nested struct  | `(field1,field2)`     | `(Engineering,500000)`   |

### Nested Structs

```dart
class Dept implements AsonSchema {
  final String title;
  // ...fieldNames/fieldTypes/fieldValues
}

class Employee implements AsonSchema {
  final String name;
  final Dept dept;
  // ...fieldNames/fieldTypes/fieldValues
}

// Schema reflects nesting:
// {name:str,dept:{title:str}}:(Alice,(Engineering))
```

### Optional Fields

```text
// With value:   {id,label}:(1,hello)
// With null:    {id,label}:(1,)
```

### Arrays & Maps

```text
// Array field:
{name,tags}:(Alice,[rust,go,python])

// Map field:
{name,attrs}:(Alice,<age:30, score:95>)
```

### Type Annotations (Optional)

ASON schema supports **optional** type annotations. Both forms are fully equivalent — the deserializer handles them identically:

```text
// Without annotations (default output of encode)
{id,name,salary,active}:(1,Alice,5000.50,true)

// With annotations (output of encodeTyped)
{id:int,name:str,salary:float,active:bool}:(1,Alice,5000.50,true)
```

Annotations are **purely decorative metadata** — they do not affect parsing or deserialization behavior.

**When to use annotations:**

- LLM prompts — helps models understand and generate correct data
- API documentation — self-describing schema without external docs
- Cross-language exchange — eliminates type ambiguity (is `42` an int or double?)
- Debugging — see data types at a glance

### Comments

```text
/* user list */
[{id:int, name:str, active:bool}]:(1,Alice,true),(2,Bob,false)
```

### Multiline Format

```text
[{id:int, name:str, active:bool}]:
  (1, Alice, true),
  (2, Bob, false),
  (3, "Carol Smith", true)
```

## API Reference

### Text Format

| Function                    | Description                                                  |
| --------------------------- | ------------------------------------------------------------ |
| `encode(value)`             | Serialize → unannotated schema `{id,name}:`                  |
| `encodeTyped(value)`        | Serialize → annotated schema `{id:int,name:str}:`            |
| `decode(input)`             | Deserialize to dynamic Map/List (both schema forms)          |
| `decodeWith(input, factory)` | Deserialize to typed object using factory                    |
| `decodeListWith(input, factory)` | Deserialize to typed list using factory                 |

### Pretty Format

| Function                     | Description                                   |
| ---------------------------- | --------------------------------------------- |
| `encodePretty(value)`        | Pretty-formatted ASON (unannotated)           |
| `encodePrettyTyped(value)`   | Pretty-formatted ASON (annotated)             |

### Binary Format

| Function                                        | Description                          |
| ----------------------------------------------- | ------------------------------------ |
| `encodeBinary(value)`                           | Encode to compact binary bytes       |
| `decodeBinaryWith(data, fields, types, factory)` | Decode binary to typed object       |
| `decodeBinaryListWith(data, fields, types, factory)` | Decode binary to typed list    |

## Performance

Benchmarked on Linux, Dart VM, comparing ASON against `dart:convert` JSON:

### Serialization (ASON is 1.6–2.6x faster)

| Scenario            | JSON      | ASON     | Speedup   | BIN encode | BIN vs JSON |
| ------------------- | --------- | -------- | --------- | ---------- | ----------- |
| Flat struct × 100   | 21.6 ms   | 8.2 ms   | **2.64x** | 13.2 ms    | **1.6x**    |
| Flat struct × 500   | 60.5 ms   | 35.7 ms  | **1.69x** | 9.3 ms     | **6.5x**    |
| Flat struct × 1000  | 111.5 ms  | 70.5 ms  | **1.58x** | 19.1 ms    | **5.8x**    |
| Flat struct × 5000  | 616.4 ms  | 369.5 ms | **1.67x** | 137.8 ms   | **4.5x**    |
| 5-level deep × 10   | 45.5 ms   | 26.3 ms  | **1.73x** | 10.7 ms    | **4.3x**    |
| 5-level deep × 50   | 226.0 ms  | 116.0 ms | **1.95x** | 28.9 ms    | **7.8x**    |
| 5-level deep × 100  | 481.4 ms  | 232.6 ms | **2.07x** | 88.0 ms    | **5.5x**    |
| Large payload (10k) | 134.6 ms  | 73.7 ms  | **1.83x** | 30.0 ms    | **4.5x**    |

### Deserialization (ASON is 1.1–3.2x faster)

| Scenario            | JSON      | ASON     | Speedup   | BIN decode | BIN vs JSON |
| ------------------- | --------- | -------- | --------- | ---------- | ----------- |
| Flat struct × 500   | 40.5 ms   | 40.2 ms  | **1.01x** | 35.5 ms    | **1.1x**    |
| Flat struct × 1000  | 87.7 ms   | 78.3 ms  | **1.12x** | 70.2 ms    | **1.3x**    |
| 5-level deep × 10   | 36.4 ms   | 15.0 ms  | **2.42x** | —          | —           |
| 5-level deep × 50   | 181.8 ms  | 57.3 ms  | **3.17x** | —          | —           |
| 5-level deep × 100  | 376.5 ms  | 136.8 ms | **2.75x** | —          | —           |
| Large payload (10k) | 103.7 ms  | 81.5 ms  | **1.27x** | 76.6 ms    | **1.4x**    |

### Size Savings

| Scenario            | JSON     | ASON text | ASON binary | Text saving | Binary saving |
| ------------------- | -------- | --------- | ----------- | ----------- | ------------- |
| Flat struct × 1000  | 118.8 KB | 55.4 KB   | 72.7 KB     | **53%**     | **39%**       |
| 5-level deep × 100  | 438.1 KB | 170.2 KB  | 225.4 KB    | **61%**     | **49%**       |
| Large payload (10k) | 1.2 MB   | 576.8 KB  | 744.5 KB    | **53%**     | **39%**       |

### Why is ASON Faster?

1. **Zero key-hashing** — Schema is parsed once; data fields are mapped by position index `O(1)`, no per-row key string hashing.
2. **Schema caching** — Parsed schema field names are cached globally, avoiding re-parsing identical headers.
3. **Schema-driven parsing** — The decoder knows the expected type of each field from the schema, enabling direct parsing. CPU branch prediction hits ~100%.
4. **Optimized branch order** — Numbers checked first (most common data type), inline bool comparison without substring allocation.
5. **Minimal memory allocation** — All data rows share one schema reference. No repeated key string allocation.

Run the benchmark yourself:

```bash
dart run example/bench.dart
```

## Examples

```bash
# Basic usage
dart run example/basic.dart

# Comprehensive (all types, nested structs, edge cases)
dart run example/complex.dart

# Performance benchmark (ASON vs JSON, throughput, size)
dart run example/bench.dart
```

## ASON Format Specification

See the full [ASON Spec](https://github.com/ason-lab/ason/blob/main/docs/ASON_SPEC.md) for syntax rules, BNF grammar, escape rules, type system, and LLM integration best practices.

### Syntax Quick Reference

| Element       | Schema                      | Data                |
| ------------- | --------------------------- | ------------------- |
| Object        | `{field1:type,field2:type}` | `(val1,val2)`       |
| Array         | `field:[type]`              | `[v1,v2,v3]`        |
| Object array  | `field:[{f1:type,f2:type}]` | `[(v1,v2),(v3,v4)]` |
| Map           | `field:<K:V>`               | `<k1:v1, k2:v2>`    |
| Nested object | `field:{f1:type,f2:type}`   | `(v1,(v3,v4))`      |
| Null          | —                           | _(blank)_           |
| Empty string  | —                           | `""`                |
| Comment       | —                           | `/* ... */`         |

## License

MIT

## Contributors

- [Athan](https://github.com/athxx)

## Latest Benchmarks

Measured on this machine with Dart `3.9.4`.

Headline numbers:

- Flat 1,000-record dataset: ASON serialize `183.06ms` vs JSON `242.92ms`, while deserialize was slower in this run at `448.75ms` vs JSON `340.35ms`
- Flat 10,000-record dataset: ASON serialize `145.45ms` vs JSON `231.42ms`, deserialize `183.07ms` vs JSON `202.22ms`
- Deep 100-record company dataset: ASON serialize `892.85ms` vs JSON `2099.11ms`, deserialize `438.69ms` vs JSON `1610.99ms`
- Size summary for 1,000 flat records: JSON `121,675 B`, ASON text `56,718 B` (`53%` smaller), ASON binary `74,454 B` (`39%` smaller)
- Binary serialization was often much faster than JSON in this run, especially on deep payloads
