/// Pure Dart RFC 4180 compliant CSV parser and generator.
class CsvHelper {
  /// Converts a list of records (each record is a list of cell values) into a CSV string.
  static String encode(List<List<dynamic>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      final line = row.map(_escapeCell).join(',');
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  /// Parses a CSV string into a list of string rows.
  static List<List<String>> decode(String csvContent) {
    final rows = <List<String>>[];
    if (csvContent.trim().isEmpty) return rows;

    final lines = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

    for (final rawLine in lines) {
      if (rawLine.trim().isEmpty) continue;
      final row = _parseLine(rawLine);
      rows.add(row);
    }

    return rows;
  }

  static String _escapeCell(dynamic val) {
    if (val == null) return '';
    final str = val.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      final escaped = str.replaceAll('"', '""');
      return '"$escaped"';
    }
    return str;
  }

  static List<String> _parseLine(String line) {
    final cells = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++; // skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        cells.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(char);
      }
    }

    cells.add(sb.toString().trim());
    return cells;
  }
}
