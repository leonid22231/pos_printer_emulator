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
  });

  final int widthBytes;
  final int height;
  final List<int> data;
}

class ReceiptCut extends ReceiptElement {
  const ReceiptCut({this.partial = false});

  final bool partial;
}

class ReceiptSeparator extends ReceiptElement {
  const ReceiptSeparator();
}
