import 'package:flutter_test/flutter_test.dart';
import 'package:appgrowth_studio/core/utils/csv_helper.dart';

void main() {
  group('CsvHelper RFC 4180 Tests', () {
    test('Encodes and escapes complex rows into CSV correctly', () {
      final rows = [
        ['Keyword', 'Cluster', 'Score', 'Notes'],
        ['best habit app', 'Tutorials', 85.5, 'Works well, highly rated'],
        ['app with "cloud sync"', 'Cloud', 70.0, 'Has commas, quotes "test"'],
      ];

      final csv = CsvHelper.encode(rows);
      expect(csv.contains('Keyword,Cluster,Score,Notes'), isTrue);
      expect(csv.contains('"Works well, highly rated"'), isTrue);
      expect(csv.contains('"app with ""cloud sync"""'), isTrue);
    });

    test('Decodes CSV string with quotes and commas properly', () {
      const csv = '''Keyword,Cluster,Score,Notes
best habit app,Tutorials,85.5,"Works well, highly rated"
"app with ""cloud sync""",Cloud,70.0,"Has commas, quotes"
''';

      final rows = CsvHelper.decode(csv);
      expect(rows.length, 3);
      expect(rows[0][0], 'Keyword');
      expect(rows[1][3], 'Works well, highly rated');
      expect(rows[2][0], 'app with "cloud sync"');
    });
  });
}
