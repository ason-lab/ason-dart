import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ason/ason.dart';

class User implements AsonSchema {
  final int id;
  final String name;
  final String email;
  final int age;
  final double score;
  final bool active;
  final String role;
  final String city;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.age,
    required this.score,
    required this.active,
    required this.role,
    required this.city,
  });

  @override
  List<String> get fieldNames =>
      ['id', 'name', 'email', 'age', 'score', 'active', 'role', 'city'];

  @override
  List<String?> get fieldTypes =>
      ['int', 'str', 'str', 'int', 'float', 'bool', 'str', 'str'];

  @override
  List<dynamic> get fieldValues =>
      [id, name, email, age, score, active, role, city];

  static const binFields = [
    'id',
    'name',
    'email',
    'age',
    'score',
    'active',
    'role',
    'city',
  ];

  static const binTypes = [
    FieldType.int_,
    FieldType.string_,
    FieldType.string_,
    FieldType.int_,
    FieldType.double_,
    FieldType.bool_,
    FieldType.string_,
    FieldType.string_,
  ];

  factory User.fromFields(Map<String, dynamic> m) => User(
        id: (m['id'] as num).toInt(),
        name: m['name'] as String,
        email: m['email'] as String,
        age: (m['age'] as num).toInt(),
        score: (m['score'] as num).toDouble(),
        active: m['active'] as bool,
        role: m['role'] as String,
        city: m['city'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'age': age,
        'score': score,
        'active': active,
        'role': role,
        'city': city,
      };
}

class AllTypes implements AsonSchema {
  final bool b;
  final int i8v;
  final int i16v;
  final int i32v;
  final int i64v;
  final int u8v;
  final int u16v;
  final int u32v;
  final int u64v;
  final double f32v;
  final double f64v;
  final String s;
  final String note;
  final int rank;
  final List<int> vecInt;
  final List<String> vecStr;

  AllTypes({
    required this.b,
    required this.i8v,
    required this.i16v,
    required this.i32v,
    required this.i64v,
    required this.u8v,
    required this.u16v,
    required this.u32v,
    required this.u64v,
    required this.f32v,
    required this.f64v,
    required this.s,
    required this.note,
    required this.rank,
    required this.vecInt,
    required this.vecStr,
  });

  @override
  List<String> get fieldNames => [
        'b',
        'i8v',
        'i16v',
        'i32v',
        'i64v',
        'u8v',
        'u16v',
        'u32v',
        'u64v',
        'f32v',
        'f64v',
        's',
        'note',
        'rank',
        'vec_int',
        'vec_str',
      ];

  @override
  List<String?> get fieldTypes => [
        'bool',
        'int',
        'int',
        'int',
        'int',
        'int',
        'int',
        'int',
        'int',
        'float',
        'float',
        'str',
        'str',
        'int',
        '[int]',
        '[str]',
      ];

  @override
  List<dynamic> get fieldValues => [
        b,
        i8v,
        i16v,
        i32v,
        i64v,
        u8v,
        u16v,
        u32v,
        u64v,
        f32v,
        f64v,
        s,
        note,
        rank,
        vecInt,
        vecStr,
      ];

  static const binFields = [
    'b',
    'i8v',
    'i16v',
    'i32v',
    'i64v',
    'u8v',
    'u16v',
    'u32v',
    'u64v',
    'f32v',
    'f64v',
    's',
    'note',
    'rank',
    'vec_int',
    'vec_str',
  ];

  static const binTypes = [
    FieldType.bool_,
    FieldType.int_,
    FieldType.int_,
    FieldType.int_,
    FieldType.int_,
    FieldType.int_,
    FieldType.int_,
    FieldType.int_,
    FieldType.int_,
    FieldType.double_,
    FieldType.double_,
    FieldType.string_,
    FieldType.string_,
    FieldType.int_,
    FieldType.listInt,
    FieldType.listString,
  ];

  factory AllTypes.fromFields(Map<String, dynamic> m) => AllTypes(
        b: m['b'] as bool,
        i8v: (m['i8v'] as num).toInt(),
        i16v: (m['i16v'] as num).toInt(),
        i32v: (m['i32v'] as num).toInt(),
        i64v: (m['i64v'] as num).toInt(),
        u8v: (m['u8v'] as num).toInt(),
        u16v: (m['u16v'] as num).toInt(),
        u32v: (m['u32v'] as num).toInt(),
        u64v: (m['u64v'] as num).toInt(),
        f32v: (m['f32v'] as num).toDouble(),
        f64v: (m['f64v'] as num).toDouble(),
        s: m['s'] as String,
        note: m['note'] as String,
        rank: (m['rank'] as num).toInt(),
        vecInt: _asList(m['vec_int']).map((e) => (e as num).toInt()).toList(),
        vecStr: _asList(m['vec_str']).map((e) => e.toString()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'b': b,
        'i8v': i8v,
        'i16v': i16v,
        'i32v': i32v,
        'i64v': i64v,
        'u8v': u8v,
        'u16v': u16v,
        'u32v': u32v,
        'u64v': u64v,
        'f32v': f32v,
        'f64v': f64v,
        's': s,
        'note': note,
        'rank': rank,
        'vec_int': vecInt,
        'vec_str': vecStr,
      };
}

class Task implements AsonSchema {
  final int id;
  final String title;
  final int priority;
  final bool done;
  final double hours;

  Task({
    required this.id,
    required this.title,
    required this.priority,
    required this.done,
    required this.hours,
  });

  @override
  List<String> get fieldNames => ['id', 'title', 'priority', 'done', 'hours'];

  @override
  List<String?> get fieldTypes => ['int', 'str', 'int', 'bool', 'float'];

  @override
  List<dynamic> get fieldValues => [id, title, priority, done, hours];

  factory Task.fromFields(Map<String, dynamic> m) => Task(
        id: (m['id'] as num).toInt(),
        title: m['title'] as String,
        priority: (m['priority'] as num).toInt(),
        done: m['done'] as bool,
        hours: (m['hours'] as num).toDouble(),
      );

  factory Task.fromValue(dynamic value) {
    if (value is Map<String, dynamic>) return Task.fromFields(value);
    final items = _asList(value);
    return Task(
      id: (items[0] as num).toInt(),
      title: items[1] as String,
      priority: (items[2] as num).toInt(),
      done: items[3] as bool,
      hours: (items[4] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'priority': priority,
        'done': done,
        'hours': hours,
      };
}

class Project implements AsonSchema {
  final String name;
  final double budget;
  final bool active;
  final List<Task> tasks;

  Project({
    required this.name,
    required this.budget,
    required this.active,
    required this.tasks,
  });

  @override
  List<String> get fieldNames => ['name', 'budget', 'active', 'tasks'];

  @override
  List<String?> get fieldTypes => ['str', 'float', 'bool', null];

  @override
  List<dynamic> get fieldValues => [name, budget, active, tasks];

  factory Project.fromFields(Map<String, dynamic> m) => Project(
        name: m['name'] as String,
        budget: (m['budget'] as num).toDouble(),
        active: m['active'] as bool,
        tasks: _asList(m['tasks']).map(Task.fromValue).toList(),
      );

  factory Project.fromValue(dynamic value) {
    if (value is Map<String, dynamic>) return Project.fromFields(value);
    final items = _asList(value);
    return Project(
      name: items[0] as String,
      budget: (items[1] as num).toDouble(),
      active: items[2] as bool,
      tasks: _asList(items[3]).map(Task.fromValue).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'budget': budget,
        'active': active,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };
}

class Team implements AsonSchema {
  final String name;
  final String lead;
  final int size;
  final List<Project> projects;

  Team({
    required this.name,
    required this.lead,
    required this.size,
    required this.projects,
  });

  @override
  List<String> get fieldNames => ['name', 'lead', 'size', 'projects'];

  @override
  List<String?> get fieldTypes => ['str', 'str', 'int', null];

  @override
  List<dynamic> get fieldValues => [name, lead, size, projects];

  factory Team.fromFields(Map<String, dynamic> m) => Team(
        name: m['name'] as String,
        lead: m['lead'] as String,
        size: (m['size'] as num).toInt(),
        projects: _asList(m['projects']).map(Project.fromValue).toList(),
      );

  factory Team.fromValue(dynamic value) {
    if (value is Map<String, dynamic>) return Team.fromFields(value);
    final items = _asList(value);
    return Team(
      name: items[0] as String,
      lead: items[1] as String,
      size: (items[2] as num).toInt(),
      projects: _asList(items[3]).map(Project.fromValue).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'lead': lead,
        'size': size,
        'projects': projects.map((p) => p.toJson()).toList(),
      };
}

class Division implements AsonSchema {
  final String name;
  final String location;
  final int headcount;
  final List<Team> teams;

  Division({
    required this.name,
    required this.location,
    required this.headcount,
    required this.teams,
  });

  @override
  List<String> get fieldNames => ['name', 'location', 'headcount', 'teams'];

  @override
  List<String?> get fieldTypes => ['str', 'str', 'int', null];

  @override
  List<dynamic> get fieldValues => [name, location, headcount, teams];

  factory Division.fromFields(Map<String, dynamic> m) => Division(
        name: m['name'] as String,
        location: m['location'] as String,
        headcount: (m['headcount'] as num).toInt(),
        teams: _asList(m['teams']).map(Team.fromValue).toList(),
      );

  factory Division.fromValue(dynamic value) {
    if (value is Map<String, dynamic>) return Division.fromFields(value);
    final items = _asList(value);
    return Division(
      name: items[0] as String,
      location: items[1] as String,
      headcount: (items[2] as num).toInt(),
      teams: _asList(items[3]).map(Team.fromValue).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'location': location,
        'headcount': headcount,
        'teams': teams.map((t) => t.toJson()).toList(),
      };
}

class Company implements AsonSchema {
  final String name;
  final int founded;
  final double revenueM;
  final bool public_;
  final List<Division> divisions;
  final List<String> tags;

  Company({
    required this.name,
    required this.founded,
    required this.revenueM,
    required this.public_,
    required this.divisions,
    required this.tags,
  });

  @override
  List<String> get fieldNames =>
      ['name', 'founded', 'revenue_m', 'public', 'divisions', 'tags'];

  @override
  List<String?> get fieldTypes =>
      ['str', 'int', 'float', 'bool', null, '[str]'];

  @override
  List<dynamic> get fieldValues =>
      [name, founded, revenueM, public_, divisions, tags];

  factory Company.fromFields(Map<String, dynamic> m) => Company(
        name: m['name'] as String,
        founded: (m['founded'] as num).toInt(),
        revenueM: (m['revenue_m'] as num).toDouble(),
        public_: m['public'] as bool,
        divisions: _asList(m['divisions']).map(Division.fromValue).toList(),
        tags: _asList(m['tags']).map((e) => e.toString()).toList(),
      );

  factory Company.fromValue(dynamic value) {
    if (value is Map<String, dynamic>) return Company.fromFields(value);
    final items = _asList(value);
    return Company(
      name: items[0] as String,
      founded: (items[1] as num).toInt(),
      revenueM: (items[2] as num).toDouble(),
      public_: items[3] as bool,
      divisions: _asList(items[4]).map(Division.fromValue).toList(),
      tags: _asList(items[5]).map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'founded': founded,
        'revenue_m': revenueM,
        'public': public_,
        'divisions': divisions.map((d) => d.toJson()).toList(),
        'tags': tags,
      };
}

class BenchResult {
  final String name;
  final double jsonSerMs;
  final double asonSerMs;
  final double binSerMs;
  final double jsonDeMs;
  final double asonDeMs;
  final double binDeMs;
  final int jsonBytes;
  final int asonBytes;
  final int binBytes;

  BenchResult({
    required this.name,
    required this.jsonSerMs,
    required this.asonSerMs,
    required this.binSerMs,
    required this.jsonDeMs,
    required this.asonDeMs,
    required this.binDeMs,
    required this.jsonBytes,
    required this.asonBytes,
    required this.binBytes,
  });

  void print_() {
    print('  $name');
    print(
      '    Serialize:   JSON ${jsonSerMs.toStringAsFixed(2)}ms/${jsonBytes}B | '
      'ASON ${asonSerMs.toStringAsFixed(2)}ms(${_formatRatio(jsonSerMs, asonSerMs)})/${asonBytes}B(${_formatPercent(asonBytes, jsonBytes)}) | '
      'BIN ${binSerMs.toStringAsFixed(2)}ms(${_formatRatio(jsonSerMs, binSerMs)})/${binBytes}B(${_formatPercent(binBytes, jsonBytes)})',
    );
    print(
      '    Deserialize: JSON ${jsonDeMs.toStringAsFixed(2).padLeft(8)}ms | '
      'ASON ${asonDeMs.toStringAsFixed(2).padLeft(8)}ms(${_formatRatio(jsonDeMs, asonDeMs)}) | '
      'BIN ${binDeMs.toStringAsFixed(2).padLeft(8)}ms(${_formatRatio(jsonDeMs, binDeMs)})',
    );
  }
}

double _measureMs(void Function() fn) {
  final sw = Stopwatch()..start();
  fn();
  sw.stop();
  return sw.elapsedMicroseconds / 1000.0;
}

String _formatRatio(double base, double target) {
  if (target <= 0) return 'infx';
  final s = (base / target).toStringAsFixed(1);
  return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}x';
}

String _formatPercent(int part, int whole) {
  if (whole <= 0) return '0%';
  final s = (part * 100.0 / whole).toStringAsFixed(1);
  return s.endsWith('.0') ? '${s.substring(0, s.length - 2)}%' : '$s%';
}

void _printSection(String title, int width) {
  final line = '─' * (width - 2);
  print('┌$line┐');
  print('│ ${title.padRight(width - 4)} │');
  print('└$line┘');
}

List<dynamic> _asList(dynamic value) => (value as List).cast<dynamic>();

Map<String, dynamic> _asFieldBag(dynamic value) => value is Map<String, dynamic>
    ? value
    : Map<String, dynamic>.from(value as Map);

List<User> _decodeJsonUsers(String json) {
  final raw = jsonDecode(json) as List;
  return raw.map((e) => User.fromFields(_asFieldBag(e))).toList();
}

List<AllTypes> _decodeJsonAllTypes(String json) {
  final raw = jsonDecode(json) as List;
  return raw.map((e) => AllTypes.fromFields(_asFieldBag(e))).toList();
}

List<Company> _decodeJsonCompanies(String json) {
  final raw = jsonDecode(json) as List;
  return raw.map((e) => Company.fromFields(_asFieldBag(e))).toList();
}

List<User> generateUsers(int n) {
  const names = [
    'Alice',
    'Bob',
    'Carol',
    'David',
    'Eve',
    'Frank',
    'Grace',
    'Hank'
  ];
  const roles = ['engineer', 'designer', 'manager', 'analyst'];
  const cities = ['NYC', 'LA', 'Chicago', 'Houston', 'Phoenix'];
  return List.generate(
    n,
    (i) => User(
      id: i,
      name: names[i % names.length],
      email: '${names[i % names.length].toLowerCase()}@example.com',
      age: 25 + (i % 40),
      score: 50.0 + (i % 50) + 0.5,
      active: i % 3 != 0,
      role: roles[i % roles.length],
      city: cities[i % cities.length],
    ),
  );
}

List<AllTypes> generateAllTypes(int n) {
  return List.generate(
    n,
    (i) => AllTypes(
      b: i % 2 == 0,
      i8v: i % 128,
      i16v: -i,
      i32v: i * 1000,
      i64v: i * 100000,
      u8v: i % 255,
      u16v: i % 65535,
      u32v: i * 7919,
      u64v: i * 1000000007,
      f32v: i * 1.5,
      f64v: i * 0.25 + 0.5,
      s: 'item_$i',
      note: 'note_$i',
      rank: i % 10,
      vecInt: [i, i + 1, i + 2],
      vecStr: ['tag${i % 5}', 'cat${i % 3}'],
    ),
  );
}

List<Company> generateCompanies(int n) {
  const locations = ['NYC', 'London', 'Tokyo', 'Berlin'];
  const leads = ['Alice', 'Bob', 'Carol', 'David'];
  return List.generate(
    n,
    (i) => Company(
      name: 'Corp_$i',
      founded: 1990 + (i % 35),
      revenueM: 10.0 + i * 5.5,
      public_: i.isEven,
      divisions: List.generate(
        2,
        (d) => Division(
          name: 'Div_${i}_$d',
          location: locations[d % locations.length],
          headcount: 50 + d * 20,
          teams: List.generate(
            2,
            (t) => Team(
              name: 'Team_${i}_${d}_$t',
              lead: leads[t % leads.length],
              size: 5 + t * 2,
              projects: List.generate(
                3,
                (p) => Project(
                  name: 'Proj_${t}_$p',
                  budget: 100.0 + p * 50.5,
                  active: p.isEven,
                  tasks: List.generate(
                    4,
                    (tk) => Task(
                      id: i * 100 + d * 10 + t * 5 + tk,
                      title: 'Task_$tk',
                      priority: tk % 3 + 1,
                      done: tk.isEven,
                      hours: 2.0 + tk * 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      tags: ['enterprise', 'tech', 'sector_${i % 5}'],
    ),
  );
}

void _warmUp() {
  print('Warming up...');
  final users = generateUsers(100);
  final allTypes = generateAllTypes(50);
  final companies = generateCompanies(10);
  final userJson = jsonEncode(users.map((u) => u.toJson()).toList());
  final userAson = encode(users);
  final userBin = encodeBinary(users);
  final allJson = jsonEncode(allTypes.map((a) => a.toJson()).toList());
  final allAson = encode(allTypes);
  final allBin = encodeBinary(allTypes);
  final companyJson = jsonEncode(companies.map((c) => c.toJson()).toList());
  final companyAson = encode(companies);
  final companyBin = encodeBinary(companies);

  for (int i = 0; i < 50; i++) {
    jsonEncode(users.map((u) => u.toJson()).toList());
    encode(users);
    encodeBinary(users);
    _decodeJsonUsers(userJson);
    decodeListWith(userAson, User.fromFields);
    decodeBinaryListWith(
        userBin, User.binFields, User.binTypes, User.fromFields);
  }

  for (int i = 0; i < 20; i++) {
    jsonEncode(allTypes.map((a) => a.toJson()).toList());
    encode(allTypes);
    encodeBinary(allTypes);
    _decodeJsonAllTypes(allJson);
    decodeListWith(allAson, AllTypes.fromFields);
    decodeBinaryListWith(
      allBin,
      AllTypes.binFields,
      AllTypes.binTypes,
      AllTypes.fromFields,
    );
  }

  for (int i = 0; i < 10; i++) {
    jsonEncode(companies.map((c) => c.toJson()).toList());
    encode(companies);
    encodeBinary(companies);
    _decodeJsonCompanies(companyJson);
    decodeListWith(companyAson, Company.fromFields);
    _BenchDecode.decodeCompanyListBinary(companyBin);
  }
  print('Warmup complete.');
}

BenchResult benchFlat(int count, int iterations) {
  final users = generateUsers(count);
  final jsonList = users.map((u) => u.toJson()).toList();
  String jsonStr = '';
  String asonStr = '';
  Uint8List binData = Uint8List(0);

  final jsonSerMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      jsonStr = jsonEncode(jsonList);
    }
  });
  final asonSerMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      asonStr = encode(users);
    }
  });
  final binSerMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      binData = encodeBinary(users);
    }
  });
  final jsonDeMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      _decodeJsonUsers(jsonStr);
    }
  });
  final asonDeMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      decodeListWith(asonStr, User.fromFields);
    }
  });
  final binDeMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      decodeBinaryListWith(
          binData, User.binFields, User.binTypes, User.fromFields);
    }
  });

  return BenchResult(
    name: 'Flat struct × $count (8 fields, vec)',
    jsonSerMs: jsonSerMs,
    asonSerMs: asonSerMs,
    binSerMs: binSerMs,
    jsonDeMs: jsonDeMs,
    asonDeMs: asonDeMs,
    binDeMs: binDeMs,
    jsonBytes: utf8.encode(jsonStr).length,
    asonBytes: utf8.encode(asonStr).length,
    binBytes: binData.length,
  );
}

BenchResult benchAllTypes(int count, int iterations) {
  final items = generateAllTypes(count);
  final jsonList = items.map((a) => a.toJson()).toList();
  String jsonStr = '';
  String asonStr = '';
  Uint8List binData = Uint8List(0);

  final jsonSerMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      jsonStr = jsonEncode(jsonList);
    }
  });
  final asonSerMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      asonStr = encode(items);
    }
  });
  final binSerMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      binData = encodeBinary(items);
    }
  });
  final jsonDeMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      _decodeJsonAllTypes(jsonStr);
    }
  });
  final asonDeMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      decodeListWith(asonStr, AllTypes.fromFields);
    }
  });
  final binDeMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      decodeBinaryListWith(
        binData,
        AllTypes.binFields,
        AllTypes.binTypes,
        AllTypes.fromFields,
      );
    }
  });

  return BenchResult(
    name: 'All-types struct × $count (16 fields, vec)',
    jsonSerMs: jsonSerMs,
    asonSerMs: asonSerMs,
    binSerMs: binSerMs,
    jsonDeMs: jsonDeMs,
    asonDeMs: asonDeMs,
    binDeMs: binDeMs,
    jsonBytes: utf8.encode(jsonStr).length,
    asonBytes: utf8.encode(asonStr).length,
    binBytes: binData.length,
  );
}

BenchResult benchDeep(int count, int iterations) {
  final companies = generateCompanies(count);
  final jsonList = companies.map((c) => c.toJson()).toList();
  String jsonStr = '';
  String asonStr = '';
  Uint8List binData = Uint8List(0);

  final jsonSerMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      jsonStr = jsonEncode(jsonList);
    }
  });
  final asonSerMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      asonStr = encode(companies);
    }
  });
  final binSerMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      binData = encodeBinary(companies);
    }
  });
  final jsonDeMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      _decodeJsonCompanies(jsonStr);
    }
  });
  final asonDeMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      decodeListWith(asonStr, Company.fromFields);
    }
  });
  final binDeMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      _BenchDecode.decodeCompanyListBinary(binData);
    }
  });

  return BenchResult(
    name: '5-level deep × $count (Company>Division>Team>Project>Task)',
    jsonSerMs: jsonSerMs,
    asonSerMs: asonSerMs,
    binSerMs: binSerMs,
    jsonDeMs: jsonDeMs,
    asonDeMs: asonDeMs,
    binDeMs: binDeMs,
    jsonBytes: utf8.encode(jsonStr).length,
    asonBytes: utf8.encode(asonStr).length,
    binBytes: binData.length,
  );
}

(double, double) benchSingleRoundtrip(int iterations) {
  final users = generateUsers(1);
  final user = users.first;
  final jsonObject = user.toJson();

  final asonMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      final s = encode(user);
      decodeWith(s, User.fromFields);
    }
  });
  final jsonMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      final s = jsonEncode(jsonObject);
      User.fromFields(_asFieldBag(jsonDecode(s)));
    }
  });
  return (asonMs, jsonMs);
}

(double, double) benchDeepSingleRoundtrip(int iterations) {
  final company = generateCompanies(1).first;
  final jsonObject = company.toJson();

  final asonMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      final s = encode(company);
      decodeWith(s, Company.fromFields);
    }
  });
  final jsonMs = _measureMs(() {
    for (int i = 0; i < iterations; i++) {
      final s = jsonEncode(jsonObject);
      Company.fromFields(_asFieldBag(jsonDecode(s)));
    }
  });
  return (asonMs, jsonMs);
}

class _BenchDecode {
  static List<Company> decodeCompanyListBinary(Uint8List data) {
    final reader = _BenchBinReader(data);
    final count = reader.readU32();
    final result = <Company>[];
    for (int i = 0; i < count; i++) {
      result.add(_readCompany(reader));
    }
    return result;
  }

  static Company _readCompany(_BenchBinReader r) => Company(
        name: r.readString(),
        founded: r.readI64(),
        revenueM: r.readF64(),
        public_: r.readBool(),
        divisions: _readList(r, _readDivision),
        tags: _readList(r, (rr) => rr.readString()),
      );

  static Division _readDivision(_BenchBinReader r) => Division(
        name: r.readString(),
        location: r.readString(),
        headcount: r.readI64(),
        teams: _readList(r, _readTeam),
      );

  static Team _readTeam(_BenchBinReader r) => Team(
        name: r.readString(),
        lead: r.readString(),
        size: r.readI64(),
        projects: _readList(r, _readProject),
      );

  static Project _readProject(_BenchBinReader r) => Project(
        name: r.readString(),
        budget: r.readF64(),
        active: r.readBool(),
        tasks: _readList(r, _readTask),
      );

  static Task _readTask(_BenchBinReader r) => Task(
        id: r.readI64(),
        title: r.readString(),
        priority: r.readI64(),
        done: r.readBool(),
        hours: r.readF64(),
      );

  static List<T> _readList<T>(
      _BenchBinReader r, T Function(_BenchBinReader) readItem) {
    final count = r.readU32();
    return List.generate(count, (_) => readItem(r));
  }
}

class _BenchBinReader {
  final Uint8List data;
  late final ByteData view;
  int pos = 0;

  _BenchBinReader(this.data) {
    view = ByteData.sublistView(data);
  }

  int readU32() {
    final value = view.getUint32(pos, Endian.little);
    pos += 4;
    return value;
  }

  int readI64() {
    final value = view.getInt64(pos, Endian.little);
    pos += 8;
    return value;
  }

  double readF64() {
    final value = view.getFloat64(pos, Endian.little);
    pos += 8;
    return value;
  }

  bool readBool() => data[pos++] != 0;

  String readString() {
    final len = readU32();
    final bytes = Uint8List.sublistView(data, pos, pos + len);
    pos += len;
    return utf8.decode(bytes);
  }
}

void main() {
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║            ASON vs JSON Comprehensive Benchmark              ║');
  print('╚══════════════════════════════════════════════════════════════╝');
  print('');
  print('System: ${Platform.operatingSystemVersion}');
  print('Dart: ${Platform.version.split(" ").take(2).join(" ")}');
  print('Iterations per test: 100');

  _warmUp();

  print('');
  _printSection('Section 1: Flat Struct (schema-driven vec)', 47);
  print('');
  for (final count in [100, 500, 1000, 5000]) {
    benchFlat(count, 100).print_();
    print('');
  }

  _printSection('Section 2: All-Types Struct (16 fields)', 48);
  print('');
  for (final count in [100, 500]) {
    benchAllTypes(count, 100).print_();
    print('');
  }

  _printSection('Section 3: 5-Level Deep Nesting (Company hierarchy)', 60);
  print('');
  for (final count in [10, 50, 100]) {
    benchDeep(count, 50).print_();
    print('');
  }

  _printSection('Section 4: Single Struct Roundtrip (10000x)', 48);
  print('');
  final flatRoundtrip = benchSingleRoundtrip(10000);
  print(
    '  Flat:  ASON ${flatRoundtrip.$1.toStringAsFixed(2).padLeft(8)}ms | '
    'JSON ${flatRoundtrip.$2.toStringAsFixed(2).padLeft(8)}ms | '
    'ratio ${(flatRoundtrip.$2 / flatRoundtrip.$1).toStringAsFixed(2)}x',
  );
  final deepRoundtrip = benchDeepSingleRoundtrip(10000);
  print(
    '  Deep:  ASON ${deepRoundtrip.$1.toStringAsFixed(2).padLeft(8)}ms | '
    'JSON ${deepRoundtrip.$2.toStringAsFixed(2).padLeft(8)}ms | '
    'ratio ${(deepRoundtrip.$2 / deepRoundtrip.$1).toStringAsFixed(2)}x',
  );

  print('');
  _printSection('Section 5: Large Payload (10k records)', 48);
  print('');
  print('  (10 iterations for large payload)');
  benchFlat(10000, 10).print_();

  print('');
  _printSection('Section 6: Annotated vs Unannotated Schema (deserialize)', 64);
  print('');
  {
    final users = generateUsers(1000);
    final untyped = encode(users);
    final typed = encodeTyped(users);
    const iterations = 200;
    final untypedMs = _measureMs(() {
      for (int i = 0; i < iterations; i++) {
        decodeListWith(untyped, User.fromFields);
      }
    });
    final typedMs = _measureMs(() {
      for (int i = 0; i < iterations; i++) {
        decodeListWith(typed, User.fromFields);
      }
    });
    print('  Flat struct × 1000 ($iterations iters, deserialize only)');
    print(
        '    Unannotated: ${untypedMs.toStringAsFixed(2).padLeft(8)}ms  (${utf8.encode(untyped).length} B)');
    print(
        '    Annotated:   ${typedMs.toStringAsFixed(2).padLeft(8)}ms  (${utf8.encode(typed).length} B)');
    print(
        '    Ratio: ${(untypedMs / typedMs).toStringAsFixed(3)}x (unannotated / annotated)');
  }

  print('');
  _printSection('Section 7: Annotated vs Unannotated Schema (serialize)', 62);
  print('');
  {
    final users = generateUsers(1000);
    const iterations = 200;
    String untyped = '';
    String typed = '';
    final untypedMs = _measureMs(() {
      for (int i = 0; i < iterations; i++) {
        untyped = encode(users);
      }
    });
    final typedMs = _measureMs(() {
      for (int i = 0; i < iterations; i++) {
        typed = encodeTyped(users);
      }
    });
    print('  Flat struct × 1000 ($iterations iters, serialize only)');
    print(
        '    Unannotated: ${untypedMs.toStringAsFixed(2).padLeft(8)}ms  (${utf8.encode(untyped).length} B)');
    print(
        '    Annotated:   ${typedMs.toStringAsFixed(2).padLeft(8)}ms  (${utf8.encode(typed).length} B)');
    print(
        '    Ratio: ${(untypedMs / typedMs).toStringAsFixed(3)}x (unannotated / annotated)');
  }

  print('');
  _printSection('Section 8: Throughput Summary', 48);
  print('');
  {
    final users = generateUsers(1000);
    final json = jsonEncode(users.map((u) => u.toJson()).toList());
    final asonText = encode(users);
    const iterations = 100;
    final jsonSerSecs = _measureMs(() {
          for (int i = 0; i < iterations; i++) {
            jsonEncode(users.map((u) => u.toJson()).toList());
          }
        }) /
        1000.0;
    final asonSerSecs = _measureMs(() {
          for (int i = 0; i < iterations; i++) {
            encode(users);
          }
        }) /
        1000.0;
    final jsonDeSecs = _measureMs(() {
          for (int i = 0; i < iterations; i++) {
            _decodeJsonUsers(json);
          }
        }) /
        1000.0;
    final asonDeSecs = _measureMs(() {
          for (int i = 0; i < iterations; i++) {
            decodeListWith(asonText, User.fromFields);
          }
        }) /
        1000.0;

    final totalRecords = 1000.0 * iterations;
    print('  Serialize throughput (1000 records × $iterations iters):');
    print(
        '    JSON: ${(totalRecords / jsonSerSecs).toStringAsFixed(0)} records/s');
    print(
        '    ASON: ${(totalRecords / asonSerSecs).toStringAsFixed(0)} records/s');
    print('    Speed: ${(jsonSerSecs / asonSerSecs).toStringAsFixed(2)}x');
    print('  Deserialize throughput:');
    print(
        '    JSON: ${(totalRecords / jsonDeSecs).toStringAsFixed(0)} records/s');
    print(
        '    ASON: ${(totalRecords / asonDeSecs).toStringAsFixed(0)} records/s');
    print('    Speed: ${(jsonDeSecs / asonDeSecs).toStringAsFixed(2)}x');
  }

  print('');
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║                    Benchmark Complete                        ║');
  print('╚══════════════════════════════════════════════════════════════╝');
}
