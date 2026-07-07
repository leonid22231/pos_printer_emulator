/// Builds a realistic ESC/POS byte stream for mock mode and tests.
class SampleReceiptBuilder {
  static List<int> buildCoffeeShopReceipt() {
    final bytes = <int>[];

    void esc(List<int> payload) {
      bytes.addAll([0x1B, ...payload]);
    }

    void gs(List<int> payload) {
      bytes.addAll([0x1D, ...payload]);
    }

    void text(String value) {
      bytes.addAll(value.codeUnits);
    }

    void line([String value = '']) {
      if (value.isNotEmpty) {
        text(value);
      }
      bytes.add(0x0A);
    }

    esc([0x40]); // Initialize

    esc([0x61, 0x01]); // Center
    esc([0x21, 0x30]); // Double width + height
    esc([0x45, 0x01]); // Bold on
    line('COFFEE SHOP');
    esc([0x45, 0x00]);
    esc([0x21, 0x00]);
    line('123 Main Street');
    line('Tel: +1 (555) 012-3456');
    line();

    esc([0x61, 0x00]); // Left
    line('--------------------------------');
    line('Item              Qty      Total');
    line('--------------------------------');
    line('Espresso            2      \$7.00');
    line('Croissant           1      \$3.50');
    line('Latte               1      \$4.50');
    line('--------------------------------');

    esc([0x61, 0x02]); // Right
    esc([0x45, 0x01]);
    line('SUBTOTAL:        \$15.00');
    line('TAX 10%:          \$1.50');
    esc([0x21, 0x10]); // Double height
    line('TOTAL:           \$16.50');
    esc([0x21, 0x00]);
    esc([0x45, 0x00]);

    esc([0x61, 0x01]); // Center
    line();
    line('Thank you!');
    line('Please come again');
    esc([0x64, 0x03]); // Feed 3 lines

    // Small raster logo placeholder (16x16 monochrome)
    _appendRasterPlaceholder(bytes, widthPixels: 128, height: 16);

    gs([0x56, 0x00]); // Full cut

    return bytes;
  }

  static void _appendRasterPlaceholder(
    List<int> bytes, {
    required int widthPixels,
    required int height,
  }) {
    final widthBytes = (widthPixels + 7) ~/ 8;
    bytes.addAll([0x1D, 0x76, 0x30, 0x00]);
    bytes.add(widthBytes & 0xFF);
    bytes.add((widthBytes >> 8) & 0xFF);
    bytes.add(height & 0xFF);
    bytes.add((height >> 8) & 0xFF);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < widthBytes; x++) {
        // Checker-ish pattern
        bytes.add(((x + y) % 2 == 0) ? 0xAA : 0x55);
      }
    }
  }
}
