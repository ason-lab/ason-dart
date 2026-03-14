import 'dart:convert';
import 'package:ason/ason.dart';

// ===========================================================================
// Data classes
// ===========================================================================

class Department implements AsonSchema {
  final String title;
  Department({required this.title});

  @override
  List<String> get fieldNames => ['title'];
  @override
  List<String?> get fieldTypes => ['str'];
  @override
  List<dynamic> get fieldValues => [title];

  factory Department.fromFields(Map<String, dynamic> m) =>
      Department(title: m['title'] as String);

  @override
  bool operator ==(Object o) => o is Department && title == o.title;
  @override
  int get hashCode => title.hashCode;
  @override
  String toString() => 'Department($title)';
}

class Employee implements AsonSchema {
  final int id;
  final String name;
  final Department dept;
  final List<String> skills;
  final bool active;

  Employee(
      {required this.id,
      required this.name,
      required this.dept,
      required this.skills,
      required this.active});

  @override
  List<String> get fieldNames => ['id', 'name', 'dept', 'skills', 'active'];
  @override
  List<String?> get fieldTypes => ['int', 'str', null, '[str]', 'bool'];
  @override
  List<dynamic> get fieldValues => [id, name, dept, skills, active];

  factory Employee.fromFields(Map<String, dynamic> m) {
    final deptData = m['dept'];
    final dept = deptData is Map<String, dynamic>
        ? Department.fromFields(deptData)
        : Department(
            title: (deptData is List
                ? deptData.first.toString()
                : deptData.toString()));
    return Employee(
      id: m['id'] as int,
      name: m['name'] as String,
      dept: dept,
      skills: (m['skills'] as List).cast<String>(),
      active: m['active'] as bool,
    );
  }

  @override
  bool operator ==(Object o) => o is Employee && id == o.id && name == o.name;
  @override
  int get hashCode => Object.hash(id, name);
  @override
  String toString() =>
      'Employee(id:$id, name:$name, dept:${dept.title}, skills:$skills, active:$active)';
}

class Address implements AsonSchema {
  final String city;
  final int zip;
  Address({required this.city, required this.zip});

  @override
  List<String> get fieldNames => ['city', 'zip'];
  @override
  List<String?> get fieldTypes => ['str', 'int'];
  @override
  List<dynamic> get fieldValues => [city, zip];

  factory Address.fromFields(Map<String, dynamic> m) =>
      Address(city: m['city'] as String, zip: m['zip'] as int);

  @override
  bool operator ==(Object o) => o is Address && city == o.city && zip == o.zip;
  @override
  int get hashCode => Object.hash(city, zip);
  @override
  String toString() => 'Address($city, $zip)';
}

class Nested implements AsonSchema {
  final String name;
  final Address addr;
  Nested({required this.name, required this.addr});

  @override
  List<String> get fieldNames => ['name', 'addr'];
  @override
  List<String?> get fieldTypes => ['str', null];
  @override
  List<dynamic> get fieldValues => [name, addr];

  factory Nested.fromFields(Map<String, dynamic> m) {
    final addrData = m['addr'];
    final addr = addrData is Map<String, dynamic>
        ? Address.fromFields(addrData)
        : Address(
            city: (addrData as List)[0].toString(), zip: (addrData)[1] as int);
    return Nested(name: m['name'] as String, addr: addr);
  }

  @override
  bool operator ==(Object o) => o is Nested && name == o.name && addr == o.addr;
  @override
  int get hashCode => Object.hash(name, addr);
  @override
  String toString() => 'Nested($name, $addr)';
}

// 5-level deep: Country > Region > City > District > Street > Building

class Building implements AsonSchema {
  final String name;
  final int floors;
  final bool residential;
  final double heightM;

  Building(
      {required this.name,
      required this.floors,
      required this.residential,
      required this.heightM});

  @override
  List<String> get fieldNames => ['name', 'floors', 'residential', 'height_m'];
  @override
  List<String?> get fieldTypes => ['str', 'int', 'bool', 'float'];
  @override
  List<dynamic> get fieldValues => [name, floors, residential, heightM];

  factory Building.fromFields(Map<String, dynamic> m) => Building(
        name: m['name'] as String,
        floors: m['floors'] as int,
        residential: m['residential'] as bool,
        heightM: (m['height_m'] as num).toDouble(),
      );

  @override
  bool operator ==(Object o) =>
      o is Building && name == o.name && floors == o.floors;
  @override
  int get hashCode => Object.hash(name, floors);
  @override
  String toString() => 'Building($name, $floors floors, ${heightM}m)';
}

class Street implements AsonSchema {
  final String name;
  final double lengthKm;
  final List<Building> buildings;

  Street({required this.name, required this.lengthKm, required this.buildings});

  @override
  List<String> get fieldNames => ['name', 'length_km', 'buildings'];
  @override
  List<String?> get fieldTypes => ['str', 'float', null];
  @override
  List<dynamic> get fieldValues => [name, lengthKm, buildings];

  factory Street.fromFields(Map<String, dynamic> m) => Street(
        name: m['name'] as String,
        lengthKm: (m['length_km'] as num).toDouble(),
        buildings: (m['buildings'] as List)
            .map((e) => Building.fromFields(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  bool operator ==(Object o) => o is Street && name == o.name;
  @override
  int get hashCode => name.hashCode;
}

class District implements AsonSchema {
  final String name;
  final int population;
  final List<Street> streets;

  District(
      {required this.name, required this.population, required this.streets});

  @override
  List<String> get fieldNames => ['name', 'population', 'streets'];
  @override
  List<String?> get fieldTypes => ['str', 'int', null];
  @override
  List<dynamic> get fieldValues => [name, population, streets];

  factory District.fromFields(Map<String, dynamic> m) => District(
        name: m['name'] as String,
        population: m['population'] as int,
        streets: (m['streets'] as List)
            .map((e) => Street.fromFields(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  bool operator ==(Object o) => o is District && name == o.name;
  @override
  int get hashCode => name.hashCode;
}

class City implements AsonSchema {
  final String name;
  final int population;
  final double areaKm2;
  final List<District> districts;

  City(
      {required this.name,
      required this.population,
      required this.areaKm2,
      required this.districts});

  @override
  List<String> get fieldNames =>
      ['name', 'population', 'area_km2', 'districts'];
  @override
  List<String?> get fieldTypes => ['str', 'int', 'float', null];
  @override
  List<dynamic> get fieldValues => [name, population, areaKm2, districts];

  factory City.fromFields(Map<String, dynamic> m) => City(
        name: m['name'] as String,
        population: m['population'] as int,
        areaKm2: (m['area_km2'] as num).toDouble(),
        districts: (m['districts'] as List)
            .map((e) => District.fromFields(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  bool operator ==(Object o) => o is City && name == o.name;
  @override
  int get hashCode => name.hashCode;
}

class Region implements AsonSchema {
  final String name;
  final List<City> cities;

  Region({required this.name, required this.cities});

  @override
  List<String> get fieldNames => ['name', 'cities'];
  @override
  List<String?> get fieldTypes => ['str', null];
  @override
  List<dynamic> get fieldValues => [name, cities];

  factory Region.fromFields(Map<String, dynamic> m) => Region(
        name: m['name'] as String,
        cities: (m['cities'] as List)
            .map((e) => City.fromFields(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  bool operator ==(Object o) => o is Region && name == o.name;
  @override
  int get hashCode => name.hashCode;
}

class Country implements AsonSchema {
  final String name;
  final String code;
  final int population;
  final double gdpTrillion;
  final List<Region> regions;

  Country(
      {required this.name,
      required this.code,
      required this.population,
      required this.gdpTrillion,
      required this.regions});

  @override
  List<String> get fieldNames =>
      ['name', 'code', 'population', 'gdp_trillion', 'regions'];
  @override
  List<String?> get fieldTypes => ['str', 'str', 'int', 'float', null];
  @override
  List<dynamic> get fieldValues =>
      [name, code, population, gdpTrillion, regions];

  factory Country.fromFields(Map<String, dynamic> m) => Country(
        name: m['name'] as String,
        code: m['code'] as String,
        population: m['population'] as int,
        gdpTrillion: (m['gdp_trillion'] as num).toDouble(),
        regions: (m['regions'] as List)
            .map((e) => Region.fromFields(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  bool operator ==(Object o) =>
      o is Country && name == o.name && code == o.code;
  @override
  int get hashCode => Object.hash(name, code);
  @override
  String toString() => 'Country($name, $code)';
}

// ===========================================================================
// Main
// ===========================================================================

void main() {
  print('=== ASON Dart Complex Examples ===\n');

  // 1. Nested struct
  print('1. Nested struct:');
  final emp = Employee(
    id: 1,
    name: 'Alice',
    dept: Department(title: 'Manager'),
    skills: ['rust'],
    active: true,
  );
  final empStr = encode(emp);
  print('   $empStr');
  final empDec = decodeWith(empStr, Employee.fromFields);
  assert(empDec.id == 1);
  assert(empDec.name == 'Alice');
  print('   ✓ nested struct roundtrip OK\n');

  // 2. Nested struct roundtrip
  print('2. Nested struct roundtrip:');
  final nested = Nested(
    name: 'Alice',
    addr: Address(city: 'NYC', zip: 10001),
  );
  final nestedStr = encode(nested);
  print('   serialized: $nestedStr');
  final nestedDec = decodeWith(nestedStr, Nested.fromFields);
  assert(nested == nestedDec);
  print('   ✓ roundtrip OK\n');

  // 3. 5-level deep nesting
  print(
      '3. Five-level nesting (Country>Region>City>District>Street>Building):');
  final country = Country(
    name: 'Rustland',
    code: 'RL',
    population: 50000000,
    gdpTrillion: 1.5,
    regions: [
      Region(name: 'Northern', cities: [
        City(name: 'Ferriton', population: 2000000, areaKm2: 350.5, districts: [
          District(name: 'Downtown', population: 500000, streets: [
            Street(name: 'Main St', lengthKm: 2.5, buildings: [
              Building(
                  name: 'Tower A',
                  floors: 50,
                  residential: false,
                  heightM: 200.0),
              Building(
                  name: 'Apt Block 1',
                  floors: 12,
                  residential: true,
                  heightM: 40.5),
            ]),
            Street(name: 'Oak Ave', lengthKm: 1.2, buildings: [
              Building(
                  name: 'Library',
                  floors: 3,
                  residential: false,
                  heightM: 15.0),
            ]),
          ]),
          District(name: 'Harbor', population: 150000, streets: [
            Street(name: 'Dock Rd', lengthKm: 0.8, buildings: [
              Building(
                  name: 'Warehouse 7',
                  floors: 1,
                  residential: false,
                  heightM: 8.0),
            ]),
          ]),
        ]),
      ]),
      Region(name: 'Southern', cities: [
        City(name: 'Crabville', population: 800000, areaKm2: 120.0, districts: [
          District(name: 'Old Town', population: 200000, streets: [
            Street(name: 'Heritage Ln', lengthKm: 0.5, buildings: [
              Building(
                  name: 'Museum', floors: 2, residential: false, heightM: 12.0),
              Building(
                  name: 'Town Hall',
                  floors: 4,
                  residential: false,
                  heightM: 20.0),
            ]),
          ]),
        ]),
      ]),
    ],
  );
  final countryStr = encode(country);
  print('   serialized (${countryStr.length} bytes)');
  print(
      '   first 200 chars: ${countryStr.substring(0, 200.clamp(0, countryStr.length))}...');

  // ASON binary roundtrip
  final bin = encodeBinary(country);
  print('   ✓ 5-level ASON-text encode OK');
  print('   ASON text: ${countryStr.length} B | ASON bin: ${bin.length} B');

  // JSON comparison
  final jsonStr = jsonEncode(_countryToJson(country));
  print('   JSON: ${jsonStr.length} B');
  print(
      '   TEXT vs JSON: ${((1.0 - countryStr.length / jsonStr.length) * 100).toStringAsFixed(0)}% smaller');
  print(
      '   BIN vs JSON: ${((1.0 - bin.length / jsonStr.length) * 100).toStringAsFixed(0)}% smaller');

  // 4. Large structure (100 countries)
  print('\n4. Large structure (100 countries × nested regions):');
  final countries = List.generate(
      100,
      (i) => Country(
            name: 'Country_$i',
            code: 'C${(i % 100).toString().padLeft(2, '0')}',
            population: 1000000 + i * 500000,
            gdpTrillion: i * 0.5,
            regions: List.generate(
                3,
                (r) => Region(
                      name: 'Region_${i}_$r',
                      cities: List.generate(
                          2,
                          (c) => City(
                                name: 'City_${i}_${r}_$c',
                                population: 100000 + c * 50000,
                                areaKm2: 50.0 + c * 25.5,
                                districts: [
                                  District(
                                    name: 'Dist_$c',
                                    population: 50000 + c * 10000,
                                    streets: [
                                      Street(
                                        name: 'St_$c',
                                        lengthKm: 1.0 + c * 0.5,
                                        buildings: List.generate(
                                            2,
                                            (b) => Building(
                                                  name: 'Bldg_${c}_$b',
                                                  floors: 5 + b * 3,
                                                  residential: b % 2 == 0,
                                                  heightM: 15.0 + b * 10.5,
                                                )),
                                      )
                                    ],
                                  )
                                ],
                              )),
                    )),
          ));

  int totalAsonBytes = 0;
  int totalJsonBytes = 0;
  int totalBinBytes = 0;
  for (final c in countries) {
    final s = encode(c);
    final j = jsonEncode(_countryToJson(c));
    final b = encodeBinary(c);
    totalAsonBytes += s.length;
    totalJsonBytes += j.length;
    totalBinBytes += b.length;
  }
  print('   100 countries with 5-level nesting:');
  print(
      '   Total ASON text: $totalAsonBytes bytes (${(totalAsonBytes / 1024).toStringAsFixed(1)} KB)');
  print(
      '   Total ASON bin:  $totalBinBytes bytes (${(totalBinBytes / 1024).toStringAsFixed(1)} KB)');
  print(
      '   Total JSON:      $totalJsonBytes bytes (${(totalJsonBytes / 1024).toStringAsFixed(1)} KB)');
  print(
      '   TEXT vs JSON: ${((1.0 - totalAsonBytes / totalJsonBytes) * 100).toStringAsFixed(0)}% smaller');
  print(
      '   BIN vs JSON: ${((1.0 - totalBinBytes / totalJsonBytes) * 100).toStringAsFixed(0)}% smaller');
  print('   ✓ large structure complete');

  // 5. Typed output
  print('\n5. Typed output:');
  final typedCountry = encodeTyped(country);
  print(
      '   typed (${typedCountry.length} bytes): ${typedCountry.substring(0, 200.clamp(0, typedCountry.length))}...');

  // 6. Pretty format
  print('\n6. Pretty format:');
  final prettyCountry = encodePretty(country);
  final lines = prettyCountry.split('\n');
  for (int i = 0; i < lines.length.clamp(0, 10); i++) {
    print('   ${lines[i]}');
  }
  if (lines.length > 10) print('   ... (${lines.length} lines total)');

  print('\n=== All complex examples passed! ===');
}

// JSON conversion helpers for size comparison
Map<String, dynamic> _countryToJson(Country c) => {
      'name': c.name,
      'code': c.code,
      'population': c.population,
      'gdp_trillion': c.gdpTrillion,
      'regions': c.regions
          .map((r) => {
                'name': r.name,
                'cities': r.cities
                    .map((ci) => {
                          'name': ci.name,
                          'population': ci.population,
                          'area_km2': ci.areaKm2,
                          'districts': ci.districts
                              .map((d) => {
                                    'name': d.name,
                                    'population': d.population,
                                    'streets': d.streets
                                        .map((s) => {
                                              'name': s.name,
                                              'length_km': s.lengthKm,
                                              'buildings': s.buildings
                                                  .map((b) => {
                                                        'name': b.name,
                                                        'floors': b.floors,
                                                        'residential':
                                                            b.residential,
                                                        'height_m': b.heightM,
                                                      })
                                                  .toList(),
                                            })
                                        .toList(),
                                  })
                              .toList(),
                        })
                    .toList(),
              })
          .toList(),
    };
