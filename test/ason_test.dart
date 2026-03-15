import 'package:test/test.dart';
import 'package:ason/ason.dart';

class User implements AsonSchema {
  final int id;
  final String name;
  final bool active;

  User({required this.id, required this.name, required this.active});

  @override
  List<String> get fieldNames => ['id', 'name', 'active'];
  @override
  List<String?> get fieldTypes => ['int', 'str', 'bool'];
  @override
  List<dynamic> get fieldValues => [id, name, active];

  factory User.fromFields(Map<String, dynamic> m) => User(
        id: m['id'] as int,
        name: m['name'] as String,
        active: m['active'] as bool,
      );

  @override
  bool operator ==(Object o) =>
      o is User && id == o.id && name == o.name && active == o.active;
  @override
  int get hashCode => Object.hash(id, name, active);
}

class Dept implements AsonSchema {
  final String title;
  Dept({required this.title});
  @override
  List<String> get fieldNames => ['title'];
  @override
  List<String?> get fieldTypes => ['str'];
  @override
  List<dynamic> get fieldValues => [title];
  factory Dept.fromFields(Map<String, dynamic> m) =>
      Dept(title: m['title'] as String);
  @override
  bool operator ==(Object o) => o is Dept && title == o.title;
  @override
  int get hashCode => title.hashCode;
}

class Employee implements AsonSchema {
  final String name;
  final Dept dept;
  final bool active;

  Employee({required this.name, required this.dept, required this.active});
  @override
  List<String> get fieldNames => ['name', 'dept', 'active'];
  @override
  List<String?> get fieldTypes => ['str', null, 'bool'];
  @override
  List<dynamic> get fieldValues => [name, dept, active];

  factory Employee.fromFields(Map<String, dynamic> m) {
    final d = m['dept'];
    final dept = d is Map<String, dynamic>
        ? Dept.fromFields(d)
        : Dept(title: (d is List ? d.first.toString() : d.toString()));
    return Employee(
        name: m['name'] as String, dept: dept, active: m['active'] as bool);
  }
  @override
  bool operator ==(Object o) =>
      o is Employee && name == o.name && dept == o.dept;
  @override
  int get hashCode => Object.hash(name, dept);
}

class MatrixPart {
  final int id;
  final double score;
  MatrixPart({required this.id, required this.score});

  factory MatrixPart.fromFields(Map<String, dynamic> m) =>
      MatrixPart(id: m['id'] as int, score: (m['score'] as num).toDouble());
}

class MatrixNoOverlap {
  final int foo;
  final String? bar;
  MatrixNoOverlap({required this.foo, required this.bar});

  factory MatrixNoOverlap.fromFields(Map<String, dynamic> m) => MatrixNoOverlap(
        foo: (m['foo'] as num?)?.toInt() ?? 0,
        bar: m['bar'] as String?,
      );
}

class MatrixNestedOptional {
  final String name;
  final String? nick;
  MatrixNestedOptional({required this.name, required this.nick});

  factory MatrixNestedOptional.fromFields(Map<String, dynamic> m) =>
      MatrixNestedOptional(
          name: m['name'] as String, nick: m['nick'] as String?);
}

class MatrixUserNestedOptional {
  final int id;
  final MatrixNestedOptional profile;
  MatrixUserNestedOptional({required this.id, required this.profile});

  factory MatrixUserNestedOptional.fromFields(Map<String, dynamic> m) {
    final p = m['profile'];
    final profile = p is Map<String, dynamic>
        ? MatrixNestedOptional.fromFields(p)
        : MatrixNestedOptional(
            name: (p as List).isNotEmpty ? p[0] as String : '',
            nick: p.length > 1 ? p[1] as String? : null,
          );
    return MatrixUserNestedOptional(id: m['id'] as int, profile: profile);
  }
}

class LegacyMapHolder implements AsonSchema {
  final Map<String, dynamic> attrs;
  LegacyMapHolder(this.attrs);

  @override
  List<String> get fieldNames => ['attrs'];

  @override
  List<String?> get fieldTypes => ['[{key@str,value@int}]'];

  @override
  List<dynamic> get fieldValues => [attrs];
}

class SpecialSchemaFields implements AsonSchema {
  final int idUuid;
  final String numeric;
  final bool special;
  SpecialSchemaFields(
      {required this.idUuid, required this.numeric, required this.special});

  @override
  List<String> get fieldNames => ['id uuid', '65', '{}[]@"'];

  @override
  List<String?> get fieldTypes => ['int', 'str', 'bool'];

  @override
  List<dynamic> get fieldValues => [idUuid, numeric, special];

  factory SpecialSchemaFields.fromFields(Map<String, dynamic> m) =>
      SpecialSchemaFields(
        idUuid: m['id uuid'] as int,
        numeric: m['65'] as String,
        special: m['{}[]@"'] as bool,
      );

  @override
  bool operator ==(Object other) =>
      other is SpecialSchemaFields &&
      idUuid == other.idUuid &&
      numeric == other.numeric &&
      special == other.special;

  @override
  int get hashCode => Object.hash(idUuid, numeric, special);
}

void main() {
  group('Encode', () {
    test('single struct unannotated', () {
      final u = User(id: 1, name: 'Alice', active: true);
      expect(encode(u), '{id,name,active}:(1,Alice,true)');
    });

    test('single struct typed', () {
      final u = User(id: 1, name: 'Alice', active: true);
      expect(encodeTyped(u), '{id@int,name@str,active@bool}:(1,Alice,true)');
    });

    test('vec of structs', () {
      final users = [
        User(id: 1, name: 'Alice', active: true),
        User(id: 2, name: 'Bob', active: false),
      ];
      expect(encode(users), '[{id,name,active}]:(1,Alice,true),(2,Bob,false)');
    });

    test('vec typed', () {
      final users = [
        User(id: 1, name: 'Alice', active: true),
        User(id: 2, name: 'Bob', active: false),
      ];
      expect(encodeTyped(users),
          '[{id@int,name@str,active@bool}]:(1,Alice,true),(2,Bob,false)');
    });

    test('nested struct', () {
      final e = Employee(
          name: 'Alice', dept: Dept(title: 'Engineering'), active: true);
      expect(
          encode(e), '{name,dept@{title},active}:(Alice,(Engineering),true)');
    });

    test('nested struct typed', () {
      final e = Employee(
          name: 'Alice', dept: Dept(title: 'Engineering'), active: true);
      expect(encodeTyped(e),
          '{name@str,dept@{title@str},active@bool}:(Alice,(Engineering),true)');
    });

    test('escaped string', () {
      final u = User(id: 1, name: 'hello, world', active: true);
      final s = encode(u);
      expect(s.contains('"'), true);
    });

    test('quotes string values containing @', () {
      final u = User(id: 1, name: '@Alice', active: true);
      expect(encode(u), '{id,name,active}:(1,"@Alice",true)');
      expect(decodeWith(encode(u), User.fromFields), u);
      expect(decodeWith(encodeTyped(u), User.fromFields), u);
      expect(decodeWith(encodePretty(u), User.fromFields), u);
      expect(decodeWith(encodePrettyTyped(u), User.fromFields), u);
      final bin = encodeBinary(u);
      final u2 = decodeBinaryWith(
        bin,
        const ['id', 'name', 'active'],
        const [FieldType.int_, FieldType.string_, FieldType.bool_],
        User.fromFields,
      );
      expect(u2, u);
    });

    test('float formatting', () {
      final result = encode([_FloatStruct(v: 95.5)]);
      expect(result.contains('95.5'), true);
    });

    test('negative numbers', () {
      final result = encode([_NumStruct(a: -42, b: -3.15)]);
      expect(result.contains('-42'), true);
      expect(result.contains('-3.15'), true);
    });
  });

  group('Decode', () {
    test('single struct', () {
      final u = decodeWith('{id,name,active}:(1,Alice,true)', User.fromFields);
      expect(u.id, 1);
      expect(u.name, 'Alice');
      expect(u.active, true);
    });

    test('typed schema', () {
      final u = decodeWith(
          '{id@int,name@str,active@bool}:(1,Alice,true)', User.fromFields);
      expect(u.id, 1);
      expect(u.name, 'Alice');
      expect(u.active, true);
    });

    test('rejects schema type aliases', () {
      expect(
        () => decode('{id@integer,name@str,active@bool}:(1,Alice,true)'),
        throwsA(isA<AsonError>()),
      );
      expect(
        () => decode('{id@int,name@string,active@bool}:(1,Alice,true)'),
        throwsA(isA<AsonError>()),
      );
      expect(
        () => decode('{score@double}:(3.5)'),
        throwsA(isA<AsonError>()),
      );
      expect(
        () => decode('{active@boolean}:(true)'),
        throwsA(isA<AsonError>()),
      );
      expect(
        () => decode('{tags@[string]}:([Alice])'),
        throwsA(isA<AsonError>()),
      );
      expect(
        () => decode('{profile@{name@string}}:((Alice))'),
        throwsA(isA<AsonError>()),
      );
    });

    test('vec of structs', () {
      final users = decodeListWith(
        '[{id,name,active}]:(1,Alice,true),(2,Bob,false)',
        User.fromFields,
      );
      expect(users.length, 2);
      expect(users[0].name, 'Alice');
      expect(users[1].name, 'Bob');
    });

    test('multiline', () {
      final users = decodeListWith(
        '[{id@int,name@str,active@bool}]:\n  (1, Alice, true),\n  (2, Bob, false)',
        User.fromFields,
      );
      expect(users.length, 2);
    });

    test('quoted string', () {
      final u = decodeWith(
          '{id,name,active}:(1,"Carol Smith",true)', User.fromFields);
      expect(u.name, 'Carol Smith');
    });

    test('optional field with value', () {
      final m = decode('{id,label}:(1,hello)') as Map<String, dynamic>;
      expect(m['id'], 1);
      expect(m['label'], 'hello');
    });

    test('optional field with null', () {
      final m = decode('{id,label}:(2,)') as Map<String, dynamic>;
      expect(m['id'], 2);
      expect(m['label'], null);
    });

    test('array field', () {
      final m =
          decode('{name,tags@[]}:(Alice,[rust,go])') as Map<String, dynamic>;
      expect(m['tags'], ['rust', 'go']);
    });

    test('entry-list field', () {
      final m = decode(
        '{name,attrs@[{key@str,value@int}]}:(Alice,[(age,30),(score,95)])',
      ) as Map<String, dynamic>;
      expect(m['name'], 'Alice');
      expect((m['attrs'] as List).length, 2);
    });

    test('nested struct', () {
      final m = decode('{name,dept@{title}}:(Alice,(Manager))')
          as Map<String, dynamic>;
      expect(m['name'], 'Alice');
    });

    test('float field', () {
      final m = decode('{id,value}:(1,95.5)') as Map<String, dynamic>;
      expect(m['value'], 95.5);
    });

    test('negative number', () {
      final m = decode('{a,b}:(-42,-3.15)') as Map<String, dynamic>;
      expect(m['a'], -42);
      expect(m['b'], -3.15);
    });

    test('comment stripping', () {
      final m = decode('/* users */ {id,name,active}:(1,Alice,true)')
          as Map<String, dynamic>;
      expect(m['id'], 1);
    });

    test('legacy map syntax rejected', () {
      expect(
        () => decode('{attrs}:(<age:30>)'),
        throwsA(isA<AsonError>()),
      );
    });

    test('trailing comma', () {
      final users = decodeListWith(
        '[{id,name,active}]:(1,Alice,true),(2,Bob,false),',
        User.fromFields,
      );
      expect(users.length, 2);
    });

    test('matrix P1 typed partial overlap', () {
      final dst = decodeWith(
        '{id@int,name@str,score@float,active@bool}:(42,Alice,9.5,true)',
        MatrixPart.fromFields,
      );
      expect(dst.id, 42);
      expect(dst.score, 9.5);
    });

    test('matrix P1 untyped partial overlap', () {
      final dst = decodeWith(
        '{id,name,score,active}:(42,Alice,9.5,true)',
        MatrixPart.fromFields,
      );
      expect(dst.id, 42);
      expect(dst.score, 9.5);
    });

    test('matrix P2 typed no overlap defaults', () {
      final dst = decodeWith(
        '{id@int,name@str}:(42,Alice)',
        MatrixNoOverlap.fromFields,
      );
      expect(dst.foo, 0);
      expect(dst.bar, null);
    });

    test('matrix P2 untyped no overlap defaults', () {
      final dst = decodeWith(
        '{id,name}:(42,Alice)',
        MatrixNoOverlap.fromFields,
      );
      expect(dst.foo, 0);
      expect(dst.bar, null);
    });

    test('matrix N4 typed nested optional subset', () {
      final dst = decodeListWith(
        '[{id@int,profile@{name@str,nick@str?,score@float?},active@bool}]:(1,(Alice,ally,9.5),true),(2,(Bob,,),false)',
        MatrixUserNestedOptional.fromFields,
      );
      expect(dst.length, 2);
      expect(dst[0].profile.name, 'Alice');
      expect(dst[0].profile.nick, 'ally');
      expect(dst[1].profile.name, 'Bob');
      expect(dst[1].profile.nick, null);
    });

    test('matrix N4 untyped nested optional subset', () {
      final dst = decodeListWith(
        '[{id,profile@{name,nick,score},active}]:(1,(Alice,ally,9.5),true),(2,(Bob,,),false)',
        MatrixUserNestedOptional.fromFields,
      );
      expect(dst.length, 2);
      expect(dst[0].profile.nick, 'ally');
      expect(dst[1].profile.nick, null);
    });
  });

  group('Roundtrip', () {
    test('single struct', () {
      final u = User(id: 42, name: 'Bob', active: false);
      final s = encode(u);
      final u2 = decodeWith(s, User.fromFields);
      expect(u, u2);
    });

    test('typed roundtrip', () {
      final u = User(id: 42, name: 'Bob', active: false);
      final s = encodeTyped(u);
      final u2 = decodeWith(s, User.fromFields);
      expect(u, u2);
    });

    test('nested struct', () {
      final e = Employee(name: 'Alice', dept: Dept(title: 'Eng'), active: true);
      final s = encode(e);
      final e2 = decodeWith(s, Employee.fromFields);
      expect(e, e2);
    });

    test('quoted schema field names', () {
      final v =
          SpecialSchemaFields(idUuid: 1, numeric: 'Alice', special: true);
      expect(
        encodeTyped(v),
        '{"id uuid"@int,"65"@str,"{}[]@\\""@bool}:(1,Alice,true)',
      );
      expect(decodeWith(encodeTyped(v), SpecialSchemaFields.fromFields), v);
      expect(decodeWith(encodePrettyTyped(v), SpecialSchemaFields.fromFields), v);
    });
  });

  group('Binary', () {
    test('legacy map field rejected', () {
      expect(
        () => encode(LegacyMapHolder({'age': 30})),
        throwsA(isA<AsonError>()),
      );
    });

    test('encode/decode struct', () {
      final u = User(id: 1, name: 'Alice', active: true);
      final bin = encodeBinary(u);
      final u2 = decodeBinaryWith(
        bin,
        ['id', 'name', 'active'],
        [FieldType.int_, FieldType.string_, FieldType.bool_],
        User.fromFields,
      );
      expect(u, u2);
    });

    test('encode/decode vec', () {
      final users = [
        User(id: 1, name: 'Alice', active: true),
        User(id: 2, name: 'Bob', active: false),
      ];
      final bin = encodeBinary(users);
      final users2 = decodeBinaryListWith(
        bin,
        ['id', 'name', 'active'],
        [FieldType.int_, FieldType.string_, FieldType.bool_],
        User.fromFields,
      );
      expect(users2.length, 2);
      expect(users[0], users2[0]);
      expect(users[1], users2[1]);
    });

    test('binary smaller than JSON', () {
      final u = User(id: 1, name: 'Alice', active: true);
      final bin = encodeBinary(u);
      final json = '{"id":1,"name":"Alice","active":true}';
      expect(bin.length < json.length, true);
    });

    test('encode/decode quoted schema names', () {
      final v =
          SpecialSchemaFields(idUuid: 1, numeric: 'Alice', special: true);
      final bin = encodeBinary(v);
      final v2 = decodeBinaryWith(
        bin,
        ['id uuid', '65', '{}[]@"'],
        [FieldType.int_, FieldType.string_, FieldType.bool_],
        SpecialSchemaFields.fromFields,
      );
      expect(v2, v);
    });
  });

  group('Pretty', () {
    test('simple struct', () {
      final u = User(id: 1, name: 'Alice', active: true);
      final p = encodePretty(u);
      expect(p, '{id, name, active}:(1, Alice, true)');
    });

    test('typed simple', () {
      final u = User(id: 1, name: 'Alice', active: true);
      final p = encodePrettyTyped(u);
      expect(p, '{id@int, name@str, active@bool}:(1, Alice, true)');
    });

    test('array has newlines', () {
      final users = [
        User(id: 1, name: 'Alice', active: true),
        User(id: 2, name: 'Bob', active: false),
      ];
      final p = encodePretty(users);
      expect(p.contains('\n'), true);
    });

    test('pretty roundtrip', () {
      final u = User(id: 1, name: 'Alice', active: true);
      final p = encodePretty(u);
      final u2 = decodeWith(p, User.fromFields);
      expect(u, u2);
    });
  });
}

// Helper structs for testing
class _FloatStruct implements AsonSchema {
  final double v;
  _FloatStruct({required this.v});
  @override
  List<String> get fieldNames => ['v'];
  @override
  List<String?> get fieldTypes => ['float'];
  @override
  List<dynamic> get fieldValues => [v];
}

class _NumStruct implements AsonSchema {
  final int a;
  final double b;
  _NumStruct({required this.a, required this.b});
  @override
  List<String> get fieldNames => ['a', 'b'];
  @override
  List<String?> get fieldTypes => ['int', 'float'];
  @override
  List<dynamic> get fieldValues => [a, b];
}
