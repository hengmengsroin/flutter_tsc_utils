import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'declarative_generator.dart';
import 'enums.dart';

class TscPreview extends StatefulWidget {
  const TscPreview({
    super.key,
    required this.generator,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = const Color(0xFFFFFEF8),
    this.borderColor = const Color(0xFFE7DFC9),
    this.showDebugOverlay = false,
  });

  final TscLabelGenerator generator;
  final EdgeInsets padding;
  final Color backgroundColor;
  final Color borderColor;
  final bool showDebugOverlay;

  @override
  State<TscPreview> createState() => _TscPreviewState();
}

class _TscPreviewState extends State<TscPreview> {
  Future<String>? _commandFuture;

  @override
  void initState() {
    super.initState();
    _refreshPreview();
  }

  @override
  void didUpdateWidget(covariant TscPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generator != widget.generator) {
      _refreshPreview();
    }
  }

  void _refreshPreview() {
    _commandFuture = widget.generator.build();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.generator.config;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : config.printWidth.toDouble();
        final metrics = _resolvePreviewMetrics(
          availableWidth: availableWidth,
          printWidth: config.printWidth.toDouble(),
          labelLength: config.labelLength.toDouble(),
        );
        final compact = availableWidth < 420;

        return FutureBuilder<String>(
          future: _commandFuture,
          builder: (context, snapshot) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: compact
                        ? const EdgeInsets.all(12)
                        : widget.padding,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F0E6),
                      borderRadius: BorderRadius.circular(compact ? 18 : 24),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: metrics.width,
                        height: metrics.height,
                        child: _PreviewCanvas(
                          generator: widget.generator,
                          width: metrics.width,
                          height: metrics.height,
                          backgroundColor: widget.backgroundColor,
                          borderColor: widget.borderColor,
                          showDebugOverlay: widget.showDebugOverlay,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1320),
                      borderRadius: BorderRadius.circular(compact ? 14 : 18),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 12 : 14),
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? const SizedBox(
                              height: 72,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SelectableText(
                                snapshot.hasError
                                    ? 'Preview build failed: ${snapshot.error}'
                                    : _trimCommandPreview(snapshot.data ?? ''),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: Color(0xFFD9F99D),
                                  height: 1.4,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PreviewCanvas extends StatelessWidget {
  const _PreviewCanvas({
    required this.generator,
    required this.width,
    required this.height,
    required this.backgroundColor,
    required this.borderColor,
    required this.showDebugOverlay,
  });

  final TscLabelGenerator generator;
  final double width;
  final double height;
  final Color backgroundColor;
  final Color borderColor;
  final bool showDebugOverlay;

  @override
  Widget build(BuildContext context) {
    final config = generator.config;
    final scaleX = width / config.printWidth;
    final scaleY = height / config.labelLength;
    final previewContext = _PreviewLayoutContext(
      originX: 0,
      originY: 0,
      width: config.printWidth.round(),
      height: config.labelLength.round(),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            for (final command in generator.commands)
              ..._layoutCommandWidgets(
                context,
                command,
                previewContext,
                scaleX,
                scaleY,
              ).widgets,
            if (showDebugOverlay)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _GridPainter()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  _PreviewBuildResult _layoutCommandWidgets(
    BuildContext context,
    TscLabelCommand command,
    _PreviewLayoutContext previewContext,
    double scaleX,
    double scaleY,
  ) {
    if (command is TscText) {
      final fontSize = math.max(
        10.0,
        (command.fontHeight ?? (12.0 * command.style.yMultiplier)).toDouble(),
      );
      final textStyle = TextStyle(
        color: Colors.black,
        fontSize: fontSize * scaleY,
        fontWeight: FontWeight.w600,
      );
      final estimatedWidth = _measurePreviewTextWidth(
        command.text,
        textStyle,
        scaleY: scaleY,
      );
      final localX = _previewLeft(
        x: command.x,
        availableWidth: previewContext.width,
        itemWidth: estimatedWidth,
        alignment: command.alignment,
      );
      final localY = command.y ?? previewContext.cursorY;
      return _PreviewBuildResult(
        widgets: [
          Positioned(
            left: (previewContext.originX + localX) * scaleX,
            top: (previewContext.originY + localY) * scaleY,
            child: Transform.rotate(
              angle: command.style.rotation.value * math.pi / 180,
              alignment: Alignment.topLeft,
              child: Text(command.text, style: textStyle),
            ),
          ),
        ],
        height: command.y == null ? fontSize.ceil() + 8 : 0,
      );
    }

    if (command is TscColumn) {
      final widgets = <Widget>[];
      var cursor = previewContext.cursorY;
      var consumed = 0;

      for (var i = 0; i < command.children.length; i++) {
        final result = _layoutCommandWidgets(
          context,
          command.children[i],
          previewContext.copyWith(cursorY: cursor),
          scaleX,
          scaleY,
        );
        widgets.addAll(result.widgets);
        if (result.height > 0) {
          cursor += result.height;
          consumed += result.height;
          if (i != command.children.length - 1) {
            cursor += command.spacing;
            consumed += command.spacing;
          }
        }
      }

      return _PreviewBuildResult(widgets: widgets, height: consumed);
    }

    if (command is TscGridRow) {
      final widgets = <Widget>[];
      final gutterCount = math.max(0, command.children.length - 1);
      final usableWidth = previewContext.width - command.gutter * gutterCount;
      var currentX = 0;
      var maxHeight = 0;

      for (final column in command.children) {
        final columnWidth = (usableWidth * column.width / command.totalColumns)
            .round();
        final result = _layoutCommandWidgets(
          context,
          column.child,
          previewContext.nested(x: currentX, y: command.y, width: columnWidth),
          scaleX,
          scaleY,
        );
        widgets.addAll(result.widgets);
        maxHeight = math.max(maxHeight, result.height);
        currentX += columnWidth + command.gutter;
      }

      return _PreviewBuildResult(widgets: widgets, height: maxHeight);
    }

    if (command is TscReceiptSection) {
      return _layoutCommandWidgets(
        context,
        TscColumn(
          spacing: command.spacing,
          children: [
            TscText(
              text: command.title,
              fontHeight: command.titleFontHeight,
              fontWidth: command.titleFontWidth,
            ),
            ...command.lines.map(
              (line) => TscText(
                text: line,
                fontHeight: command.bodyFontHeight,
                fontWidth: command.bodyFontWidth,
              ),
            ),
          ],
        ),
        previewContext.nested(
          x: command.x,
          y: command.y,
          width: previewContext.width - command.x,
        ),
        scaleX,
        scaleY,
      );
    }

    if (command is TscReceiptTotals) {
      final widgets = <Widget>[];
      final contentWidth = command.width ?? (previewContext.width - command.x);
      var currentY = command.y;

      for (var i = 0; i < command.lines.length; i++) {
        final line = command.lines[i];
        if (command.showSeparatorBeforeLast &&
            i == command.lines.length - 1 &&
            command.lines.length > 1) {
          final separator = _layoutCommandWidgets(
            context,
            TscSeparator(
              y: currentY,
              thickness: command.separatorThickness,
              paddingLeft: command.separatorPaddingLeft,
              paddingRight: command.separatorPaddingRight,
            ),
            previewContext.nested(x: command.x, width: contentWidth),
            scaleX,
            scaleY,
          );
          widgets.addAll(separator.widgets);
          currentY += command.separatorThickness + command.lineSpacing;
        }

        final effectiveHeight = line.emphasis
            ? line.fontHeight + 4
            : line.fontHeight;
        widgets.addAll(
          _layoutCommandWidgets(
            context,
            TscText(
              x: 0,
              y: currentY,
              text: line.label,
              fontHeight: effectiveHeight,
              fontWidth: line.fontWidth,
            ),
            previewContext.nested(x: command.x, width: contentWidth),
            scaleX,
            scaleY,
          ).widgets,
        );
        widgets.addAll(
          _layoutCommandWidgets(
            context,
            TscText(
              y: currentY,
              text: line.value,
              fontHeight: effectiveHeight,
              fontWidth: line.fontWidth,
              alignment: TscAlignment.right,
            ),
            previewContext.nested(x: command.x, width: contentWidth),
            scaleX,
            scaleY,
          ).widgets,
        );
        currentY += effectiveHeight + command.lineSpacing;
      }

      return _PreviewBuildResult(
        widgets: widgets,
        height: currentY - command.y,
      );
    }

    if (command is TscRenderedText) {
      final localX = command.x ?? 0;
      final localY = command.y ?? previewContext.cursorY;
      return _PreviewBuildResult(
        widgets: [
          Positioned(
            left: (previewContext.originX + localX) * scaleX,
            top: (previewContext.originY + localY) * scaleY,
            child: Text(
              command.text,
              style: command.options.style.copyWith(
                color: Colors.black,
                fontSize: (command.options.style.fontSize ?? 14) * scaleY,
              ),
            ),
          ),
        ],
        height: command.y == null
            ? ((command.options.style.fontSize ?? 24) * scaleY).ceil() + 8
            : 0,
      );
    }

    if (command is TscBarcode) {
      final barcodeWidth = math.max(
        96.0,
        command.data.length * (command.narrow + command.wide) * 3.0,
      );
      final localX = _previewLeft(
        x: command.x,
        availableWidth: previewContext.width,
        itemWidth: barcodeWidth.round(),
        alignment: command.alignment,
      );
      final localY = command.y ?? previewContext.cursorY;
      return _PreviewBuildResult(
        widgets: [
          Positioned(
            left: (previewContext.originX + localX) * scaleX,
            top: (previewContext.originY + localY) * scaleY,
            child: Transform.rotate(
              angle: 0,
              child: SizedBox(
                width: barcodeWidth * scaleX,
                height:
                    (command.height +
                        (command.printInterpretationLine ? 24 : 0)) *
                    scaleY,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: CustomPaint(
                        painter: _BarcodePainter(seed: command.data.hashCode),
                      ),
                    ),
                    if (command.printInterpretationLine)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          command.data,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: math.max(9, 10 * scaleY),
                            color: Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        height: command.y == null
            ? command.height + (command.printInterpretationLine ? 24 : 0) + 8
            : 0,
      );
    }

    if (command is TscQrCode) {
      final size = command.cellWidth.value * 24.0;
      final localX = _previewLeft(
        x: command.x,
        availableWidth: previewContext.width,
        itemWidth: size.round(),
        alignment: command.alignment,
      );
      final localY = command.y ?? previewContext.cursorY;
      return _PreviewBuildResult(
        widgets: [
          Positioned(
            left: (previewContext.originX + localX) * scaleX,
            top: (previewContext.originY + localY) * scaleY,
            child: SizedBox(
              width: size * scaleX,
              height: size * scaleY,
              child: CustomPaint(
                painter: _QrPainter(seed: command.data.hashCode),
              ),
            ),
          ),
        ],
        height: command.y == null ? size.ceil() + 8 : 0,
      );
    }

    if (command is TscBitmap) {
      final bytes = Uint8List.fromList(img.encodePng(command.image));
      final localX = command.x ?? 0;
      final localY = command.y ?? previewContext.cursorY;
      return _PreviewBuildResult(
        widgets: [
          Positioned(
            left: (previewContext.originX + localX) * scaleX,
            top: (previewContext.originY + localY) * scaleY,
            child: Image.memory(
              bytes,
              filterQuality: FilterQuality.none,
              gaplessPlayback: true,
              width: command.image.width * scaleX,
              height: command.image.height * scaleY,
            ),
          ),
        ],
        height: command.y == null ? command.image.height + 8 : 0,
      );
    }

    if (command is TscBar) {
      return _positionedFill(
        previewContext: previewContext,
        x: command.x ?? 0,
        y: command.y ?? previewContext.cursorY,
        width: command.width,
        height: command.height,
        scaleX: scaleX,
        scaleY: scaleY,
        color: Colors.black,
        consumedHeight: command.y == null ? command.height : 0,
      );
    }

    if (command is TscBox) {
      final localX = command.x ?? 0;
      final localY = command.y ?? previewContext.cursorY;
      return _PreviewBuildResult(
        widgets: [
          Positioned(
            left: (previewContext.originX + localX) * scaleX,
            top: (previewContext.originY + localY) * scaleY,
            child: Container(
              width: math.max(1, command.width) * scaleX,
              height: math.max(1, command.height) * scaleY,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black,
                  width: math.max(1, command.thickness * scaleX),
                ),
              ),
            ),
          ),
        ],
        height: command.y == null ? command.height : 0,
      );
    }

    if (command is TscBlock) {
      return _buildBlockPreview(command, previewContext, scaleX, scaleY);
    }

    if (command is TscErase) {
      return _positionedFill(
        previewContext: previewContext,
        x: command.x ?? 0,
        y: command.y ?? previewContext.cursorY,
        width: command.width,
        height: command.height,
        scaleX: scaleX,
        scaleY: scaleY,
        color: backgroundColor,
        consumedHeight: command.y == null ? command.height : 0,
      );
    }

    if (command is TscReverse) {
      final localX = command.x ?? 0;
      final localY = command.y ?? previewContext.cursorY;
      return _PreviewBuildResult(
        widgets: [
          Positioned(
            left: (previewContext.originX + localX) * scaleX,
            top: (previewContext.originY + localY) * scaleY,
            width: math.max(1, command.width) * scaleX,
            height: math.max(1, command.height) * scaleY,
            child: const CustomPaint(
              painter: _ReversePainter(),
              child: SizedBox.expand(),
            ),
          ),
        ],
        height: command.y == null ? command.height : 0,
      );
    }

    if (command is TscPdf417) {
      final localX =
          command.x ??
          _resolveAlignedX(
            previewContext.width,
            command.width,
            command.alignment,
          );
      final localY = command.y ?? previewContext.cursorY;
      return _PreviewBuildResult(
        widgets: [
          Positioned(
            left: (previewContext.originX + localX) * scaleX,
            top: (previewContext.originY + localY) * scaleY,
            child: SizedBox(
              width: math.max(1, command.width) * scaleX,
              height: math.max(1, command.height) * scaleY,
              child: CustomPaint(
                painter: _Pdf417Painter(seed: command.data.hashCode),
              ),
            ),
          ),
        ],
        height: command.y == null ? command.height + 8 : 0,
      );
    }

    if (command is TscDataMatrix) {
      final localX =
          command.x ??
          _resolveAlignedX(
            previewContext.width,
            command.width,
            command.alignment,
          );
      final localY = command.y ?? previewContext.cursorY;
      return _PreviewBuildResult(
        widgets: [
          Positioned(
            left: (previewContext.originX + localX) * scaleX,
            top: (previewContext.originY + localY) * scaleY,
            child: SizedBox(
              width: math.max(1, command.width) * scaleX,
              height: math.max(1, command.height) * scaleY,
              child: CustomPaint(
                painter: _MatrixPainter(seed: command.data.hashCode),
              ),
            ),
          ),
        ],
        height: command.y == null ? command.height + 8 : 0,
      );
    }

    if (command is TscSeparator) {
      return _PreviewBuildResult(
        widgets: [
          Positioned(
            left: (previewContext.originX + command.paddingLeft) * scaleX,
            top: (previewContext.originY + command.y) * scaleY,
            child: Container(
              width: math.max(
                1,
                (previewContext.width -
                        command.paddingLeft -
                        command.paddingRight) *
                    scaleX,
              ),
              height: math.max(1, command.thickness * scaleY),
              color: Colors.black87,
            ),
          ),
        ],
      );
    }

    if (command is TscTable) {
      return _buildTablePreview(command, previewContext, scaleX, scaleY);
    }

    return const _PreviewBuildResult();
  }

  _PreviewBuildResult _buildTablePreview(
    TscTable command,
    _PreviewLayoutContext previewContext,
    double scaleX,
    double scaleY,
  ) {
    final widgets = <Widget>[];
    final tableWidth = previewContext.width - command.x;
    final columnPixelWidths = command.columnWidths
        .map((width) => (tableWidth * width / command.totalColumns).round())
        .toList();
    var currentY = previewContext.originY + command.y;
    final originX = previewContext.originX + command.x;

    int rowHeight(List<String> cells, List<int> fontHeights) {
      var maxHeight = 0;
      for (var i = 0; i < columnPixelWidths.length; i++) {
        final value = i < cells.length ? cells[i] : '';
        final textStyle = TextStyle(
          color: Colors.black,
          fontSize: math.max(9, fontHeights[i] * scaleY),
          fontWeight: FontWeight.w600,
        );
        final lines = _wrapText(
          value,
          maxWidth: math.max(1, columnPixelWidths[i] - command.cellPadding * 2),
          style: textStyle,
          scaleY: scaleY,
        );
        maxHeight = math.max(
          maxHeight,
          math.max(1, lines.length) * fontHeights[i] +
              command.cellPadding * 2 +
              command.borderThickness * 2,
        );
      }
      return maxHeight;
    }

    void drawRow(
      List<String> cells,
      List<TscAlignment> alignments,
      List<int> fontHeights,
      int height,
    ) {
      var cellX = originX;
      for (var i = 0; i < columnPixelWidths.length; i++) {
        final cellWidth = columnPixelWidths[i];
        widgets.add(
          Positioned(
            left: cellX * scaleX,
            top: currentY * scaleY,
            child: Container(
              width: cellWidth * scaleX,
              height: height * scaleY,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black87,
                  width: math.max(1, command.borderThickness * scaleX),
                ),
              ),
            ),
          ),
        );

        final value = i < cells.length ? cells[i] : '';
        final textStyle = TextStyle(
          color: Colors.black,
          fontSize: math.max(9, fontHeights[i] * scaleY),
          fontWeight: FontWeight.w600,
        );
        final lines = _wrapText(
          value,
          maxWidth: math.max(1, cellWidth - command.cellPadding * 2),
          style: textStyle,
          scaleY: scaleY,
        );
        for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
          final line = lines[lineIndex];
          final textWidth = _measurePreviewTextWidth(
            line,
            textStyle,
            scaleY: scaleY,
          );
          final contentWidth = math.max(0, cellWidth - command.cellPadding * 2);
          final textX = switch (alignments[i]) {
            TscAlignment.left => cellX + command.cellPadding,
            TscAlignment.center =>
              cellX +
                  command.cellPadding +
                  math.max(0, (contentWidth - textWidth) ~/ 2),
            TscAlignment.right =>
              cellX +
                  cellWidth -
                  command.cellPadding -
                  math.min(textWidth, contentWidth).toInt(),
          };

          widgets.add(
            Positioned(
              left: textX * scaleX,
              top:
                  (currentY +
                      command.cellPadding +
                      lineIndex * fontHeights[i]) *
                  scaleY,
              child: Text(line, style: textStyle),
            ),
          );
        }

        cellX += cellWidth - command.borderThickness;
      }
    }

    final headerHeight = rowHeight(
      command.headers.map((header) => header.text).toList(),
      command.headers.map((header) => header.fontHeight).toList(),
    );
    drawRow(
      command.headers.map((header) => header.text).toList(),
      command.headers.map((header) => header.alignment).toList(),
      command.headers.map((header) => header.fontHeight).toList(),
      headerHeight,
    );
    currentY += headerHeight - command.borderThickness;

    for (final row in command.data) {
      final dataHeight = rowHeight(
        row,
        List.filled(command.columnWidths.length, command.dataFontHeight),
      );
      drawRow(
        row,
        [
          for (var column = 0; column < command.columnWidths.length; column++)
            column < command.headers.length
                ? command.headers[column].alignment
                : TscAlignment.left,
        ],
        List.filled(command.columnWidths.length, command.dataFontHeight),
        dataHeight,
      );
      currentY += dataHeight - command.borderThickness;
    }

    return _PreviewBuildResult(
      widgets: widgets,
      height: currentY - (previewContext.originY + command.y),
    );
  }

  _PreviewBuildResult _buildBlockPreview(
    TscBlock command,
    _PreviewLayoutContext previewContext,
    double scaleX,
    double scaleY,
  ) {
    final fontSize = math.max(
      10.0,
      (command.fontHeight ?? (12.0 * command.style.yMultiplier)).toDouble(),
    );
    final textStyle = TextStyle(
      color: Colors.black,
      fontSize: fontSize * scaleY,
      fontWeight: FontWeight.w600,
    );
    final localX = command.x ?? 0;
    final localY = command.y ?? previewContext.cursorY;
    final lines = _wrapText(
      command.text,
      maxWidth: math.max(1, command.width),
      style: textStyle,
      scaleY: scaleY,
    );
    final lineAdvance = fontSize + (command.space ?? 0);

    double lineLeft(String line) {
      final textWidth = _measurePreviewTextWidth(
        line,
        textStyle,
        scaleY: scaleY,
      );
      return switch (command.alignment) {
        TscBlockAlignment.left || TscBlockAlignment.justified => 0,
        TscBlockAlignment.center => math.max(
          0,
          (command.width - textWidth) / 2,
        ),
        TscBlockAlignment.right => math.max(
          0,
          command.width - textWidth.toDouble(),
        ),
      };
    }

    return _PreviewBuildResult(
      widgets: [
        Positioned(
          left: (previewContext.originX + localX) * scaleX,
          top: (previewContext.originY + localY) * scaleY,
          width: math.max(1, command.width) * scaleX,
          height: math.max(1, command.height) * scaleY,
          child: ClipRect(
            child: Stack(
              children: [
                for (var i = 0; i < lines.length; i++)
                  if (i * lineAdvance < command.height)
                    Positioned(
                      left: lineLeft(lines[i]) * scaleX,
                      top: i * lineAdvance * scaleY,
                      child: Text(lines[i], style: textStyle, maxLines: 1),
                    ),
              ],
            ),
          ),
        ),
      ],
      height: command.y == null ? command.height : 0,
    );
  }
}

_PreviewBuildResult _positionedFill({
  required _PreviewLayoutContext previewContext,
  required int x,
  required int y,
  required int width,
  required int height,
  required double scaleX,
  required double scaleY,
  required Color color,
  required int consumedHeight,
}) {
  return _PreviewBuildResult(
    widgets: [
      Positioned(
        left: (previewContext.originX + x) * scaleX,
        top: (previewContext.originY + y) * scaleY,
        child: Container(
          width: math.max(1, width) * scaleX,
          height: math.max(1, height) * scaleY,
          color: color,
        ),
      ),
    ],
    height: consumedHeight,
  );
}

class _PreviewLayoutContext {
  const _PreviewLayoutContext({
    required this.originX,
    required this.originY,
    required this.width,
    required this.height,
    this.cursorY = 0,
  });

  final int originX;
  final int originY;
  final int width;
  final int height;
  final int cursorY;

  _PreviewLayoutContext copyWith({
    int? originX,
    int? originY,
    int? width,
    int? height,
    int? cursorY,
  }) {
    return _PreviewLayoutContext(
      originX: originX ?? this.originX,
      originY: originY ?? this.originY,
      width: width ?? this.width,
      height: height ?? this.height,
      cursorY: cursorY ?? this.cursorY,
    );
  }

  _PreviewLayoutContext nested({
    int x = 0,
    int y = 0,
    required int width,
    int? height,
    int cursorY = 0,
  }) {
    return _PreviewLayoutContext(
      originX: originX + x,
      originY: originY + y,
      width: width,
      height: height ?? this.height,
      cursorY: cursorY,
    );
  }
}

class _PreviewBuildResult {
  const _PreviewBuildResult({this.widgets = const <Widget>[], this.height = 0});

  final List<Widget> widgets;
  final int height;
}

class _PreviewMetrics {
  const _PreviewMetrics({required this.width, required this.height});

  final double width;
  final double height;
}

_PreviewMetrics _resolvePreviewMetrics({
  required double availableWidth,
  required double printWidth,
  required double labelLength,
}) {
  final safeWidth = availableWidth.isFinite && availableWidth > 0
      ? availableWidth
      : printWidth;
  final safeAspectRatio = labelLength > 0 && printWidth > 0
      ? printWidth / labelLength
      : 1.0;
  final minHeight = math.min(math.max(180.0, safeWidth * 0.45), 260.0);
  final targetHeight = (safeWidth / safeAspectRatio).clamp(minHeight, 520.0);

  return _PreviewMetrics(
    width: targetHeight * safeAspectRatio,
    height: targetHeight,
  );
}

int _previewLeft({
  required int? x,
  required int availableWidth,
  required int itemWidth,
  required TscAlignment? alignment,
}) {
  if (x == null) {
    return _resolveAlignedX(availableWidth, itemWidth, alignment);
  }

  return switch (alignment) {
    null || TscAlignment.left => x,
    TscAlignment.center => x - itemWidth ~/ 2,
    TscAlignment.right => x - itemWidth,
  };
}

int _resolveAlignedX(int width, int itemWidth, TscAlignment? alignment) {
  return switch (alignment ?? TscAlignment.left) {
    TscAlignment.left => 0,
    TscAlignment.center => math.max(0, (width - itemWidth) ~/ 2),
    TscAlignment.right => math.max(0, width - itemWidth),
  };
}

List<String> _wrapText(
  String text, {
  required int maxWidth,
  required TextStyle style,
  required double scaleY,
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
    final words = paragraph.split(RegExp(r'\s+'));
    var current = '';

    for (final word in words) {
      if (current.isEmpty) {
        if (_measurePreviewTextWidth(word, style, scaleY: scaleY) <= maxWidth) {
          current = word;
        } else {
          final pieces = _breakLongWord(
            word,
            maxWidth: maxWidth,
            style: style,
            scaleY: scaleY,
          );
          lines.addAll(pieces.take(math.max(0, pieces.length - 1)));
          current = pieces.isEmpty ? '' : pieces.last;
        }
        continue;
      }

      final candidate = '$current $word';
      if (_measurePreviewTextWidth(candidate, style, scaleY: scaleY) <=
          maxWidth) {
        current = candidate;
        continue;
      }

      lines.add(current);
      if (_measurePreviewTextWidth(word, style, scaleY: scaleY) <= maxWidth) {
        current = word;
      } else {
        final pieces = _breakLongWord(
          word,
          maxWidth: maxWidth,
          style: style,
          scaleY: scaleY,
        );
        lines.addAll(pieces.take(math.max(0, pieces.length - 1)));
        current = pieces.isEmpty ? '' : pieces.last;
      }
    }

    if (current.isNotEmpty) {
      lines.add(current);
    }
  }

  return lines.isEmpty ? const [''] : lines;
}

List<String> _breakLongWord(
  String word, {
  required int maxWidth,
  required TextStyle style,
  required double scaleY,
}) {
  final pieces = <String>[];
  var current = '';

  for (final rune in word.runes) {
    final char = String.fromCharCode(rune);
    final candidate = '$current$char';
    if (current.isNotEmpty &&
        _measurePreviewTextWidth(candidate, style, scaleY: scaleY) > maxWidth) {
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

int _measurePreviewTextWidth(
  String text,
  TextStyle style, {
  required double scaleY,
}) {
  if (text.isEmpty) {
    return 1;
  }

  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  return math.max(1, (painter.width / scaleY).ceil());
}

class _BarcodePainter extends CustomPainter {
  _BarcodePainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    var x = 0.0;
    var value = seed.abs() + 1;

    while (x < size.width) {
      final width = (value % 4 + 1).toDouble();
      canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
      x += width + ((value >> 2) % 3 + 1);
      value = (value * 1103515245 + 12345) & 0x7fffffff;
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final cell = size.shortestSide / 21;

    void finder(double x, double y) {
      canvas.drawRect(Rect.fromLTWH(x, y, cell * 7, cell * 7), paint);
      canvas.drawRect(
        Rect.fromLTWH(x + cell, y + cell, cell * 5, cell * 5),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + cell * 2, y + cell * 2, cell * 3, cell * 3),
        paint,
      );
    }

    finder(0, 0);
    finder(size.width - cell * 7, 0);
    finder(0, size.height - cell * 7);

    var value = seed.abs() + 7;
    for (var row = 0; row < 21; row++) {
      for (var col = 0; col < 21; col++) {
        final inFinder =
            (row < 7 && col < 7) ||
            (row < 7 && col >= 14) ||
            (row >= 14 && col < 7);
        if (inFinder) {
          continue;
        }
        value = (value * 1664525 + 1013904223) & 0x7fffffff;
        if (value.isEven) {
          canvas.drawRect(
            Rect.fromLTWH(col * cell, row * cell, cell, cell),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}

class _ReversePainter extends CustomPainter {
  const _ReversePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.difference
        ..color = const Color(0xFFFFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Pdf417Painter extends CustomPainter {
  const _Pdf417Painter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    const rows = 8;
    final rowHeight = size.height / rows;
    var value = seed.abs() + 3;

    for (var row = 0; row < rows; row++) {
      var x = 0.0;
      while (x < size.width) {
        final barWidth = (value % 3 + 1).toDouble();
        canvas.drawRect(
          Rect.fromLTWH(x, row * rowHeight, barWidth, rowHeight * 0.72),
          paint,
        );
        x += barWidth + ((value >> 2) % 2 + 1);
        value = (value * 1103515245 + 12345) & 0x7fffffff;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Pdf417Painter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}

class _MatrixPainter extends CustomPainter {
  const _MatrixPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    const modules = 16;
    final cell = size.shortestSide / modules;
    var value = seed.abs() + 11;

    for (var row = 0; row < modules; row++) {
      for (var col = 0; col < modules; col++) {
        value = (value * 1664525 + 1013904223) & 0x7fffffff;
        final border =
            col == 0 ||
            row == modules - 1 ||
            (row == 0 && col.isEven) ||
            (col == modules - 1 && row.isEven);
        if (border || value.isEven) {
          canvas.drawRect(
            Rect.fromLTWH(col * cell, row * cell, cell, cell),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixPainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x11000000)
      ..strokeWidth = 1;

    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _trimCommandPreview(String preview) {
  return preview
      .split('\r\n')
      .where((line) => line.isNotEmpty)
      .map((line) {
        if (line.startsWith('BITMAP ')) {
          final firstComma = line.indexOf(',');
          return firstComma == -1
              ? 'BITMAP <binary bitmap bytes>'
              : '${line.substring(0, firstComma + 1)}<binary bitmap bytes>';
        }
        return line;
      })
      .join('\n');
}
