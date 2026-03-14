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

void main() {
  final u = User(id: 1, name: 'Alice', active: true);
  final bin = encodeBinary(u);
  print('bin length: ${bin.length}');
  print(
      'bin hex: ${bin.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

  try {
    final u2 = decodeBinaryWith(bin, ['id', 'name', 'active'],
        [FieldType.int_, FieldType.string_, FieldType.bool_], User.fromFields);
    print('u: id=${u.id} name="${u.name}" active=${u.active}');
    print('u2: id=${u2.id} name="${u2.name}" active=${u2.active}');
    print('equal: ${u == u2}');
    print('u.runtimeType: ${u.runtimeType}');
    print('u2.runtimeType: ${u2.runtimeType}');
  } catch (e) {
    print('Error: $e');
  }
}
