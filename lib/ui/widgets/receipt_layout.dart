import '../../models/paper_width.dart';

/// Thermal paper layout — character grid like Garletz escpos-virtual-printer-emulator.
abstract final class ReceiptLayout {
  static const double horizontalPadding = 12;

  static double contentWidth(PaperWidth paper) =>
      paper.previewWidth - horizontalPadding * 2;

  /// Monospace cell width — one normal character column.
  static double cellWidth(PaperWidth paper) =>
      contentWidth(paper) / paper.normalChars;

  static int effectiveColumns({
    required PaperWidth paper,
    required bool doubleWidth,
  }) =>
      paper.maxChars(doubleWidth: doubleWidth);
}
