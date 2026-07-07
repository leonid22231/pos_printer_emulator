import '../../models/log_entry.dart';
import '../../models/receipt_document.dart';
import '../../models/receipt_element.dart';
import 'escpos_text_decoder.dart';

enum _ParsePhase {
  normal,
  esc,
  gs,
  fs,
  escBang,
  escAlign,
  escBold,
  escFeed,
  escLineSpacing,
  escCodePage,
  escCharset,
  fsBang,
  gsRasterMode,
  gsRasterSubcommand,
  gsRasterWidthLow,
  gsRasterWidthHigh,
  gsRasterHeightLow,
  gsRasterHeightHigh,
  gsRasterData,
  gsCut,
  gsBang,
}

/// Streaming ESC/POS parser. Accepts arbitrary byte chunks.
class EscPosParser {
  EscPosParser({EscPosTextDecoder? textDecoder})
      : _textDecoder = textDecoder ?? EscPosTextDecoder();

  final EscPosTextDecoder _textDecoder;
  _ParsePhase _phase = _ParsePhase.normal;
  TextStyleState _style = TextStyleState.initial;
  ReceiptDocument _document = const ReceiptDocument();
  final List<LogEntry> _pendingLogs = [];

  String _currentLine = '';
  int? _rasterWidthBytes;
  int? _rasterHeight;
  final List<int> _rasterData = [];
  int _rasterBytesExpected = 0;

  ReceiptDocument get document => _document;
  List<LogEntry> consumeLogs() {
    final logs = List<LogEntry>.from(_pendingLogs);
    _pendingLogs.clear();
    return logs;
  }

  void reset() {
    _phase = _ParsePhase.normal;
    _style = TextStyleState.initial;
    _document = const ReceiptDocument();
    _pendingLogs.clear();
    _currentLine = '';
    _textDecoder.reset();
    _resetRaster();
  }

  void feed(List<int> chunk) {
    for (final byte in chunk) {
      _processByte(byte);
    }
  }

  void _processByte(int byte) {
    switch (_phase) {
      case _ParsePhase.normal:
        _handleNormal(byte);
      case _ParsePhase.esc:
        _handleEsc(byte);
      case _ParsePhase.gs:
        _handleGs(byte);
      case _ParsePhase.fs:
        _handleFs(byte);
      case _ParsePhase.escBang:
        _handleEscBang(byte);
      case _ParsePhase.escAlign:
        _handleEscAlign(byte);
      case _ParsePhase.escBold:
        _handleEscBold(byte);
      case _ParsePhase.escFeed:
        _handleEscFeed(byte);
      case _ParsePhase.escLineSpacing:
        _handleEscLineSpacing(byte);
      case _ParsePhase.escCodePage:
        _handleEscCodePage(byte);
      case _ParsePhase.escCharset:
        _handleEscCharset(byte);
      case _ParsePhase.fsBang:
        _handleFsBang(byte);
      case _ParsePhase.gsRasterMode:
        _handleGsRasterMode(byte);
      case _ParsePhase.gsRasterSubcommand:
        _handleGsRasterSubcommand(byte);
      case _ParsePhase.gsRasterWidthLow:
        _rasterWidthBytes = byte;
        _phase = _ParsePhase.gsRasterWidthHigh;
      case _ParsePhase.gsRasterWidthHigh:
        _rasterWidthBytes = ((_rasterWidthBytes ?? 0) & 0xFF) | (byte << 8);
        _phase = _ParsePhase.gsRasterHeightLow;
      case _ParsePhase.gsRasterHeightLow:
        _rasterHeight = byte;
        _phase = _ParsePhase.gsRasterHeightHigh;
      case _ParsePhase.gsRasterHeightHigh:
        _rasterHeight = ((_rasterHeight ?? 0) & 0xFF) | (byte << 8);
        _startRasterDataCollection();
      case _ParsePhase.gsRasterData:
        _rasterData.add(byte);
        if (_rasterData.length >= _rasterBytesExpected) {
          _finishRaster();
        }
      case _ParsePhase.gsCut:
        _handleGsCut(byte);
      case _ParsePhase.gsBang:
        _handleGsBang(byte);
    }
  }

  void _handleNormal(int byte) {
    if (byte == 0x1B) {
      _phase = _ParsePhase.esc;
      return;
    }
    if (byte == 0x1D) {
      _phase = _ParsePhase.gs;
      return;
    }
    if (byte == 0x1C) {
      _phase = _ParsePhase.fs;
      return;
    }
    if (byte == 0x0A) {
      _flushLineOrFeed();
      return;
    }
    if (byte == 0x0D) {
      return;
    }
    if (byte == 0x09) {
      _currentLine += '    ';
      return;
    }
    _currentLine += _textDecoder.feed(byte);
  }

  void _handleEsc(int byte) {
    switch (byte) {
      case 0x40:
        _logCommand('ESC @', 'Initialize printer');
        _flushLine();
        _style = TextStyleState.initial;
        _textDecoder.reset();
        _phase = _ParsePhase.normal;
      case 0x21:
        _phase = _ParsePhase.escBang;
      case 0x61:
        _phase = _ParsePhase.escAlign;
      case 0x45:
        _phase = _ParsePhase.escBold;
      case 0x64:
        _phase = _ParsePhase.escFeed;
      case 0x33:
        _phase = _ParsePhase.escLineSpacing;
      case 0x74:
        _phase = _ParsePhase.escCodePage;
      case 0x52:
        _phase = _ParsePhase.escCharset;
      default:
        _logUnknownCommand('ESC', byte);
        _phase = _ParsePhase.normal;
    }
  }

  void _handleFs(int byte) {
    switch (byte) {
      case 0x21:
        _phase = _ParsePhase.fsBang;
      case 0x26:
        _textDecoder.setChineseMode(true);
        _logCommand('FS &', 'Chinese mode on (GBK)');
        _phase = _ParsePhase.normal;
      case 0x2E:
        _textDecoder.setChineseMode(false);
        _logCommand('FS .', 'Chinese mode off');
        _phase = _ParsePhase.normal;
      default:
        _logUnknownCommand('FS', byte);
        _phase = _ParsePhase.normal;
    }
  }

  void _handleFsBang(int byte) {
    if (byte == 0x00 || byte == 0x01) {
      _textDecoder.setChineseMode(byte == 0x01);
      _logCommand('FS !', 'Chinese mode ${byte == 0x01}');
    } else {
      _logCommand('FS !', 'Mode 0x${byte.toRadixString(16)}');
    }
    _phase = _ParsePhase.normal;
  }

  void _handleEscCodePage(int byte) {
    _textDecoder.setCodePage(byte);
    _logCommand('ESC t', 'Code page $byte (${_textDecoder.encoding.name})');
    _phase = _ParsePhase.normal;
  }

  void _handleEscCharset(int byte) {
    _textDecoder.setInternationalCharset(byte);
    _logCommand('ESC R', 'Charset $byte');
    _phase = _ParsePhase.normal;
  }

  void _handleGs(int byte) {
    switch (byte) {
      case 0x21:
        _phase = _ParsePhase.gsBang;
      case 0x76:
        _phase = _ParsePhase.gsRasterMode;
      case 0x56:
        _phase = _ParsePhase.gsCut;
      default:
        _logUnknownCommand('GS', byte);
        _phase = _ParsePhase.normal;
    }
  }

  void _handleGsBang(int byte) {
    if (byte == 0) {
      _style = _style.copyWith(doubleWidth: false, doubleHeight: false);
      _logCommand('GS !', 'Character size normal');
    } else {
      final widthMag = ((byte >> 4) & 0x0F) + 1;
      final heightMag = (byte & 0x0F) + 1;
      _style = _style.copyWith(
        doubleWidth: widthMag > 1,
        doubleHeight: heightMag > 1,
      );
      _logCommand('GS !', 'Character size ${widthMag}x$heightMag');
    }
    _phase = _ParsePhase.normal;
  }

  void _handleEscBang(int byte) {
    final bold = (byte & 0x08) != 0;
    final doubleHeight = (byte & 0x10) != 0;
    final doubleWidth = (byte & 0x20) != 0;
    _style = _style.copyWith(
      bold: bold,
      doubleHeight: doubleHeight,
      doubleWidth: doubleWidth,
    );
    _logCommand('ESC !', 'Print mode 0x${byte.toRadixString(16)}');
    _phase = _ParsePhase.normal;
  }

  void _handleEscAlign(int byte) {
    final align = switch (byte) {
      1 => ReceiptAlign.center,
      2 => ReceiptAlign.right,
      _ => ReceiptAlign.left,
    };
    _flushLine();
    _style = _style.copyWith(align: align);
    _logCommand('ESC a', 'Alignment ${align.name}');
    _phase = _ParsePhase.normal;
  }

  void _handleEscBold(int byte) {
    _style = _style.copyWith(bold: byte == 1);
    _logCommand('ESC E', 'Bold ${byte == 1}');
    _phase = _ParsePhase.normal;
  }

  void _handleEscFeed(int byte) {
    _flushLine();
    _document = _document.appendElement(ReceiptFeed(byte));
    _logCommand('ESC d', 'Feed $byte lines');
    _phase = _ParsePhase.normal;
  }

  void _handleEscLineSpacing(int byte) {
    _logCommand('ESC 3', 'Line spacing $byte');
    _phase = _ParsePhase.normal;
  }

  void _handleGsRasterMode(int byte) {
    // GS v 0 — Epson form: 1D 76 30 m xL xH yL yH [data]
    if (byte == 0x30) {
      _phase = _ParsePhase.gsRasterSubcommand;
      return;
    }
    if (_isRasterMode(byte)) {
      _phase = _ParsePhase.gsRasterWidthLow;
      return;
    }
    _logUnknownCommand('GS v mode', byte);
    _resetRaster();
    _phase = _ParsePhase.normal;
  }

  void _handleGsRasterSubcommand(int byte) {
    if (_isRasterMode(byte)) {
      _phase = _ParsePhase.gsRasterWidthLow;
      return;
    }
    _logUnknownCommand('GS v 0 m', byte);
    _resetRaster();
    _phase = _ParsePhase.normal;
  }

  bool _isRasterMode(int byte) =>
      byte == 0x00 || byte == 0x01 || byte == 0x32 || byte == 0x33;

  void _startRasterDataCollection() {
    final width = _rasterWidthBytes ?? 0;
    final height = _rasterHeight ?? 0;
    _rasterBytesExpected = width * height;
    _rasterData.clear();
    if (_rasterBytesExpected <= 0) {
      _resetRaster();
      _phase = _ParsePhase.normal;
      return;
    }
    _flushLine();
    _phase = _ParsePhase.gsRasterData;
  }

  void _finishRaster() {
    final image = ReceiptRasterImage(
      widthBytes: _rasterWidthBytes ?? 0,
      height: _rasterHeight ?? 0,
      data: List<int>.from(_rasterData),
    );
    _document = _document.appendElement(image);
    _logCommand(
      'GS v 0',
      'Raster ${image.widthBytes * 8}x${image.height} (${image.data.length} bytes)',
    );
    _resetRaster();
    _phase = _ParsePhase.normal;
  }

  void _handleGsCut(int byte) {
    _flushLine();
    final partial = byte == 66 || byte == 1;
    _document = _document.appendElement(ReceiptCut(partial: partial));
    _document = _document.appendElement(const ReceiptSeparator());
    _logCommand('GS V', partial ? 'Partial cut' : 'Full cut');
    _phase = _ParsePhase.normal;
  }

  void _flushLineOrFeed() {
    _currentLine += _textDecoder.flush();
    if (_currentLine.isEmpty) {
      _document = _document.appendElement(const ReceiptFeed(1));
      return;
    }
    final line = ReceiptTextLine(text: _currentLine, style: _style);
    _document = _document
        .appendElement(line)
        .appendText('$_currentLine\n');
    _currentLine = '';
  }

  void _flushLine() {
    _currentLine += _textDecoder.flush();
    if (_currentLine.isEmpty) {
      return;
    }
    final line = ReceiptTextLine(text: _currentLine, style: _style);
    _document = _document
        .appendElement(line)
        .appendText('$_currentLine\n');
    _currentLine = '';
  }

  void _resetRaster() {
    _rasterWidthBytes = null;
    _rasterHeight = null;
    _rasterData.clear();
    _rasterBytesExpected = 0;
  }

  void _logCommand(String name, String detail) {
    _pendingLogs.add(
      LogEntry(
        timestamp: DateTime.now(),
        kind: LogEntryKind.command,
        message: '$name — $detail',
      ),
    );
  }

  void _logUnknownCommand(String prefix, int byte) {
    _pendingLogs.add(
      LogEntry(
        timestamp: DateTime.now(),
        kind: LogEntryKind.command,
        message: '$prefix 0x${byte.toRadixString(16).padLeft(2, '0')} (unknown)',
        bytes: [byte],
      ),
    );
  }
}
