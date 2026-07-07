import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/log_entry.dart';

/// Persists hex log and events to disk.
class SessionLogService {
  Future<File> defaultLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final logsDir = Directory(
      '${dir.path}${Platform.pathSeparator}pos_emulator_logs',
    );
    if (!logsDir.existsSync()) {
      logsDir.createSync(recursive: true);
    }
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return File('${logsDir.path}${Platform.pathSeparator}log_$stamp.txt');
  }

  Future<void> saveLogs({
    required File file,
    required List<LogEntry> entries,
    required String plainText,
  }) async {
    final buffer = StringBuffer()
      ..writeln('# POS Emulator Log')
      ..writeln('# Saved: ${DateTime.now().toIso8601String()}')
      ..writeln()
      ..writeln('## Plain text receipt')
      ..writeln(plainText)
      ..writeln()
      ..writeln('## Event log');

    for (final entry in entries) {
      buffer.writeln(
        '[${entry.formattedTime}] ${entry.kind.name}: ${entry.message}',
      );
      if (entry.bytes != null && entry.bytes!.isNotEmpty) {
        buffer.writeln('  HEX: ${_formatHex(entry.bytes!)}');
      }
    }

    await file.writeAsString(buffer.toString(), encoding: utf8);
  }

  String _formatHex(List<int> bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }
}
