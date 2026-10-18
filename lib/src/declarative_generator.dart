import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'enums.dart';
import 'generator.dart';
import 'label_size.dart';
import 'options.dart';
import 'rendered_text_options.dart';
import 'text_style.dart';

/// High-level builder that composes a label from declarative commands.
class TscLabelGenerator {
  /// Creates a declarative label generator.
  TscLabelGenerator({
    required this.config,
    required this.commands,
    this.newLine = '\r\n',
    this.codec = latin1,
  });

  /// Base printer configuration for the label.
  final TscLabelConfiguration config;

  /// Ordered commands used to draw label content.
  final List<TscLabelCommand> commands;

  /// New-line sequence used by the underlying command generator.
  final String newLine;

  /// Text encoding used for generated command output.
  final Encoding codec;

  /// Builds the TSPL output as a string.
  Future<String> build() async {
    final bytes = await buildBytes();
    return codec.decode(bytes);
  }

  /// Builds the TSPL output as raw bytes.
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

/// Global label settings applied before drawing commands.
class TscLabelConfiguration {
  /// Creates a label configuration.
  const TscLabelConfiguration({
    required this.printWidth,
    required this.labelLength,
    this.unit = TscUnit.dot,
    this.gap = 0,
    this.gapOffset = 0,
    this.media = TscMedia.gap,
    this.offset,
    this.speed,
    this.printDensity,
    this.direction = TscDirection.forward,
    this.mirror = TscMirror.normal,
    this.referenceX = 0,
    this.referenceY = 0,
    this.clearBuffer = true,
    this.codePage,
    this.copies = 1,
    this.sets = 1,
    this.peel,
    this.tear,
    this.back,
    this.ribbon,
    this.rewind,
    this.cutter,
    this.partialCutter,
  });

  /// Printable width.
  final num printWidth;

  /// Label length.
  final num labelLength;

  /// Measurement unit used for size and gap.
  final TscUnit unit;

  /// Gap height between labels.
  final num gap;

  /// Gap sensor offset, or black-mark offset when [media] is [TscMedia.blackMark].
  final num gapOffset;

  /// Label sensing mode. Defaults to [TscMedia.gap].
  final TscMedia media;

  /// Optional vertical print offset, in [unit].
  final num? offset;

  /// Optional print speed in inches per second.
  final num? speed;

  /// Optional print density.
  final TscPrintDensity? printDensity;

  /// Print direction.
  final TscDirection direction;

  /// Mirror mode.
  final TscMirror mirror;

  /// X origin reference.
  final int referenceX;

  /// Y origin reference.
  final int referenceY;

  /// Whether to clear print buffer before drawing.
  final bool clearBuffer;

  /// Optional code page name.
  final String? codePage;

  /// Number of copies.
  final int copies;

  /// Number of sets.
  final int sets;

  /// Optional `SET PEEL` state.
  final TscToggle? peel;

  /// Optional `SET TEAR` state.
  final TscToggle? tear;

  /// Optional `SET BACK` state.
  final TscToggle? back;

  /// Optional `SET RIBBON` state.
  final TscToggle? ribbon;

  /// Optional `SET REWIND` mode.
  final TscRewindMode? rewind;

  /// Optional full-cutter behavior.
  final TscCutterSetting? cutter;

  /// Optional partial-cutter behavior.
  final TscCutterSetting? partialCutter;

  /// Applies this configuration to [generator].
  void apply(TscGenerator generator) {
    generator.size(TscLabelSize(printWidth, labelLength, unit: unit));
    switch (media) {
      case TscMedia.gap:
        generator.gap(gap, gapOffset, unit: unit);
      case TscMedia.blackMark:
        generator.bline(gap, gapOffset, unit: unit);
      case TscMedia.continuous:
        generator.gap(0, 0, unit: unit);
    }

    if (offset != null) {
      generator.offset(offset!, unit: unit);
    }
    if (speed != null) {
      generator.speed(speed!);
    }
    if (printDensity != null) {
      generator.density(printDensity!.value);
    }

    generator
      ..direction(direction, mirror: mirror)
      ..reference(referenceX, referenceY);

    if (peel != null) {
      generator.setPeel(peel!);
    }
    if (tear != null) {
      generator.setTear(tear!);
    }
    if (back != null) {
      generator.setBack(back!);
    }
    if (ribbon != null) {
      generator.setRibbon(ribbon!);
    }
    if (rewind != null) {
      generator.setRewind(rewind!);
    }
    cutter?.apply(generator);
    partialCutter?.apply(generator, partial: true);

    if (codePage != null && codePage!.isNotEmpty) {
      generator.codePage(codePage!);
    }

    if (clearBuffer) {
      generator.cls();
    }
  }
}

/// Cutter behavior for `SET CUTTER` and `SET PARTIAL_CUTTER`.
class TscCutterSetting {
  /// Disables the cutter.
  const TscCutterSetting.off() : _every = null, batch = false;

  /// Cuts after every [every] labels.
  const TscCutterSetting.every(int every) : _every = every, batch = false;

  /// Cuts once when the print job finishes.
  const TscCutterSetting.batch() : _every = null, batch = true;

  final int? _every;

  /// Label interval for counted cuts, or null for off/batch modes.
  int? get every => _every;

  /// Whether this setting uses batch mode.
  final bool batch;

  /// Applies this setting to [generator].
  void apply(TscGenerator generator, {bool partial = false}) {
    if (partial) {
      generator.setPartialCutter(every: every, batch: batch);
    } else {
      generator.setCutter(every: every, batch: batch);
    }
  }
}

/// Horizontal alignment for declarative widgets.
enum TscAlignment { left, center, right }

/// Runtime layout context passed to declarative commands.
class TscBuildContext {
  /// Creates a build context.
  const TscBuildContext({
    required this.originX,
    required this.originY,
    required this.width,
    required this.height,
    this.cursorY = 0,
  });

  /// Creates a root context from [config].
  factory TscBuildContext.root(TscLabelConfiguration config) {
    return TscBuildContext(
      originX: 0,
      originY: 0,
      width: config.printWidth.round(),
      height: config.labelLength.round(),
    );
  }

  /// Absolute x-origin for the current context.
  final int originX;

  /// Absolute y-origin for the current context.
  final int originY;

  /// Available width in dots.
  final int width;

  /// Available height in dots.
  final int height;

  /// Current vertical cursor in dots.
  final int cursorY;

  /// Returns a copy with updated cursor.
  TscBuildContext withCursor(int value) {
    return TscBuildContext(
      originX: originX,
      originY: originY,
      width: width,
      height: height,
      cursorY: value,
    );
  }

  /// Returns a nested context offset from the current one.
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

/// Result of laying out a declarative command.
class TscLayoutResult {
  /// Creates a layout result.
  const TscLayoutResult({this.height = 0});

  /// Vertical space consumed by this command.
  final int height;
}

/// Base class for declarative label commands.
abstract class TscLabelCommand {
  /// Creates a label command.
  const TscLabelCommand();

  /// Applies this command without layout context.
  FutureOr<void> apply(TscGenerator generator) {}

  /// Applies this command with layout context information.
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) async {
    await apply(generator);
    return const TscLayoutResult();
  }
}

/// Declarative text command.
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

  /// Horizontal placement. [x] is the printer anchor for this alignment.
  /// When [x] is omitted, the anchor is the matching edge of the layout width.
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

    final drawX =
        context.originX + _resolveAnchorX(context.width, x, alignment);
    final drawY = context.originY + (y ?? context.cursorY);

    generator.text(drawX, drawY, text, style: resolvedStyle);
    return TscLayoutResult(height: (y == null ? effectiveFontHeight + 8 : 0));
  }
}

/// Declarative 1D barcode command.
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

  /// Horizontal placement. [x] is the printer anchor for this alignment.
  final TscAlignment? alignment;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    final drawX =
        context.originX + _resolveAnchorX(context.width, x, alignment);
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

/// Declarative QR code command.
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

  /// Horizontal placement. [x] is the printer anchor for this alignment.
  final TscAlignment? alignment;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    final estimatedSize = cellWidth.value * 24;
    final drawX =
        context.originX + _resolveAnchorX(context.width, x, alignment);
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

/// Declarative bitmap draw command.
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

/// Declarative rendered-text command.
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

/// Horizontal separator line.
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

/// Vertical stack layout command.
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

/// Grid column definition.
class TscGridCol {
  const TscGridCol({required this.width, required this.child});

  final int width;
  final TscLabelCommand child;
}

/// Grid row layout command.
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

/// Table header cell configuration.
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

/// Declarative table command.
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
        fontHeights: List.filled(columnPixelWidths.length, dataFontHeight),
        fontWidths: List.filled(columnPixelWidths.length, dataFontWidth),
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
        alignments: [
          for (var column = 0; column < columnPixelWidths.length; column++)
            column < headers.length
                ? headers[column].alignment
                : TscAlignment.left,
        ],
        fontHeights: List.filled(columnPixelWidths.length, dataFontHeight),
        fontWidths: List.filled(columnPixelWidths.length, dataFontWidth),
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

/// Section block with heading and list lines.
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

/// One total line entry used by [TscReceiptTotals].
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

/// Totals block for receipts.
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

/// Filled rectangle drawn with the `BAR` command.
class TscBar extends TscLabelCommand {
  /// Creates a filled rectangle.
  const TscBar({this.x, this.y, required this.width, required this.height});

  /// Left edge in dots. Defaults to the current origin.
  final int? x;

  /// Top edge in dots. Defaults to the layout cursor.
  final int? y;

  /// Rectangle width in dots.
  final int width;

  /// Rectangle height in dots.
  final int height;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    generator.bar(
      context.originX + (x ?? 0),
      context.originY + (y ?? context.cursorY),
      width,
      height,
    );
    return TscLayoutResult(height: y == null ? height : 0);
  }
}

/// Rectangular outline drawn with the `BOX` command.
class TscBox extends TscLabelCommand {
  /// Creates a rectangular outline.
  const TscBox({
    this.x,
    this.y,
    required this.width,
    required this.height,
    this.thickness = 1,
  });

  /// Left edge in dots. Defaults to the current origin.
  final int? x;

  /// Top edge in dots. Defaults to the layout cursor.
  final int? y;

  /// Box width in dots. The TSPL end coordinate is origin plus this width.
  final int width;

  /// Box height in dots. The TSPL end coordinate is origin plus this height.
  final int height;

  /// Stroke thickness in dots.
  final int thickness;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    final drawX = context.originX + (x ?? 0);
    final drawY = context.originY + (y ?? context.cursorY);
    generator.box(
      drawX,
      drawY,
      drawX + width,
      drawY + height,
      thickness: thickness,
    );
    return TscLayoutResult(height: y == null ? height : 0);
  }
}

/// Multi-line text region drawn with the `BLOCK` command.
class TscBlock extends TscLabelCommand {
  /// Creates a block of wrapped text.
  const TscBlock({
    this.x,
    this.y,
    required this.width,
    required this.height,
    required this.text,
    this.style = const TscTextStyle(),
    this.fontHeight,
    this.fontWidth,
    this.space,
    this.alignment = TscBlockAlignment.left,
    this.fit = false,
  });

  /// Left edge in dots. Defaults to the current origin.
  final int? x;

  /// Top edge in dots. Defaults to the layout cursor.
  final int? y;

  /// Block width in dots.
  final int width;

  /// Block height in dots.
  final int height;

  /// Text drawn inside the block.
  final String text;

  /// Base printer font and rotation.
  final TscTextStyle style;

  /// Optional font height in dots. Overrides [style] y-multiplier.
  final int? fontHeight;

  /// Optional font width in dots. Overrides [style] x-multiplier.
  final int? fontWidth;

  /// Extra space between lines, in dots.
  final int? space;

  /// Horizontal alignment inside the block.
  final TscBlockAlignment alignment;

  /// Whether the printer should fit the text into the block.
  final bool fit;

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
    );
    generator.block(
      context.originX + (x ?? 0),
      context.originY + (y ?? context.cursorY),
      width,
      height,
      text,
      style: resolvedStyle,
      space: space,
      alignment: alignment,
      fit: fit,
    );
    return TscLayoutResult(height: y == null ? height : 0);
  }
}

/// Clears a rectangle in the image buffer with the `ERASE` command.
class TscErase extends TscLabelCommand {
  /// Creates an erase region.
  const TscErase({this.x, this.y, required this.width, required this.height});

  /// Left edge in dots. Defaults to the current origin.
  final int? x;

  /// Top edge in dots. Defaults to the layout cursor.
  final int? y;

  /// Region width in dots.
  final int width;

  /// Region height in dots.
  final int height;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    generator.erase(
      context.originX + (x ?? 0),
      context.originY + (y ?? context.cursorY),
      width,
      height,
    );
    return TscLayoutResult(height: y == null ? height : 0);
  }
}

/// Inverts a rectangle with the `REVERSE` command.
class TscReverse extends TscLabelCommand {
  /// Creates an invert region.
  const TscReverse({this.x, this.y, required this.width, required this.height});

  /// Left edge in dots. Defaults to the current origin.
  final int? x;

  /// Top edge in dots. Defaults to the layout cursor.
  final int? y;

  /// Region width in dots.
  final int width;

  /// Region height in dots.
  final int height;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    generator.reverse(
      context.originX + (x ?? 0),
      context.originY + (y ?? context.cursorY),
      width,
      height,
    );
    return TscLayoutResult(height: y == null ? height : 0);
  }
}

/// PDF417 symbol drawn with the `PDF417` command.
class TscPdf417 extends TscLabelCommand {
  /// Creates a PDF417 symbol.
  const TscPdf417({
    this.x,
    this.y,
    required this.width,
    required this.height,
    required this.data,
    this.rotation = TscRotation.angle0,
    this.options = const TscPdf417Options(),
    this.alignment,
  });

  /// Left edge in dots. Defaults to alignment within the current context.
  final int? x;

  /// Top edge in dots. Defaults to the layout cursor.
  final int? y;

  /// Symbol width in dots.
  final int width;

  /// Symbol height in dots.
  final int height;

  /// Payload encoded in the symbol.
  final String data;

  /// Symbol rotation.
  final TscRotation rotation;

  /// Optional PDF417 encoding options.
  final TscPdf417Options options;

  /// Horizontal placement when [x] is omitted.
  final TscAlignment? alignment;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    final drawX =
        context.originX +
        (x ?? _resolveAlignedX(context.width, width, alignment));
    final drawY = context.originY + (y ?? context.cursorY);
    generator.pdf417(
      drawX,
      drawY,
      width,
      height,
      data,
      rotation: rotation,
      options: options,
    );
    return TscLayoutResult(height: y == null ? height + 8 : 0);
  }
}

/// Data Matrix symbol drawn with the `DMATRIX` command.
class TscDataMatrix extends TscLabelCommand {
  /// Creates a Data Matrix symbol.
  const TscDataMatrix({
    this.x,
    this.y,
    required this.width,
    required this.height,
    required this.data,
    this.options = const TscDataMatrixOptions(),
    this.alignment,
  });

  /// Left edge in dots. Defaults to alignment within the current context.
  final int? x;

  /// Top edge in dots. Defaults to the layout cursor.
  final int? y;

  /// Symbol width in dots.
  final int width;

  /// Symbol height in dots.
  final int height;

  /// Payload encoded in the symbol.
  final String data;

  /// Optional Data Matrix encoding options.
  final TscDataMatrixOptions options;

  /// Horizontal placement when [x] is omitted.
  final TscAlignment? alignment;

  @override
  FutureOr<TscLayoutResult> applyWithContext(
    TscGenerator generator,
    TscBuildContext context,
  ) {
    final drawX =
        context.originX +
        (x ?? _resolveAlignedX(context.width, width, alignment));
    final drawY = context.originY + (y ?? context.cursorY);
    generator.dataMatrix(drawX, drawY, width, height, data, options: options);
    return TscLayoutResult(height: y == null ? height + 8 : 0);
  }
}

/// Injects a raw TSPL command line.
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
  final normalized = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalized.isEmpty) {
    return const [''];
  }

  final lines = <String>[];
  for (final rawParagraph in normalized.split('\n')) {
    final paragraph = rawParagraph.trim();
    if (paragraph.isEmpty) {
      lines.add('');
      continue;
    }
    lines.addAll(
      _wrapParagraph(paragraph, maxWidth: maxWidth, fontWidth: fontWidth),
    );
  }

  return lines.isEmpty ? const [''] : lines;
}

List<String> _wrapParagraph(
  String paragraph, {
  required int maxWidth,
  required int fontWidth,
}) {
  final words = paragraph.split(RegExp(r'\s+'));
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

  return lines;
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

/// TSPL anchor for [alignment]. An explicit [x] is that anchor.
/// Otherwise the anchor is the left edge, midpoint, or right edge of [width].
int _resolveAnchorX(int width, int? x, TscAlignment? alignment) {
  if (x != null) {
    return x;
  }

  return switch (alignment ?? TscAlignment.left) {
    TscAlignment.left => 0,
    TscAlignment.center => width ~/ 2,
    TscAlignment.right => width,
  };
}

/// Left edge for commands that have no printer alignment argument.
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
