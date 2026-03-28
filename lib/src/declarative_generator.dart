import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'enums.dart';
import 'generator.dart';
import 'label_size.dart';
import 'rendered_text_options.dart';
import 'text_style.dart';

class TscLabelGenerator {
  TscLabelGenerator({
    required this.config,
    required this.commands,
    this.newLine = '\r\n',
    this.codec = latin1,
  });

  final TscLabelConfiguration config;
  final List<TscLabelCommand> commands;
  final String newLine;
  final Encoding codec;

  Future<String> build() async {
    final bytes = await buildBytes();
    return codec.decode(bytes);
  }

  Future<Uint8List> buildBytes() async {
    final generator = TscGenerator(newLine: newLine, codec: codec);
    config.apply(generator);
    final context = TscBuildContext.root(config);

    for (final command in commands) {
      await command.applyWithContext(generator, context);
    }

    generator.print(copies: config.copies, sets: config.sets);
    return generator.build();
  }
}

class TscLabelConfiguration {
  const TscLabelConfiguration({
    required this.printWidth,
    required this.labelLength,
    this.unit = TscUnit.dot,
    this.gap = 0,
    this.gapOffset = 0,
    this.printDensity,
    this.direction = TscDirection.forward,
    this.mirror = TscMirror.normal,
    this.referenceX = 0,
    this.referenceY = 0,
    this.clearBuffer = true,
    this.codePage,
    this.copies = 1,
    this.sets = 1,
  });

  final num printWidth;
  final num labelLength;
  final TscUnit unit;
  final num gap;
  final num gapOffset;
  final TscPrintDensity? printDensity;
  final TscDirection direction;
  final TscMirror mirror;
  final int referenceX;
  final int referenceY;
  final bool clearBuffer;
  final String? codePage;
  final int copies;
  final int sets;

  void apply(TscGenerator generator) {
    generator
      ..size(TscLabelSize(printWidth, labelLength, unit: unit))
      ..gap(gap, gapOffset, unit: unit);

    if (printDensity != null) {
      generator.density(printDensity!.value);
    }

    generator
      ..direction(direction, mirror: mirror)
      ..reference(referenceX, referenceY);

    if (codePage != null && codePage!.isNotEmpty) {
      generator.codePage(codePage!);
    }

    if (clearBuffer) {
      generator.cls();
    }
  }
}

enum TscAlignment { left, center, right }

class TscBuildContext {
  const TscBuildContext({
    required this.originX,
    required this.originY,
    required this.width,
    required this.height,
    this.cursorY = 0,
  });

  factory TscBuildContext.root(TscLabelConfiguration config) {
    return TscBuildContext(
      originX: 0,
      originY: 0,
      width: config.printWidth.round(),
      height: config.labelLength.round(),
    );
  }

  final int originX;
  final int originY;
  final int width;
  final int height;
  final int cursorY;

  TscBuildContext withCursor(int value) {
    return TscBuildContext(
      originX: originX,
      originY: originY,
      width: width,
      height: height,
      cursorY: value,
    );
  }

  TscBuildContext nested({
    int x = 0,
    int y = 0,
    required int width,
    int? height,
    int cursorY = 0,
  }) {
    return TscBuildContext(
      originX: originX + x,
      originY: originY + y,
      width: width,
      height: height ?? this.height,
      cursorY: cursorY,
    );
  }
}

class TscLayoutResult {
  const TscLayoutResult({this.height = 0});

  final int height;
}

abstract class TscLabelCommand {
  const TscLabelCommand();

  FutureOr<void> apply(TscGenerator generator) {}

  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) async {
    await apply(generator);
    return const TscLayoutResult();
  }
}

class TscText extends TscLabelCommand {
  const TscText({
    this.x,
    this.y,
    required this.text,
    this.style = const TscTextStyle(),
    this.fontHeight,
    this.fontWidth,
    this.alignment,
  });

  final int? x;
  final int? y;
  final String text;
  final TscTextStyle style;
  final int? fontHeight;
  final int? fontWidth;
  final TscAlignment? alignment;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    final effectiveFontHeight = fontHeight ?? style.yMultiplier * 24;
    final effectiveFontWidth = fontWidth ?? style.xMultiplier * 24;
    final resolvedStyle = style.copyWith(
      xMultiplier: _fontSizeToMultiplier(effectiveFontWidth),
      yMultiplier: _fontSizeToMultiplier(effectiveFontHeight),
      alignment: _toTextAlignment(alignment) ?? style.alignment,
    );

    final estimatedWidth = _estimateTextWidth(text, effectiveFontWidth);
    final drawX =
        context.originX +
        (x ?? _resolveAlignedX(context.width, estimatedWidth, alignment));
    final drawY = context.originY + (y ?? context.cursorY);

    generator.text(drawX, drawY, text, style: resolvedStyle);
    return TscLayoutResult(height: (y == null ? effectiveFontHeight + 8 : 0));
  }
}

class TscBarcode extends TscLabelCommand {
  const TscBarcode({
    this.x,
    this.y,
    required this.data,
    this.type = TscBarcodeType.code128,
    this.height = 100,
    this.printInterpretationLine = true,
    this.printInterpretationLineAbove = false,
    this.readable,
    this.rotation = TscRotation.angle0,
    this.narrow = 2,
    this.wide = 2,
    this.alignment,
  });

  final int? x;
  final int? y;
  final String data;
  final TscBarcodeType type;
  final int height;
  final bool printInterpretationLine;
  final bool printInterpretationLineAbove;
  final TscReadable? readable;
  final TscRotation rotation;
  final int narrow;
  final int wide;
  final TscAlignment? alignment;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    final estimatedWidth = math.max(120, data.length * (narrow + wide) * 6);
    final drawX =
        context.originX +
        (x ?? _resolveAlignedX(context.width, estimatedWidth, alignment));
    final drawY = context.originY + (y ?? context.cursorY);

    generator.barcode(
      drawX,
      drawY,
      data,
      type: type,
      height: height,
      readable: readable ?? _defaultReadable(),
      rotation: rotation,
      narrow: narrow,
      wide: wide,
      alignment: _toTextAlignment(alignment),
    );

    return TscLayoutResult(
      height: y == null ? height + (printInterpretationLine ? 28 : 0) + 8 : 0,
    );
  }

  TscReadable _defaultReadable() {
    if (!printInterpretationLine) {
      return TscReadable.hidden;
    }

    return printInterpretationLineAbove ? TscReadable.above : TscReadable.below;
  }
}

class TscQrCode extends TscLabelCommand {
  const TscQrCode({
    this.x,
    this.y,
    required this.data,
    this.ecc = TscQrErrorCorrection.low,
    this.cellWidth = TscQrCellWidth.size4,
    this.rotation = TscRotation.angle0,
    this.alignment,
  });

  final int? x;
  final int? y;
  final String data;
  final TscQrErrorCorrection ecc;
  final TscQrCellWidth cellWidth;
  final TscRotation rotation;
  final TscAlignment? alignment;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    final estimatedSize = cellWidth.value * 24;
    final drawX =
        context.originX +
        (x ?? _resolveAlignedX(context.width, estimatedSize, alignment));
    final drawY = context.originY + (y ?? context.cursorY);

    generator.qrCode(
      drawX,
      drawY,
      data,
      ecc: ecc,
      cellWidth: cellWidth,
      rotation: rotation,
      justification: _toTextAlignment(alignment),
    );

    return TscLayoutResult(height: y == null ? estimatedSize + 8 : 0);
  }
}

class TscBitmap extends TscLabelCommand {
  const TscBitmap({
    this.x,
    this.y,
    required this.image,
    this.mode = TscBitmapMode.overwrite,
    this.threshold = 127,
  });

  final int? x;
  final int? y;
  final img.Image image;
  final TscBitmapMode mode;
  final int threshold;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    generator.bitmap(
      context.originX + (x ?? 0),
      context.originY + (y ?? context.cursorY),
      image,
      mode: mode,
      threshold: threshold,
    );
    return TscLayoutResult(height: y == null ? image.height + 8 : 0);
  }
}

class TscRenderedText extends TscLabelCommand {
  const TscRenderedText({
    this.x,
    this.y,
    required this.text,
    required this.options,
  });

  final int? x;
  final int? y;
  final String text;
  final TscRenderedTextOptions options;

  @override
  Future<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) async {
    await generator.khmerText(
      context.originX + (x ?? 0),
      context.originY + (y ?? context.cursorY),
      text,
      options: options,
    );
    final height = ((options.style.fontSize ?? 24) * options.pixelRatio).ceil();
    return TscLayoutResult(height: y == null ? height + 8 : 0);
  }
}

class TscSeparator extends TscLabelCommand {
  const TscSeparator({
    required this.y,
    this.thickness = 1,
    this.paddingLeft = 0,
    this.paddingRight = 0,
  });

  final int y;
  final int thickness;
  final int paddingLeft;
  final int paddingRight;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    final width = context.width - paddingLeft - paddingRight;
    generator.bar(
      context.originX + paddingLeft,
      context.originY + y,
      math.max(1, width),
      thickness,
    );
    return const TscLayoutResult();
  }
}

class TscColumn extends TscLabelCommand {
  const TscColumn({required this.children, this.spacing = 8});

  final List<TscLabelCommand> children;
  final int spacing;

  @override
  Future<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) async {
    var cursor = context.cursorY;
    var consumed = 0;

    for (var i = 0; i < children.length; i++) {
      final result = await children[i].applyWithContext(
        generator,
        context.withCursor(cursor),
      );
      final advance = result.height == 0 ? 0 : result.height;
      cursor += advance;
      consumed += advance;
      if (i != children.length - 1 && advance > 0) {
        cursor += spacing;
        consumed += spacing;
      }
    }

    return TscLayoutResult(height: consumed);
  }
}

class TscGridCol {
  const TscGridCol({required this.width, required this.child});

  final int width;
  final TscLabelCommand child;
}

class TscGridRow extends TscLabelCommand {
  const TscGridRow({
    required this.y,
    required this.children,
    this.gutter = 12,
    this.totalColumns = 12,
  });

  final int y;
  final List<TscGridCol> children;
  final int gutter;
  final int totalColumns;

  @override
  Future<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) async {
    final gutterCount = math.max(0, children.length - 1);
    final usableWidth = context.width - gutter * gutterCount;
    var currentX = 0;
    var maxHeight = 0;

    for (final column in children) {
      final columnWidth = (usableWidth * column.width / totalColumns).round();
      final result = await column.child.applyWithContext(
        generator,
        context.nested(x: currentX, y: y, width: columnWidth),
      );
      maxHeight = math.max(maxHeight, result.height);
      currentX += columnWidth + gutter;
    }

    return TscLayoutResult(height: maxHeight);
  }
}

class TscTableHeader {
  const TscTableHeader(
    this.text, {
    this.alignment = TscAlignment.left,
    this.fontHeight = 22,
    this.fontWidth = 20,
  });

  final String text;
  final TscAlignment alignment;
  final int fontHeight;
  final int fontWidth;
}

class TscTable extends TscLabelCommand {
  const TscTable({
    required this.y,
    required this.columnWidths,
    required this.headers,
    required this.data,
    this.x = 0,
    this.totalColumns = 12,
    this.borderThickness = 1,
    this.cellPadding = 6,
    this.dataFontHeight = 18,
    this.dataFontWidth = 16,
  });

  final int x;
  final int y;
  final List<int> columnWidths;
  final List<TscTableHeader> headers;
  final List<List<String>> data;
  final int totalColumns;
  final int borderThickness;
  final int cellPadding;
  final int dataFontHeight;
  final int dataFontWidth;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    if (columnWidths.length != headers.length) {
      throw ArgumentError(
        'columnWidths and headers must have the same length.',
      );
    }

    final tableWidth = context.width - x;
    final columnPixelWidths = columnWidths
        .map((width) => (tableWidth * width / totalColumns).round())
        .toList();
    final drawX = context.originX + x;
    var currentY = context.originY + y;
    final headerHeight = _rowHeight(
      cells: headers.map((header) => header.text).toList(),
      columnWidths: columnPixelWidths,
      fontHeights: headers.map((header) => header.fontHeight).toList(),
      fontWidths: headers.map((header) => header.fontWidth).toList(),
      cellPadding: cellPadding,
      borderThickness: borderThickness,
    );

    _drawRow(
      generator,
      x: drawX,
      y: currentY,
      columnWidths: columnPixelWidths,
      rowHeight: headerHeight,
      cells: headers.map((header) => header.text).toList(),
      alignments: headers.map((header) => header.alignment).toList(),
      fontHeights: headers.map((header) => header.fontHeight).toList(),
      fontWidths: headers.map((header) => header.fontWidth).toList(),
      borderThickness: borderThickness,
      cellPadding: cellPadding,
    );

    currentY += headerHeight - borderThickness;

    for (final row in data) {
      final rowHeight = _rowHeight(
        cells: row,
        columnWidths: columnPixelWidths,
        fontHeights: List.filled(row.length, dataFontHeight),
        fontWidths: List.filled(row.length, dataFontWidth),
        cellPadding: cellPadding,
        borderThickness: borderThickness,
      );
      _drawRow(
        generator,
        x: drawX,
        y: currentY,
        columnWidths: columnPixelWidths,
        rowHeight: rowHeight,
        cells: row,
        alignments: List.filled(row.length, TscAlignment.left),
        fontHeights: List.filled(row.length, dataFontHeight),
        fontWidths: List.filled(row.length, dataFontWidth),
        borderThickness: borderThickness,
        cellPadding: cellPadding,
      );
      currentY += rowHeight - borderThickness;
    }

    return TscLayoutResult(height: currentY - (context.originY + y));
  }

  int _rowHeight({
    required List<String> cells,
    required List<int> columnWidths,
    required List<int> fontHeights,
    required List<int> fontWidths,
    required int cellPadding,
    required int borderThickness,
  }) {
    var maxHeight = 0;

    for (var i = 0; i < columnWidths.length; i++) {
      final value = i < cells.length ? cells[i] : '';
      final lines = _wrapText(
        value,
        maxWidth: math.max(1, columnWidths[i] - cellPadding * 2),
        fontWidth: fontWidths[i],
      );
      final contentHeight = math.max(1, lines.length) * fontHeights[i];
      maxHeight = math.max(
        maxHeight,
        contentHeight + cellPadding * 2 + borderThickness * 2,
      );
    }

    return maxHeight;
  }

  void _drawRow(
    TscGenerator generator, {
    required int x,
    required int y,
    required List<int> columnWidths,
    required int rowHeight,
    required List<String> cells,
    required List<TscAlignment> alignments,
    required List<int> fontHeights,
    required List<int> fontWidths,
    required int borderThickness,
    required int cellPadding,
  }) {
    var cellX = x;

    for (var i = 0; i < columnWidths.length; i++) {
      final cellWidth = columnWidths[i];
      final value = i < cells.length ? cells[i] : '';
      final fontHeight = fontHeights[i];
      final fontWidth = fontWidths[i];
      final lines = _wrapText(
        value,
        maxWidth: math.max(1, cellWidth - cellPadding * 2),
        fontWidth: fontWidth,
      );

      generator.box(
        cellX,
        y,
        cellX + cellWidth,
        y + rowHeight,
        thickness: borderThickness,
      );

      final contentWidth = math.max(0, cellWidth - cellPadding * 2).toInt();
      for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        final line = lines[lineIndex];
        final textWidth = _estimateTextWidth(line, fontWidth);
        final textX = switch (alignments[i]) {
          TscAlignment.left => cellX + cellPadding,
          TscAlignment.center =>
            cellX +
                cellPadding +
                math.max(0, (contentWidth - textWidth) ~/ 2).toInt(),
          TscAlignment.right =>
            cellX +
                cellWidth -
                cellPadding -
                math.min(textWidth, contentWidth).toInt(),
        };

        generator.text(
          textX,
          y + cellPadding + lineIndex * fontHeight,
          line,
          style: TscTextStyle(
            xMultiplier: _fontSizeToMultiplier(fontWidth),
            yMultiplier: _fontSizeToMultiplier(fontHeight),
          ),
        );
      }

      cellX += cellWidth - borderThickness;
    }
  }
}

class TscReceiptSection extends TscLabelCommand {
  const TscReceiptSection({
    required this.y,
    required this.title,
    required this.lines,
    this.x = 0,
    this.titleFontHeight = 26,
    this.titleFontWidth = 24,
    this.bodyFontHeight = 18,
    this.bodyFontWidth = 16,
    this.spacing = 8,
  });

  final int x;
  final int y;
  final String title;
  final List<String> lines;
  final int titleFontHeight;
  final int titleFontWidth;
  final int bodyFontHeight;
  final int bodyFontWidth;
  final int spacing;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    return TscColumn(
      spacing: spacing,
      children: [
        TscText(
          text: title,
          fontHeight: titleFontHeight,
          fontWidth: titleFontWidth,
        ),
        ...lines.map(
          (line) => TscText(
            text: line,
            fontHeight: bodyFontHeight,
            fontWidth: bodyFontWidth,
          ),
        ),
      ],
    ).applyWithContext(
      generator,
      context.nested(x: x, y: y, width: context.width - x),
    );
  }
}

class TscReceiptTotalLine {
  const TscReceiptTotalLine({
    required this.label,
    required this.value,
    this.fontHeight = 20,
    this.fontWidth = 18,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final int fontHeight;
  final int fontWidth;
  final bool emphasis;
}

class TscReceiptTotals extends TscLabelCommand {
  const TscReceiptTotals({
    required this.y,
    required this.lines,
    this.x = 0,
    this.width,
    this.showSeparatorBeforeLast = true,
    this.lineSpacing = 10,
    this.separatorThickness = 2,
    this.separatorPaddingLeft = 0,
    this.separatorPaddingRight = 0,
  });

  final int x;
  final int y;
  final int? width;
  final List<TscReceiptTotalLine> lines;
  final bool showSeparatorBeforeLast;
  final int lineSpacing;
  final int separatorThickness;
  final int separatorPaddingLeft;
  final int separatorPaddingRight;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    final contentWidth = width ?? (context.width - x);
    var currentY = y;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (showSeparatorBeforeLast &&
          i == lines.length - 1 &&
          lines.length > 1) {
        TscSeparator(
          y: currentY,
          thickness: separatorThickness,
          paddingLeft: separatorPaddingLeft,
          paddingRight: separatorPaddingRight,
        ).applyWithContext(
          generator,
          context.nested(x: x, width: contentWidth),
        );
        currentY += separatorThickness + lineSpacing;
      }

      final effectiveHeight = line.emphasis
          ? line.fontHeight + 4
          : line.fontHeight;
      TscText(
        x: 0,
        y: currentY,
        text: line.label,
        fontHeight: effectiveHeight,
        fontWidth: line.fontWidth,
      ).applyWithContext(generator, context.nested(x: x, width: contentWidth));
      TscText(
        y: currentY,
        text: line.value,
        fontHeight: effectiveHeight,
        fontWidth: line.fontWidth,
        alignment: TscAlignment.right,
      ).applyWithContext(generator, context.nested(x: x, width: contentWidth));

      currentY += effectiveHeight + lineSpacing;
    }

    return TscLayoutResult(height: currentY - y);
  }
}

class TscRawCommand extends TscLabelCommand {
  const TscRawCommand(this.command);

  final String command;

  @override
  FutureOr<void> apply(TscGenerator generator) {
    generator.rawCommand(command);
  }
}

int _fontSizeToMultiplier(int value) {
  return (value / 24).round().clamp(1, 10);
}

int _estimateTextWidth(String text, int fontWidth) {
  return math.max(1, (text.length * fontWidth * 0.62).round());
}

List<String> _wrapText(
  String text, {
  required int maxWidth,
  required int fontWidth,
}) {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return const [''];
  }

  final words = normalized.split(RegExp(r'\s+'));
  final lines = <String>[];
  var current = '';

  for (final word in words) {
    if (current.isEmpty) {
      if (_estimateTextWidth(word, fontWidth) <= maxWidth) {
        current = word;
      } else {
        lines.addAll(
          _breakLongWord(word, maxWidth: maxWidth, fontWidth: fontWidth),
        );
      }
      continue;
    }

    final candidate = '$current $word';
    if (_estimateTextWidth(candidate, fontWidth) <= maxWidth) {
      current = candidate;
      continue;
    }

    lines.add(current);
    if (_estimateTextWidth(word, fontWidth) <= maxWidth) {
      current = word;
    } else {
      final pieces = _breakLongWord(
        word,
        maxWidth: maxWidth,
        fontWidth: fontWidth,
      );
      lines.addAll(pieces.take(math.max(0, pieces.length - 1)));
      current = pieces.isEmpty ? '' : pieces.last;
    }
  }

  if (current.isNotEmpty) {
    lines.add(current);
  }

  return lines.isEmpty ? const [''] : lines;
}

List<String> _breakLongWord(
  String word, {
  required int maxWidth,
  required int fontWidth,
}) {
  final pieces = <String>[];
  var current = '';

  for (final rune in word.runes) {
    final char = String.fromCharCode(rune);
    final candidate = '$current$char';
    if (current.isNotEmpty &&
        _estimateTextWidth(candidate, fontWidth) > maxWidth) {
      pieces.add(current);
      current = char;
    } else {
      current = candidate;
    }
  }

  if (current.isNotEmpty) {
    pieces.add(current);
  }

  return pieces;
}

int _resolveAlignedX(int width, int itemWidth, TscAlignment? alignment) {
  return switch (alignment ?? TscAlignment.left) {
    TscAlignment.left => 0,
    TscAlignment.center => math.max(0, (width - itemWidth) ~/ 2),
    TscAlignment.right => math.max(0, width - itemWidth),
  };
}

TscTextAlignment? _toTextAlignment(TscAlignment? alignment) {
  return switch (alignment) {
    TscAlignment.left => TscTextAlignment.left,
    TscAlignment.center => TscTextAlignment.center,
    TscAlignment.right => TscTextAlignment.right,
    null => null,
  };
}
