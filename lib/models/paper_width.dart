/// Thermal paper width — matches Garletz escpos-virtual-printer-emulator.
enum PaperWidth {
  mm50(dots: 384, normalChars: 48),
  mm78(dots: 576, normalChars: 72),
  mm80(dots: 640, normalChars: 80);

  const PaperWidth({
    required this.dots,
    required this.normalChars,
  });

  /// Printable width in dots (monochrome raster).
  final int dots;

  /// Character columns at normal width, Font A (~12pt).
  final int normalChars;

  String get label => switch (this) {
        PaperWidth.mm50 => '50mm',
        PaperWidth.mm78 => '78mm',
        PaperWidth.mm80 => '80mm',
      };

  /// Screen preview width — 0.5 logical px per dot (80mm → 320px).
  double get previewWidth => dots * 0.5;

  /// Printable columns accounting for double-width magnification.
  int maxChars({required bool doubleWidth}) =>
      doubleWidth ? normalChars ~/ 2 : normalChars;

  static PaperWidth fromCode(String? code) {
    return switch (code) {
      '50' => PaperWidth.mm50,
      '78' => PaperWidth.mm78,
      '80' || _ => PaperWidth.mm80,
    };
  }

  String get code => switch (this) {
        PaperWidth.mm50 => '50',
        PaperWidth.mm78 => '78',
        PaperWidth.mm80 => '80',
      };
}
