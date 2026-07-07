import 'receipt_element.dart';

/// Aggregated receipt built by the ESC/POS parser.
class ReceiptDocument {
  const ReceiptDocument({
    this.elements = const [],
    this.plainText = '',
  });

  final List<ReceiptElement> elements;
  final String plainText;

  ReceiptDocument copyWith({
    List<ReceiptElement>? elements,
    String? plainText,
  }) {
    return ReceiptDocument(
      elements: elements ?? this.elements,
      plainText: plainText ?? this.plainText,
    );
  }

  ReceiptDocument appendElement(ReceiptElement element) {
    return copyWith(elements: [...elements, element]);
  }

  ReceiptDocument appendText(String text) {
    return copyWith(plainText: plainText + text);
  }
}
