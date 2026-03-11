# ason

[![Pub Version](https://img.shields.io/pub/v/ason.svg)](https://pub.dev/packages/ason)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

高性能 [ASON](https://github.com/ason-lab/ason)（Array-Schema Object Notation）Dart 编解码库 —— 一种面向 LLM 交互和大规模数据传输的高效序列化格式。

[English](README.md)

## 什么是 ASON？

ASON 将 **Schema** 与 **数据** 分离，消除了 JSON 中每个对象都重复出现 Key 的冗余。Schema 只声明一次，数据行仅保留纯值：

```text
JSON (100 tokens):
{"users":[{"id":1,"name":"Alice","active":true},{"id":2,"name":"Bob","active":false}]}

ASON (~35 tokens, 节省 65%):
[{id:int, name:str, active:bool}]:(1,Alice,true),(2,Bob,false)
```

| 方面       | JSON         | ASON             |
| ---------- | ------------ | ---------------- |
| Token 效率 | 100%         | 30–70% ✓         |
| Key 重复   | 每个对象都有 | 声明一次 ✓       |
| 人类可读   | 是           | 是 ✓             |
| 嵌套结构   | ✓            | ✓                |
| 类型注解   | 无           | 可选 ✓           |
| 序列化速度 | 1x           | **~1.7–2.6x 更快** ✓ |
| 数据体积   | 100%         | **40–55%** ✓     |

## 快速开始

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  ason: ^0.1.0
```

### 序列化与反序列化结构体

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

  // 序列化
  final s = encode(user);
  assert(s == '{id,name,active}:(1,Alice,true)');

  // 反序列化
  final user2 = decodeWith(s, User.fromMap);
  assert(user2.id == 1 && user2.name == 'Alice');
}
```

### 带类型注解序列化

使用 `encodeTyped` 输出带类型注解的 Schema —— 适用于文档生成、LLM 提示词和跨语言数据交换：

```dart
final s = encodeTyped(user);
// 输出: {id:int,name:str,active:bool}:(1,Alice,true)

// 反序列化同时支持带注解和不带注解的 Schema
final user2 = decodeWith(s, User.fromMap);
```

### 序列化与反序列化 List（Schema 驱动）

对于 `List<AsonSchema>`，ASON 只写入一次 Schema，每个元素以紧凑元组形式输出 —— 这是相比 JSON 的核心优势：

```dart
final users = [
  User(id: 1, name: 'Alice', active: true),
  User(id: 2, name: 'Bob', active: false),
];

// 无注解 Schema
final s = encode(users);
// 输出: [{id,name,active}]:(1,Alice,true),(2,Bob,false)

// 带类型注解 Schema
final s2 = encodeTyped(users);
// 输出: [{id:int,name:str,active:bool}]:(1,Alice,true),(2,Bob,false)

// 反序列化 —— 两种格式均可
final users2 = decodeListWith(s, User.fromMap);
```

## 支持的类型

| 类型       | ASON 表示             | 示例                     |
| ---------- | --------------------- | ------------------------ |
| int        | 纯数字                | `42`, `-100`             |
| double     | 带小数点              | `3.14`, `-0.5`           |
| bool       | 字面量                | `true`, `false`          |
| String     | 无引号或有引号        | `Alice`, `"Carol Smith"` |
| null       | 留空                  | _(空白)_ 表示 null       |
| List       | `[v1,v2,v3]`          | `[rust,go,python]`       |
| Map        | `<k1:v1, k2:v2>`      | `<age:30, score:95>`     |
| 嵌套结构体 | `(field1,field2)`     | `(Engineering,500000)`   |

### 嵌套结构体

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

// Schema 自动反映嵌套结构：
// {name:str,dept:{title:str}}:(Alice,(Engineering))
```

### 可选字段

```text
// 有值:    {id,label}:(1,hello)
// null:   {id,label}:(1,)
```

### 数组与字典

```text
// 数组字段:
{name,tags}:(Alice,[rust,go,python])

// 字典字段:
{name,attrs}:(Alice,<age:30, score:95>)
```

### 类型注解（可选）

ASON Schema 支持**可选的**类型注解。两种形式完全等价 —— 反序列化器对它们的处理完全一致：

```text
// 不带注解（encode 的默认输出）
{id,name,salary,active}:(1,Alice,5000.50,true)

// 带注解（encodeTyped 的输出）
{id:int,name:str,salary:float,active:bool}:(1,Alice,5000.50,true)
```

注解是**纯粹的装饰性元数据** —— 它们不影响解析和反序列化行为。

**适用场景：**

- LLM 提示词 — 帮助模型理解并生成正确的数据
- API 文档 — 无需外部文档即可自描述 Schema
- 跨语言数据交换 — 消除类型歧义（`42` 是 int 还是 double？）
- 调试 — 一眼看出数据类型

### 注释

```text
/* 用户列表 */
[{id:int, name:str, active:bool}]:(1,Alice,true),(2,Bob,false)
```

### 多行格式

```text
[{id:int, name:str, active:bool}]:
  (1, Alice, true),
  (2, Bob, false),
  (3, "Carol Smith", true)
```

## API 参考

### 文本格式

| 函数                           | 说明                                        |
| ------------------------------ | ------------------------------------------- |
| `encode(value)`                | 序列化 → 无注解 Schema `{id,name}:`         |
| `encodeTyped(value)`           | 序列化 → 带注解 Schema `{id:int,name:str}:` |
| `decode(input)`                | 反序列化为动态 Map/List（两种格式均可）      |
| `decodeWith(input, factory)`   | 反序列化为类型化对象                         |
| `decodeListWith(input, factory)` | 反序列化为类型化列表                       |

### 美化格式

| 函数                          | 说明                        |
| ----------------------------- | --------------------------- |
| `encodePretty(value)`         | 美化格式 ASON（无注解）     |
| `encodePrettyTyped(value)`    | 美化格式 ASON（带注解）     |

### 二进制格式

| 函数                                             | 说明                    |
| ------------------------------------------------ | ----------------------- |
| `encodeBinary(value)`                            | 编码为紧凑二进制字节    |
| `decodeBinaryWith(data, fields, types, factory)` | 解码为类型化对象        |
| `decodeBinaryListWith(data, fields, types, factory)` | 解码为类型化列表    |

## 性能

在 Linux 上使用 Dart VM 测试，与 `dart:convert` JSON 对比：

### 序列化（ASON 快 1.6–2.6 倍）

| 场景            | JSON      | ASON     | 加速比    | BIN 编码   | BIN vs JSON |
| --------------- | --------- | -------- | --------- | ---------- | ----------- |
| 扁平结构 × 100   | 21.6 ms   | 8.2 ms   | **2.64x** | 13.2 ms    | **1.6x**    |
| 扁平结构 × 500   | 60.5 ms   | 35.7 ms  | **1.69x** | 9.3 ms     | **6.5x**    |
| 扁平结构 × 1000  | 111.5 ms  | 70.5 ms  | **1.58x** | 19.1 ms    | **5.8x**    |
| 扁平结构 × 5000  | 616.4 ms  | 369.5 ms | **1.67x** | 137.8 ms   | **4.5x**    |
| 5 层嵌套 × 10    | 45.5 ms   | 26.3 ms  | **1.73x** | 10.7 ms    | **4.3x**    |
| 5 层嵌套 × 50    | 226.0 ms  | 116.0 ms | **1.95x** | 28.9 ms    | **7.8x**    |
| 5 层嵌套 × 100   | 481.4 ms  | 232.6 ms | **2.07x** | 88.0 ms    | **5.5x**    |
| 大数据量 (10k)   | 134.6 ms  | 73.7 ms  | **1.83x** | 30.0 ms    | **4.5x**    |

### 反序列化（ASON 快 1.1–3.2 倍）

| 场景            | JSON      | ASON     | 加速比    | BIN 解码   | BIN vs JSON |
| --------------- | --------- | -------- | --------- | ---------- | ----------- |
| 扁平结构 × 500   | 40.5 ms   | 40.2 ms  | **1.01x** | 35.5 ms    | **1.1x**    |
| 扁平结构 × 1000  | 87.7 ms   | 78.3 ms  | **1.12x** | 70.2 ms    | **1.3x**    |
| 5 层嵌套 × 10    | 36.4 ms   | 15.0 ms  | **2.42x** | —          | —           |
| 5 层嵌套 × 50    | 181.8 ms  | 57.3 ms  | **3.17x** | —          | —           |
| 5 层嵌套 × 100   | 376.5 ms  | 136.8 ms | **2.75x** | —          | —           |
| 大数据量 (10k)   | 103.7 ms  | 81.5 ms  | **1.27x** | 76.6 ms    | **1.4x**    |

### 体积节省

| 场景            | JSON     | ASON 文本 | ASON 二进制 | 文本节省 | 二进制节省 |
| --------------- | -------- | --------- | ----------- | -------- | ---------- |
| 扁平结构 × 1000 | 118.8 KB | 55.4 KB   | 72.7 KB     | **53%**  | **39%**    |
| 5 层嵌套 × 100  | 438.1 KB | 170.2 KB  | 225.4 KB    | **61%**  | **49%**    |
| 大数据量 (10k)  | 1.2 MB   | 576.8 KB  | 744.5 KB    | **53%**  | **39%**    |

### 为什么 ASON 更快？

1. **零哈希匹配** — Schema 只解析一次，数据字段通过位置索引 `O(1)` 映射，无需每行对 Key 字符串计算哈希。
2. **Schema 缓存** — 解析后的字段名全局缓存，避免重复解析相同的 Schema 头。
3. **模式驱动解析** — 解码器通过 Schema 已知每个字段的类型，CPU 分支预测命中率接近 100%。
4. **优化分支顺序** — 数字优先检查（最常见数据类型），布尔值内联字符比较避免 substring 分配。
5. **极小内存分配** — 所有数据行共享同一个 Schema 引用，无需为每行重复分配 Key 字符串的内存。

运行基准测试：

```bash
dart run example/bench.dart
```

## 示例

```bash
# 基础用法
dart run example/basic.dart

# 全面测试（全类型、嵌套结构、边界用例）
dart run example/complex.dart

# 性能基准（ASON vs JSON，吞吐量，体积比较）
dart run example/bench.dart
```

## ASON 格式规范

完整的 [ASON 规范](https://github.com/ason-lab/ason/blob/main/docs/ASON_SPEC_CN.md) 包含语法规则、BNF 文法、转义规则、类型系统及 LLM 集成最佳实践。

### 语法速查表

| 元素     | Schema 语法                 | 数据语法            |
| -------- | --------------------------- | ------------------- |
| 对象     | `{field1:type,field2:type}` | `(val1,val2)`       |
| 简单数组 | `field:[type]`              | `[v1,v2,v3]`        |
| 对象数组 | `field:[{f1:type,f2:type}]` | `[(v1,v2),(v3,v4)]` |
| 字典     | `field:<K:V>`               | `<k1:v1, k2:v2>`    |
| 嵌套对象 | `field:{f1:type,f2:type}`   | `(v1,(v3,v4))`      |
| 空值     | —                           | _(空白)_            |
| 空字符串 | —                           | `""`                |
| 注释     | —                           | `/* ... */`         |

## 许可证

MIT

## Contributors

- [Athan](https://github.com/athxx)

## Latest Benchmarks

在当前机器上使用 Dart `3.9.4` 实测：

- 扁平 1,000 条记录：ASON 序列化 `183.06ms`，JSON `242.92ms`；但这一轮反序列化 ASON `448.75ms`，JSON `340.35ms`
- 扁平 10,000 条记录：ASON 序列化 `145.45ms`，JSON `231.42ms`；反序列化 ASON `183.07ms`，JSON `202.22ms`
- 深层 100 条 company 数据：ASON 序列化 `892.85ms`，JSON `2099.11ms`；反序列化 ASON `438.69ms`，JSON `1610.99ms`
- 1,000 条扁平记录体积：JSON `121,675 B`，ASON 文本 `56,718 B`（缩小 `53%`），ASON 二进制 `74,454 B`（缩小 `39%`）
- 这轮测试里二进制序列化通常比 JSON 快很多，尤其是深层结构
