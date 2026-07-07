enum LogEntryKind {
  rawHex,
  parsedText,
  command,
  event,
  error,
}

class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.kind,
    required this.message,
    this.bytes,
  });

  final DateTime timestamp;
  final LogEntryKind kind;
  final String message;
  final List<int>? bytes;

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}
