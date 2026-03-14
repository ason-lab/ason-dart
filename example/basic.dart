import 'package:ason/ason.dart';

// ---------------------------------------------------------------------------
// Data classes with AsonSchema
// ---------------------------------------------------------------------------

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
  String toString() => 'User(id: $id, name: $name, active: $active)';

  @override
  bool operator ==(Object other) =>
      other is User &&
      id == other.id &&
      name == other.name &&
      active == other.active;

  @override
  int get hashCode => Object.hash(id, name, active);
}

void main() {
  print('=== ASON Dart Basic Examples ===\n');

  // 1. Serialize a single struct
  final user = User(id: 1, name: 'Alice', active: true);
  final asonStr = encode(user);
  print('1. Serialize single struct:');
  print('   $asonStr\n');
  assert(asonStr == '{id,name,active}:(1,Alice,true)');

  // 2. Serialize with type annotations (encodeTyped)
  final typedStr = encodeTyped(user);
  print('2. Serialize with type annotations:');
  print('   $typedStr\n');
  assert(typedStr == '{id@int,name@str,active@bool}:(1,Alice,true)');

  // 3. Deserialize from ASON (accepts both annotated and unannotated)
  final input = '{id@int,name@str,active@bool}:(1,Alice,true)';
  final decoded = decodeWith(input, User.fromFields);
  print('3. Deserialize single struct:');
  print('   $decoded\n');
  assert(decoded.id == 1);
  assert(decoded.name == 'Alice');
  assert(decoded.active == true);

  // 4. Serialize a vec of structs (schema-driven)
  final users = [
    User(id: 1, name: 'Alice', active: true),
    User(id: 2, name: 'Bob', active: false),
    User(id: 3, name: 'Carol Smith', active: true),
  ];
  final asonVec = encode(users);
  print('4. Serialize vec (schema-driven):');
  print('   $asonVec\n');

  // 5. Serialize vec with type annotations
  final typedVec = encodeTyped(users);
  print('5. Serialize vec with type annotations:');
  print('   $typedVec\n');
  assert(typedVec.startsWith('[{id@int,name@str,active@bool}]:'));

  // 6. Deserialize vec
  final vecInput =
      '[{id@int,name@str,active@bool}]:(1,Alice,true),(2,Bob,false),(3,"Carol Smith",true)';
  final decodedUsers = decodeListWith(vecInput, User.fromFields);
  print('6. Deserialize vec:');
  for (final u in decodedUsers) {
    print('   $u');
  }

  // 7. Multiline format
  print('\n7. Multiline format:');
  final multiline = '''[{id@int, name@str, active@bool}]:
  (1, Alice, true),
  (2, Bob, false),
  (3, "Carol Smith", true)''';
  final mlUsers = decodeListWith(multiline, User.fromFields);
  for (final u in mlUsers) {
    print('   $u');
  }

  // 8. Roundtrip (ASON-text + ASON-bin + JSON)
  print('\n8. Roundtrip (ASON text vs ASON binary):');
  final original = User(id: 42, name: 'Test User', active: true);
  final asonText = encode(original);
  final fromAson = decodeWith(asonText, User.fromFields);
  assert(original == fromAson);

  // ASON binary
  final asonBin = encodeBinary(original);
  final fromBin = decodeBinaryWith(
    asonBin,
    ['id', 'name', 'active'],
    [FieldType.int_, FieldType.string_, FieldType.bool_],
    User.fromFields,
  );
  assert(original == fromBin);

  print('   original:     $original');
  print('   ASON text:    $asonText (${asonText.length} B)');
  print('   ASON binary:  ${asonBin.length} B');
  print('   ✓ all formats roundtrip OK');

  // 9. Vec roundtrip (ASON-text + ASON-bin)
  print('\n9. Vec roundtrip:');
  final vecAson = encode(users);
  final vecBin = encodeBinary(users);
  final v1 = decodeListWith(vecAson, User.fromFields);
  assert(v1.length == users.length);
  for (int i = 0; i < users.length; i++) {
    assert(users[i] == v1[i]);
  }
  final v2 = decodeBinaryListWith(
    vecBin,
    ['id', 'name', 'active'],
    [FieldType.int_, FieldType.string_, FieldType.bool_],
    User.fromFields,
  );
  assert(v2.length == users.length);
  for (int i = 0; i < users.length; i++) {
    assert(users[i] == v2[i]);
  }
  print('   ASON text:   ${vecAson.length} B');
  print('   ASON binary: ${vecBin.length} B');
  print('   ✓ vec roundtrip OK');

  // 10. Optional fields
  print('\n10. Optional fields:');
  final withVal = decode('{id,label}:(1,hello)') as Map<String, dynamic>;
  print('   with value: id=${withVal['id']}, label=${withVal['label']}');

  final withNull = decode('{id,label}:(2,)') as Map<String, dynamic>;
  print('   with null:  id=${withNull['id']}, label=${withNull['label']}');

  // 11. Array fields
  print('\n11. Array fields:');
  final tagged =
      decode('{name,tags@[]}:(Alice,[rust,go,python])') as Map<String, dynamic>;
  print('   name=${tagged['name']}, tags=${tagged['tags']}');

  // 12. Comments
  print('\n12. With comments:');
  final commented = decode('/* user list */ {id,name,active}:(1,Alice,true)')
      as Map<String, dynamic>;
  print('   id=${commented['id']}, name=${commented['name']}');

  // 13. Pretty format
  print('\n13. Pretty format:');
  final pretty = encodePretty(user);
  print('   $pretty');

  final prettyTyped = encodePrettyTyped(user);
  print('   $prettyTyped');

  final prettyArr = encodePretty(users);
  print('   Pretty array:');
  for (final line in prettyArr.split('\n')) {
    print('   $line');
  }

  print('\n=== All examples passed! ===');
}
