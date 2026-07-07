import 'package:charset/charset.dart';

/// CP866 (DOS Cyrillic) — default for Russian ESC/POS (ESC t 17 / 0x11).
class Cp866Decoder {
  static String decodeByte(int byte) {
    if (byte >= 0x20 && byte <= 0x7E) {
      return String.fromCharCode(byte);
    }
    return cp866.decode([byte], allowInvalid: true);
  }
}

/// CP1251 (Windows Cyrillic) — ESC t 33 / 0x21 in kiosk project.
class Cp1251Decoder {
  static String decodeByte(int byte) {
    if (byte >= 0x20 && byte <= 0x7E) {
      return String.fromCharCode(byte);
    }
    return windows1251.decode([byte], allowInvalid: true);
  }
}
