import 'package:flutter/material.dart';

import '../../models/paper_width.dart';
import '../../models/receipt_document.dart';
import '../../models/receipt_element.dart';
import 'receipt_layout.dart';

/// Visual receipt preview styled like thermal paper.
///
/// Text is drawn on a fixed character grid (like [Garletz escpos-virtual-printer-emulator](https://github.com/Garletz/escpos-virtual-printer-emulator)):
/// double-width / double-height are canvas scales, not larger font metrics — so
/// tall lines (e.g. TOTAL) do not become wider and get clipped.
///
/// Scroll follows the paper tail — newest lines stay in view while printing.
class ReceiptPreview extends StatefulWidget {
  const ReceiptPreview({
    super.key,
    required this.document,
    this.paperWidth = PaperWidth.mm80,
    this.emptyMessage = 'Receipt preview appears when bytes arrive.',
  });

  final ReceiptDocument document;
  final PaperWidth paperWidth;
  final String emptyMessage;

  @override
  State<ReceiptPreview> createState() => _ReceiptPreviewState();
}

class _ReceiptPreviewState extends State<ReceiptPreview> {
  final ScrollController _scrollController = ScrollController();
  int _lastDocumentFingerprint = 0;

  int _fingerprint(ReceiptDocument document) =>
      Object.hash(document.elements.length, document.plainText.length);

  @override
  void initState() {
    super.initState();
    _lastDocumentFingerprint = _fingerprint(widget.document);
    if (widget.document.elements.isNotEmpty) {
      _scrollToBottom();
    }
  }

  @override
  void didUpdateWidget(ReceiptPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fingerprint = _fingerprint(widget.document);
    if (fingerprint == _lastDocumentFingerprint) {
      return;
    }
    _lastDocumentFingerprint = fingerprint;

    if (widget.document.elements.isEmpty) {
      _scrollToTop();
    } else {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      if (target <= 0) {
        return;
      }
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: Container(
          width: widget.paperWidth.previewWidth,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFEF8),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final element in widget.document.elements)
                  _buildElement(element),
                if (widget.document.elements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.emptyMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        color: Colors.black45,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElement(ReceiptElement element) {
    return switch (element) {
      ReceiptTextLine line => _textLine(line),
      ReceiptFeed feed => SizedBox(height: 14.0 * feed.lines),
      ReceiptRasterImage image => _raster(image),
      ReceiptCut cut => _cut(cut.partial),
      ReceiptSeparator _ => const Divider(height: 24, thickness: 2),
    };
  }

  Widget _textLine(ReceiptTextLine line) {
    const baseFontSize = 13.0;
    final scaleX = line.style.doubleWidth ? 2.0 : 1.0;
    final scaleY = line.style.doubleHeight ? 2.0 : 1.0;
    final contentWidth = ReceiptLayout.contentWidth(widget.paperWidth);

    final textStyle = TextStyle(
      fontFamily: 'Consolas',
      fontFamilyFallback: const [
        'Courier New',
        'Lucida Console',
        'Segoe UI',
      ],
      fontSize: baseFontSize,
      fontWeight: line.style.bold ? FontWeight.w700 : FontWeight.w400,
      height: 1.15,
      letterSpacing: 0,
      color: Colors.black87,
      decoration:
          line.style.underline ? TextDecoration.underline : TextDecoration.none,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ReceiptLayout.horizontalPadding,
        vertical: 2,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: line.text, style: textStyle),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();

          final visualHeight = painter.height * scaleY;

          return SizedBox(
            width: constraints.maxWidth,
            height: visualHeight,
            child: CustomPaint(
              size: Size(constraints.maxWidth, visualHeight),
              painter: _ReceiptTextPainter(
                text: line.text,
                style: textStyle,
                align: line.style.align,
                scaleX: scaleX,
                scaleY: scaleY,
                maxWidth: contentWidth,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _raster(ReceiptRasterImage image) {
    if (image.widthBytes <= 0 || image.height <= 0 || image.data.isEmpty) {
      return const SizedBox.shrink();
    }

    final contentWidth = ReceiptLayout.contentWidth(widget.paperWidth);
    final dotsPerLogicalPx = widget.paperWidth.dots / widget.paperWidth.previewWidth;
    final nativeWidth = image.widthPx / dotsPerLogicalPx * image.scaleX;
    final nativeHeight = image.height / dotsPerLogicalPx * image.scaleY;
    final displayWidth = nativeWidth.clamp(1.0, contentWidth);
    final displayHeight = nativeHeight * (displayWidth / nativeWidth);

    final child = SizedBox(
      width: displayWidth,
      height: displayHeight,
      child: CustomPaint(
        painter: _RasterPainter(
          data: image.data,
          widthBytes: image.widthBytes,
          height: image.height,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ReceiptLayout.horizontalPadding,
        vertical: 4,
      ),
      child: Align(
        alignment: switch (image.align) {
          ReceiptAlign.left => Alignment.centerLeft,
          ReceiptAlign.center => Alignment.center,
          ReceiptAlign.right => Alignment.centerRight,
        },
        child: child,
      ),
    );
  }

  Widget _cut(bool partial) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: partial ? Colors.black38 : Colors.black87,
                    width: partial ? 1 : 2,
                    style: partial ? BorderStyle.solid : BorderStyle.solid,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              partial ? '--- partial cut ---' : '=== CUT ===',
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                color: Colors.black45,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: Colors.black38)),
        ],
      ),
    );
  }
}

class _ReceiptTextPainter extends CustomPainter {
  _ReceiptTextPainter({
    required this.text,
    required this.style,
    required this.align,
    required this.scaleX,
    required this.scaleY,
    required this.maxWidth,
  });

  final String text;
  final TextStyle style;
  final ReceiptAlign align;
  final double scaleX;
  final double scaleY;
  final double maxWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final drawWidth = painter.width * scaleX;
    final dx = switch (align) {
      ReceiptAlign.left => 0.0,
      ReceiptAlign.center => (maxWidth - drawWidth) / 2,
      ReceiptAlign.right => maxWidth - drawWidth,
    };

    canvas.save();
    canvas.translate(dx.clamp(0.0, maxWidth), 0);
    canvas.scale(scaleX, scaleY);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReceiptTextPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.style != style ||
        oldDelegate.align != align ||
        oldDelegate.scaleX != scaleX ||
        oldDelegate.scaleY != scaleY ||
        oldDelegate.maxWidth != maxWidth;
  }
}

class _RasterPainter extends CustomPainter {
  _RasterPainter({
    required this.data,
    required this.widthBytes,
    required this.height,
  });

  final List<int> data;
  final int widthBytes;
  final int height;

  @override
  void paint(Canvas canvas, Size size) {
    if (widthBytes <= 0 || height <= 0 || data.isEmpty) {
      return;
    }
    final widthPx = widthBytes * 8;
    final cellW = size.width / widthPx;
    final cellH = size.height / height;
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;

    for (var y = 0; y < height; y++) {
      for (var byteIndex = 0; byteIndex < widthBytes; byteIndex++) {
        final index = y * widthBytes + byteIndex;
        if (index >= data.length) {
          return;
        }
        final value = data[index];
        if (value == 0) {
          continue;
        }
        for (var bit = 0; bit < 8; bit++) {
          if ((value & (0x80 >> bit)) == 0) {
            continue;
          }
          final x = byteIndex * 8 + bit;
          canvas.drawRect(
            Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.2, cellH + 0.2),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RasterPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.widthBytes != widthBytes ||
        oldDelegate.height != height;
  }
}
