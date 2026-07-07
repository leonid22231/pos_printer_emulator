import 'package:charset/charset.dart' show cp866;
import 'package:fast_gbk/fast_gbk.dart' as fast_gbk;
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_emulator/models/receipt_element.dart';
import 'package:pos_emulator/services/escpos/escpos_parser.dart';
import 'package:pos_emulator/services/escpos/escpos_text_decoder.dart';
import 'package:pos_emulator/services/samples/sample_receipt_builder.dart';

/// Builds ESC/POS bytes like EvoSoft kiosk [PosPrinterDriver._buildEscPosPayload].
List<int> buildKioskStylePayload(List<String> lines) {
  final out = <int>[
    0x1B,
    0x40, // ESC @
    0x1B,
    0x74,
    0x11, // ESC t 17 = CP866
  ];

  for (final line in lines) {
    out.addAll(cp866.encode(line));
    out.addAll([0x0D, 0x0A]); // CR LF
  }

  out.addAll([0x1B, 0x64, 0x04]); // feed
  out.addAll([0x1D, 0x56, 0x42, 0x00]); // cut
  return out;
}

/// Styled line like [PosPrinterDriver.printStyledLines].
void _appendStyledLine(
  List<int> out, {
  String text = '',
  int align = 0,
  int size = 0,
}) {
  out.addAll([0x1B, 0x61, align]);
  out.addAll([0x1D, 0x21, size]);
  if (text.isNotEmpty) {
    out.addAll(cp866.encode(text));
  }
  out.addAll([0x0D, 0x0A]);
  out.addAll([0x1D, 0x21, 0x00]);
  out.addAll([0x1B, 0x61, 0x00]);
}

List<int> buildKioskSlipPayload() {
  final out = <int>[0x1B, 0x40, 0x1B, 0x74, 0x11];
  _appendStyledLine(out, text: 'ИП Саргсян', align: 1);
  _appendStyledLine(out, text: 'Санкт-Петербург', align: 1);
  _appendStyledLine(out, text: 'ул. Карбышева, дом 9 литер А', align: 1);
  _appendStyledLine(out, text: 'т. 79818816888', align: 1);
  _appendStyledLine(out);
  _appendStyledLine(
    out,
    text: '31.03.25     20:33              ЧЕК 0003',
  );
  _appendStyledLine(out);
  _appendStyledLine(out, text: 'Сумма(Руб):                       640.00');
  _appendStyledLine(out);
  _appendStyledLine(out);
  _appendStyledLine(out, text: 'Номер заказа');
  for (final line in ['███ ███', '█ █ █ █', '█ █ █ █', '█ █ █ █', '███ ███']) {
    _appendStyledLine(out, text: line, align: 0);
  }
  _appendStyledLine(out);
  _appendStyledLine(out);
  _appendStyledLine(out, text: 'ВНИМАНИЕ !', align: 1);
  _appendStyledLine(
    out,
    text: 'Данный чек не является платёжным документом.',
    align: 1,
  );
  _appendStyledLine(
    out,
    text: 'Чек за покупку будет выдан вместе с заказом',
    align: 1,
  );
  _appendStyledLine(
    out,
    text: 'после проверки вашего возраста.',
    align: 1,
  );
  out.addAll([0x1D, 0x56, 0x42, 0x00]);
  return out;
}

void main() {  test('parses sample coffee shop receipt', () {
    final parser = EscPosParser();
    final bytes = SampleReceiptBuilder.buildCoffeeShopReceipt();

    for (var i = 0; i < bytes.length; i += 16) {
      final end = (i + 16 > bytes.length) ? bytes.length : i + 16;
      parser.feed(bytes.sublist(i, end));
    }

    expect(parser.document.plainText, contains('COFFEE SHOP'));
    expect(parser.document.plainText, contains('TOTAL:           \$16.50'));
    expect(parser.document.plainText, isNot(contains('¬U')));
    expect(parser.document.plainText, isNot(contains('UU')));
    expect(
      parser.document.elements.any((e) => e is ReceiptRasterImage),
      isTrue,
    );
    expect(parser.document.elements.isNotEmpty, isTrue);
  });

  test('parses kiosk payment slip with GS ! large order number', () {
    final parser = EscPosParser();
    final bytes = buildKioskSlipPayload();

    parser.feed(bytes);

    final text = parser.document.plainText;
    expect(text, contains('ИП Саргсян'));
    expect(text, contains('ЧЕК 0003'));
    expect(text, contains('640.00'));
    expect(text, contains('ВНИМАНИЕ !'));
    expect(text, contains('не является платёжным'));

    final orderLine = parser.document.elements
        .whereType<ReceiptTextLine>()
        .firstWhere((line) => line.text.contains('███'));
    expect(orderLine.style.align, ReceiptAlign.left);
    expect(orderLine.text, contains('█'));

    final orgLine = parser.document.elements
        .whereType<ReceiptTextLine>()
        .firstWhere((line) => line.text == 'ИП Саргсян');
    expect(orgLine.style.align, ReceiptAlign.center);
    expect(orgLine.text.startsWith(' '), isFalse);
  });

  test('GS ! 0x11 sets double width and height', () {
    final parser = EscPosParser();
    parser.feed([0x1B, 0x40, 0x1B, 0x74, 0x11]);
    parser.feed([0x1D, 0x21, 0x11]);
    parser.feed(cp866.encode('82'));
    parser.feed([0x0A]);

    final line = parser.document.elements.whereType<ReceiptTextLine>().single;
    expect(line.text, '82');
    expect(line.style.doubleWidth, isTrue);
    expect(line.style.doubleHeight, isTrue);
  });

  test('decodes kiosk Russian receipt (CP866 + ESC t 17)', () {
    final parser = EscPosParser();
    final bytes = buildKioskStylePayload([
      '=== ТЕСТ POS ===',
      'Порт: COM31',
      '2026-07-07T20:00:26.424444',
      'ПЕЧАТЬ ОК',
    ]);

    for (var i = 0; i < bytes.length; i += 8) {
      final end = (i + 8 > bytes.length) ? bytes.length : i + 8;
      parser.feed(bytes.sublist(i, end));
    }

    final text = parser.document.plainText;
    expect(text, contains('=== ТЕСТ POS ==='));
    expect(text, contains('Порт: COM31'));
    expect(text, contains('ПЕЧАТЬ ОК'));
    expect(text, isNot(contains('僗')));
    expect(text, isNot(contains('犞')));
  });

  test('decodes GBK Chinese text from POS printer test slip', () {
    final parser = EscPosParser();
    final bytes = fast_gbk.gbk.encode('专业POS热敏打印机');

    parser.feed([0x1B, 0x40, 0x1C, 0x26]); // init + FS & chinese mode
    parser.feed(bytes);
    parser.feed([0x0A]);

    expect(parser.document.plainText, contains('专业'));
  });

  test('EscPosTextDecoder maps ESC t 17 to CP866', () {
    final decoder = EscPosTextDecoder();
    decoder.setCodePage(17);
    expect(decoder.encoding, PosEncoding.cp866);

    final bytes = cp866.encode('ТЕСТ');
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(decoder.feed(b));
    }
    expect(buffer.toString(), 'ТЕСТ');
  });

  test('EscPosTextDecoder handles split GBK pairs across chunks', () {
    final decoder = EscPosTextDecoder();
    decoder.setChineseMode(true);
    final bytes = fast_gbk.gbk.encode('测试');

    final part1 = decoder.feed(bytes[0]);
    expect(part1, isEmpty);

    final part2 = decoder.feed(bytes[1]);
    expect(part2, isNotEmpty);

    final part3 = decoder.feed(bytes[2]);
    expect(part3, isEmpty);

    final part4 = decoder.feed(bytes[3]);
    expect(part4, isNotEmpty);
    expect(part2 + part4, '测试');
  });
}
