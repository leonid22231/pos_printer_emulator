/// Basic CP437 decoder for ESC/POS text (code page 437).
///
/// UTF-8 sequences are passed through when valid; otherwise bytes map to CP437.
class Cp437Decoder {
  static const _cp437 = <int, String>{
    0x80: 'Ç',
    0x81: 'ü',
    0x82: 'é',
    0x83: 'â',
    0x84: 'ä',
    0x85: 'à',
    0x86: 'å',
    0x87: 'ç',
    0x88: 'ê',
    0x89: 'ë',
    0x8A: 'è',
    0x8B: 'ï',
    0x8C: 'î',
    0x8D: 'ì',
    0x8E: 'Ä',
    0x8F: 'Å',
    0x90: 'É',
    0x91: 'æ',
    0x92: 'Æ',
    0x93: 'ô',
    0x94: 'ö',
    0x95: 'ò',
    0x96: 'û',
    0x97: 'ù',
    0x98: 'ÿ',
    0x99: 'Ö',
    0x9A: 'Ü',
    0x9B: '¢',
    0x9C: '£',
    0x9D: '¥',
    0x9E: '₧',
    0x9F: 'ƒ',
    0xA0: 'á',
    0xA1: 'í',
    0xA2: 'ó',
    0xA3: 'ú',
    0xA4: 'ñ',
    0xA5: 'Ñ',
    0xA6: 'ª',
    0xA7: 'º',
    0xA8: '¿',
    0xA9: '⌐',
    0xAA: '¬',
    0xAB: '½',
    0xAC: '¼',
    0xAD: '¡',
    0xAE: '«',
    0xAF: '»',
    0xB0: '░',
    0xB1: '▒',
    0xB2: '▓',
    0xB3: '│',
    0xB4: '┤',
    0xB5: '╡',
    0xB6: '╢',
    0xB7: '╖',
    0xB8: '╕',
    0xB9: '╣',
    0xBA: '║',
    0xBB: '╗',
    0xBC: '╝',
    0xBD: '╜',
    0xBE: '╛',
    0xBF: '┐',
    0xC0: '└',
    0xC1: '┴',
    0xC2: '┬',
    0xC3: '├',
    0xC4: '─',
    0xC5: '┼',
    0xC6: '╞',
    0xC7: '╟',
    0xC8: '╚',
    0xC9: '╔',
    0xCA: '╩',
    0xCB: '╦',
    0xCC: '╠',
    0xCD: '═',
    0xCE: '╬',
    0xCF: '╧',
    0xD0: '╨',
    0xD1: '╤',
    0xD2: '╥',
    0xD3: '╙',
    0xD4: '╘',
    0xD5: '╒',
    0xD6: '╓',
    0xD7: '╫',
    0xD8: '╪',
    0xE0: 'α',
    0xE1: 'ß',
    0xE2: 'Γ',
    0xE3: 'π',
    0xE4: 'Σ',
    0xE5: 'σ',
    0xE6: 'µ',
    0xE7: 'τ',
    0xE8: 'Φ',
    0xE9: 'Θ',
    0xEA: 'Ω',
    0xEB: 'δ',
    0xEC: '∞',
    0xED: 'φ',
    0xEE: 'ε',
    0xEF: '∩',
    0xF0: '≡',
    0xF1: '±',
    0xF2: '≥',
    0xF3: '≤',
    0xF4: '⌠',
    0xF5: '⌡',
    0xF6: '÷',
    0xF7: '≈',
    0xF8: '°',
    0xF9: '∙',
    0xFA: '·',
    0xFB: '√',
    0xFC: 'ⁿ',
    0xFD: '²',
    0xFE: '■',
    0xFF: ' ',
  };

  static String decodeByte(int byte) {
    if (byte >= 0x20 && byte <= 0x7E) {
      return String.fromCharCode(byte);
    }
    return _cp437[byte] ?? String.fromCharCode(byte);
  }

  static String decodeBytes(List<int> bytes) {
    final buffer = StringBuffer();
    var i = 0;
    while (i < bytes.length) {
      final b = bytes[i];
      if (b == 0x1B || b == 0x1D) {
        break;
      }
      if (b >= 0xC0) {
        final utf8Len = _utf8Length(b);
        if (utf8Len > 0 && i + utf8Len <= bytes.length) {
          try {
            buffer.write(String.fromCharCodes(bytes.sublist(i, i + utf8Len)));
            i += utf8Len;
            continue;
          } catch (_) {
            // fall through to CP437
          }
        }
      }
      buffer.write(decodeByte(b));
      i++;
    }
    return buffer.toString();
  }

  static int _utf8Length(int firstByte) {
    if ((firstByte & 0xE0) == 0xC0) return 2;
    if ((firstByte & 0xF0) == 0xE0) return 3;
    if ((firstByte & 0xF8) == 0xF0) return 4;
    return 0;
  }
}
