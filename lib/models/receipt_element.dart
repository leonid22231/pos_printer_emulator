enum ReceiptAlign { left, center, right }

class TextStyleState {
  const TextStyleState({
    this.bold = false,
    this.doubleWidth = false,
    this.doubleHeight = false,
    this.underline = false,
    this.align = ReceiptAlign.left,
  });

  final bool bold;
  final bool doubleWidth;
  final bool doubleHeight;
  final bool underline;
  final ReceiptAlign align;

  TextStyleState copyWith({
    bool? bold,
    bool? doubleWidth,
    bool? doubleHeight,
    bool? underline,
    ReceiptAlign? align,
  }) {
    return TextStyleState(
      bold: bold ?? this.bold,
      doubleWidth: doubleWidth ?? this.doubleWidth,
      doubleHeight: doubleHeight ?? this.doubleHeight,
      underline: underline ?? this.underline,
      align: align ?? this.align,
    );
  }

  static const initial = TextStyleState();
}

sealed class ReceiptElement {
  const ReceiptElement();
}

class ReceiptTextLine extends ReceiptElement {
  const ReceiptTextLine({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyleState style;
}

class ReceiptFeed extends ReceiptElement {
  const ReceiptFeed(this.lines);

  final int lines;
}

class ReceiptRasterImage extends ReceiptElement {
  const ReceiptRasterImage({
    required this.widthBytes,
    required this.height,
    required this.data,
    this.align = ReceiptAlign.left,
    this.mode = 0,
  });

  final int widthBytes;
  final int height;
  final List<int> data;
  final ReceiptAlign align;

  /// GS v 0 m: 0 normal, 1 double-width, 2 double-height, 3 quadruple.
  final int mode;

  int get widthPx => widthBytes * 8;

  double get scaleX => (mode == 1 || mode == 3) ? 2.0 : 1.0;

  double get scaleY => (mode == 2 || mode == 3) ? 2.0 : 1.0;
}

class ReceiptCut extends ReceiptElement {
  const ReceiptCut({this.partial = false});

  final bool partial;
}

class ReceiptSeparator extends ReceiptElement {
  const ReceiptSeparator();
}
