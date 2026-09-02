/// Output codecs for JSON, RFC 4180 CSV, GitHub Flavored Markdown tables, and typed objects.
library;

import 'dart:convert';

import '../../structured/mapper.dart';

/// Extension providing formatted exports for [StructuredHarvestResult].
extension HarvestResultCodecs on StructuredHarvestResult {
  /// Serializes the extraction data to a JSON string.
  ///
  /// When [includeProvenance] is true, adds a `_provenance` block detailing
  /// the [ExtractionSource] of each field.
  String toJsonString({bool includeProvenance = false, bool pretty = true}) {
    final payload = Map<String, dynamic>.from(data);

    if (includeProvenance) {
      payload['_provenance'] = coverage.satisfiedFields.map(
        (key, value) => MapEntry(key, value.name),
      );
    }

    final encoder = pretty
        ? const JsonEncoder.withIndent('  ')
        : const JsonEncoder();
    return encoder.convert(payload);
  }

  /// Exports extracted records to RFC 4180 compliant CSV.
  String toCsv({String separator = ','}) =>
      DataCodecs.toCsv(data, separator: separator);

  /// Formats records as a GitHub-Flavored Markdown table.
  String toMarkdownTable() => DataCodecs.toMarkdownTable(data);

  /// Deserializes the data map into a type-safe domain model [T].
  T toTyped<T>(T Function(Map<String, dynamic> json) fromJson) =>
      fromJson(data);

  /// Returns a clean, human-readable console string.
  String toPrettyString() => DataCodecs.toPrettyString(data);
}

/// Generic serialization codecs for data maps and entity lists.
abstract final class DataCodecs {
  /// Converts [data] into RFC 4180 compliant CSV.
  static String toCsv(Map<String, dynamic> data, {String separator = ','}) {
    final items = _extractItemList(data);
    if (items.isEmpty) return '';

    // Collect all distinct column headers in stable order
    final headers = <String>[];
    for (final item in items) {
      final flattened = _flatten(item);
      for (final key in flattened.keys) {
        if (!headers.contains(key)) {
          headers.add(key);
        }
      }
    }

    final sb = StringBuffer();
    // Header line
    sb.writeln(headers.map((h) => _escapeCsvCell(h, separator)).join(separator));

    // Data rows
    for (final item in items) {
      final flattened = _flatten(item);
      final row = headers.map((h) {
        final val = flattened[h];
        return _escapeCsvCell(val?.toString() ?? '', separator);
      });
      sb.writeln(row.join(separator));
    }

    return sb.toString();
  }

  /// Converts [data] into a GitHub Flavored Markdown table.
  static String toMarkdownTable(Map<String, dynamic> data) {
    final items = _extractItemList(data);
    if (items.isEmpty) return '_No data extracted._\n';

    final headers = <String>[];
    for (final item in items) {
      final flattened = _flatten(item);
      for (final key in flattened.keys) {
        if (!headers.contains(key)) {
          headers.add(key);
        }
      }
    }

    final sb = StringBuffer();
    // Header row
    sb.writeln('| ${headers.join(' | ')} |');
    // Separator row
    sb.writeln('| ${headers.map((_) => '---').join(' | ')} |');

    // Content rows
    for (final item in items) {
      final flattened = _flatten(item);
      final row = headers.map((h) {
        final val = flattened[h]?.toString().replaceAll('\n', ' ') ?? '';
        return val.replaceAll('|', r'\|');
      });
      sb.writeln('| ${row.join(' | ')} |');
    }

    return sb.toString();
  }

  /// Formats [data] for clean console debugging.
  static String toPrettyString(Map<String, dynamic> data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  static List<Map<String, dynamic>> _extractItemList(Map<String, dynamic> data) {
    if (data.containsKey('items') && data['items'] is List) {
      final list = data['items'] as List;
      return list
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
    }
    return [data];
  }

  static Map<String, dynamic> _flatten(
    Map<String, dynamic> map, [
    String prefix = '',
  ]) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (entry.value is Map<String, dynamic>) {
        result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
      } else {
        result[key] = entry.value;
      }
    }
    return result;
  }

  static String _escapeCsvCell(String cell, String separator) {
    final needsQuotes = cell.contains(separator) ||
        cell.contains('"') ||
        cell.contains('\n') ||
        cell.contains('\r');
    if (!needsQuotes) return cell;

    return '"${cell.replaceAll('"', '""')}"';
  }
}
