import 'package:fast_gbk/fast_gbk.dart';

import 'cp437_decoder.dart';
import 'cp866_decoder.dart';

/// Active text encoding selected by ESC/POS commands.
enum PosEncoding {
  cp437,
  cp866,
  cp1251,
  gbk,
}

/// Streaming decoder for ESC/POS text bytes.
///
/// Encoding is driven by `ESC t` (code page), matching EvoSoft kiosk driver:
/// - `0x11` (17) → CP866 (Russian default)
/// - `0x21` (33) → CP1251
/// - Chinese printers: GBK after `FS &` or Chinese code tables
class EscPosTextDecoder {
  EscPosTextDecoder({GbkCodec? gbkCodec})
      : _gbk = gbkCodec ?? GbkCodec(allowMalformed: true);

  final GbkCodec _gbk;

  PosEncoding _encoding = PosEncoding.cp437;
  bool _chineseMode = false;
  int? _pendingLead;

  PosEncoding get encoding => _encoding;
  bool get chineseMode => _chineseMode;

  void reset() {
    _encoding = PosEncoding.cp437;
    _chineseMode = false;
    _pendingLead = null;
  }

  /// Maps ESC/POS `ESC t n` table id to charset (Epson-compatible + kiosk).
  void setCodePage(int table) {
    _encoding = switch (table) {
      0 || 1 => PosEncoding.cp437,
      17 => PosEncoding.cp866, // 0x11 — kiosk default for Russian
      33 => PosEncoding.cp1251, // 0x21 — kiosk CP1251
      16 || 18 || 19 || 20 => PosEncoding.gbk,
      _ => PosEncoding.cp866,
    };
    _chineseMode = _encoding == PosEncoding.gbk;
    _pendingLead = null;
  }

  void setInternationalCharset(int charset) {
    if (charset == 7 || charset == 17) {
      _encoding = PosEncoding.cp866;
      _chineseMode = false;
    } else if (charset == 0 || charset == 15) {
      _encoding = PosEncoding.gbk;
      _chineseMode = true;
    }
    _pendingLead = null;
  }

  void setChineseMode(bool enabled) {
    _chineseMode = enabled;
    if (enabled) {
      _encoding = PosEncoding.gbk;
    } else if (_encoding == PosEncoding.gbk) {
      _encoding = PosEncoding.cp866;
    }
    _pendingLead = null;
  }

  String feed(int byte) {
    if (_pendingLead != null) {
      final lead = _pendingLead!;
      _pendingLead = null;
      return _decodeGbkPair(lead, byte);
    }

    if (byte >= 0x20 && byte <= 0x7E) {
      return String.fromCharCode(byte);
    }

    if (byte < 0x20) {
      return '';
    }

    if (_encoding == PosEncoding.gbk && byte >= 0x81 && byte <= 0xFE) {
      _pendingLead = byte;
      return '';
    }

    return _decodeSingle(byte);
  }

  String flush() {
    final lead = _pendingLead;
    if (lead == null) {
      return '';
    }
    _pendingLead = null;
    return _decodeSingle(lead);
  }

  String _decodeGbkPair(int lead, int trail) {
    try {
      return _gbk.decode([lead, trail], allowMalformed: true);
    } catch (_) {
      return '${_decodeSingle(lead)}${_decodeSingle(trail)}';
    }
  }

  String _decodeSingle(int byte) {
    return switch (_encoding) {
      PosEncoding.cp437 => Cp437Decoder.decodeByte(byte),
      PosEncoding.cp866 => Cp866Decoder.decodeByte(byte),
      PosEncoding.cp1251 => Cp1251Decoder.decodeByte(byte),
      PosEncoding.gbk => _decodeSingleGbk(byte),
    };
  }

  String _decodeSingleGbk(int byte) {
    if (byte >= 0x20 && byte <= 0x7E) {
      return String.fromCharCode(byte);
    }
    try {
      return _gbk.decode([byte], allowMalformed: true);
    } catch (_) {
      return Cp437Decoder.decodeByte(byte);
    }
  }
}
