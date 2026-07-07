import 'package:flutter_test/flutter_test.dart';
import 'package:pos_emulator/models/paper_width.dart';
import 'package:pos_emulator/services/serial/com0com_installer.dart';

void main() {
  group('PaperWidth', () {
    test('matches Garletz dot and char counts', () {
      expect(PaperWidth.mm50.dots, 384);
      expect(PaperWidth.mm50.normalChars, 48);
      expect(PaperWidth.mm78.dots, 576);
      expect(PaperWidth.mm78.normalChars, 72);
      expect(PaperWidth.mm80.dots, 640);
      expect(PaperWidth.mm80.normalChars, 80);
    });

    test('preview scales 0.5px per dot', () {
      expect(PaperWidth.mm80.previewWidth, 320);
      expect(PaperWidth.mm78.previewWidth, 288);
      expect(PaperWidth.mm50.previewWidth, 192);
    });

    test('double width halves columns', () {
      expect(PaperWidth.mm80.maxChars(doubleWidth: true), 40);
      expect(PaperWidth.mm80.maxChars(doubleWidth: false), 80);
    });

    test('persists by code', () {
      expect(PaperWidth.fromCode('50'), PaperWidth.mm50);
      expect(PaperWidth.fromCode('78'), PaperWidth.mm78);
      expect(PaperWidth.fromCode(null), PaperWidth.mm80);
    });
  });

  group('Com0comInstaller', () {
    test('manual install zip URL is defined', () {
      expect(Com0comInstaller.manualInstallZipUrl, contains('ManualInstall'));
      expect(Com0comInstaller.downloadPageUrl, contains('github.com'));
    });

    test('retries download on transient network errors', () {
      expect(Com0comInstaller.downloadMaxAttempts, greaterThan(1));
    });
  });
}
