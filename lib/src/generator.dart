import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

import 'commands.dart';
import 'enums.dart';
import 'label_size.dart';
import 'options.dart';
import 'rendered_text_options.dart';
import 'text_style.dart';

typedef Generator = TscGenerator;

class TscGenerator {
  TscGenerator({this.newLine = '\r\n', this.codec = latin1})
    : _commands = TscCommandBuffer(codec: codec, newLine: newLine);

  final String newLine;
  final Encoding codec;
  final TscCommandBuffer _commands;

  TscGenerator reset() {
    _commands.clear();
    return this;
  }

  Uint8List build() => _commands.build();

  List<int> bytes() => build();

  String preview() => String.fromCharCodes(build());

  TscGenerator rawBytes(List<int> bytes) {
    _commands.addRawBytes(bytes);
    return this;
  }

  TscGenerator rawCommand(String command) {
    _commands.addCommand(command);
    return this;
  }

  TscGenerator size(TscLabelSize size) {
    requirePositive(size.width, 'size.width');
    requirePositive(size.height, 'size.height');
    return rawCommand(
      'SIZE ${_withUnit(size.width, size.unit)},${_withUnit(size.height, size.unit)}',
    );
  }

  TscGenerator gap(num gap, num offset, {TscUnit unit = TscUnit.mm}) {
    requireNonNegative(gap, 'gap');
    requireNonNegative(offset, 'offset');
    return rawCommand('GAP ${_withUnit(gap, unit)},${_withUnit(offset, unit)}');
  }

  TscGenerator bline(num height, num offset, {TscUnit unit = TscUnit.mm}) {
    requireNonNegative(height, 'height');
    requireNonNegative(offset, 'offset');
    return rawCommand(
      'BLINE ${_withUnit(height, unit)},${_withUnit(offset, unit)}',
    );
  }

  TscGenerator offset(num value, {TscUnit unit = TscUnit.mm}) {
    requireNonNegative(value, 'value');
    return rawCommand('OFFSET ${_withUnit(value, unit)}');
  }

  TscGenerator speed(num inchesPerSecond) {
    requirePositive(inchesPerSecond, 'inchesPerSecond');
    return rawCommand('SPEED ${formatTscNumber(inchesPerSecond)}');
  }

  TscGenerator density(int value) {
    requireRange(value, 0, 15, 'density');
    return rawCommand('DENSITY $value');
  }

  TscGenerator direction(
    TscDirection direction, {
    TscMirror mirror = TscMirror.normal,
  }) {
    return rawCommand('DIRECTION ${direction.value},${mirror.value}');
  }

  TscGenerator reference(int x, int y) => rawCommand('REFERENCE $x,$y');

  TscGenerator shift(int x) => rawCommand('SHIFT $x');

  TscGenerator codePage(String value) => rawCommand('CODEPAGE $value');

  TscGenerator cls() => rawCommand('CLS');

  TscGenerator feed(int dots) {
    requireNonNegative(dots, 'dots');
    return rawCommand('FEED $dots');
  }

  TscGenerator backFeed(int dots) {
    requireNonNegative(dots, 'dots');
    return rawCommand('BACKFEED $dots');
  }

  TscGenerator home() => rawCommand('HOME');

  TscGenerator sound(int level, int interval) {
    requireRange(level, 0, 9, 'level');
    requireRange(interval, 1, 4095, 'interval');
    return rawCommand('SOUND $level,$interval');
  }

  TscGenerator cut() => rawCommand('CUT');

  TscGenerator setPeel(TscToggle value) =>
      rawCommand('SET PEEL ${value.value}');

  TscGenerator setTear(TscToggle value) =>
      rawCommand('SET TEAR ${value.value}');

  TscGenerator setBack(TscToggle value) =>
      rawCommand('SET BACK ${value.value}');

  TscGenerator setRibbon(TscToggle value) =>
      rawCommand('SET RIBBON ${value.value}');

  TscGenerator setRewind(TscRewindMode value) =>
      rawCommand('SET REWIND ${value.value}');

  TscGenerator setCutter({int? every, bool batch = false}) {
    return _setCutCommand(command: 'SET CUTTER', every: every, batch: batch);
  }

  TscGenerator setPartialCutter({int? every, bool batch = false}) {
    return _setCutCommand(
      command: 'SET PARTIAL_CUTTER',
      every: every,
      batch: batch,
    );
  }

  TscGenerator text(
    int x,
    int y,
    String value, {
    TscTextStyle style = const TscTextStyle(),
  }) {
    _validateTextStyle(style);
    final arguments = <String>[
      '$x',
      '$y',
      quoteTsc(style.font.value),
      '${style.rotation.value}',
      '${style.xMultiplier}',
      '${style.yMultiplier}',
      if (style.alignment != null) '${style.alignment!.value}',
      quoteTsc(value),
    ];
    return rawCommand('TEXT ${arguments.join(',')}');
  }

  TscGenerator block(
    int x,
    int y,
    int width,
    int height,
    String value, {
    TscTextStyle style = const TscTextStyle(),
    int? space,
    TscBlockAlignment alignment = TscBlockAlignment.left,
    bool fit = false,
  }) {
    requirePositive(width, 'width');
    requirePositive(height, 'height');
    _validateTextStyle(style);
    if (space != null) {
      requireNonNegative(space, 'space');
    }

    final arguments = <String>[
      '$x',
      '$y',
      '$width',
      '$height',
      quoteTsc(style.font.value),
      '${style.rotation.value}',
      '${style.xMultiplier}',
      '${style.yMultiplier}',
    ];

    if (space != null || alignment != TscBlockAlignment.left || fit) {
      arguments.add('${space ?? 0}');
      arguments.add(alignment.value);
      arguments.add(fit ? '1' : '0');
    }

    arguments.add(quoteTsc(value));
    return rawCommand('BLOCK ${arguments.join(',')}');
  }

  TscGenerator bar(int x, int y, int width, int height) {
    requirePositive(width, 'width');
    requirePositive(height, 'height');
    return rawCommand('BAR $x,$y,$width,$height');
  }

  TscGenerator box(int x, int y, int xEnd, int yEnd, {int thickness = 1}) {
    requirePositive(thickness, 'thickness');
    return rawCommand('BOX $x,$y,$xEnd,$yEnd,$thickness');
  }

  TscGenerator erase(int x, int y, int width, int height) {
    requirePositive(width, 'width');
    requirePositive(height, 'height');
    return rawCommand('ERASE $x,$y,$width,$height');
  }

  TscGenerator reverse(int x, int y, int width, int height) {
    requirePositive(width, 'width');
    requirePositive(height, 'height');
    return rawCommand('REVERSE $x,$y,$width,$height');
  }

  TscGenerator barcode(
    int x,
    int y,
    String content, {
    TscBarcodeType type = TscBarcodeType.code128,
    int height = 100,
    TscReadable readable = TscReadable.below,
    TscRotation rotation = TscRotation.angle0,
    int narrow = 2,
    int wide = 2,
    TscTextAlignment? alignment,
  }) {
    requirePositive(height, 'height');
    requirePositive(narrow, 'narrow');
    requirePositive(wide, 'wide');

    final arguments = <String>[
      '$x',
      '$y',
      quoteTsc(type.value),
      '$height',
      '${readable.value}',
      '${rotation.value}',
      '$narrow',
      '$wide',
      if (alignment != null) '${alignment.value}',
      quoteTsc(content),
    ];
    return rawCommand('BARCODE ${arguments.join(',')}');
  }

  TscGenerator qrCode(
    int x,
    int y,
    String content, {
    TscQrErrorCorrection ecc = TscQrErrorCorrection.low,
    TscQrCellWidth cellWidth = TscQrCellWidth.size4,
    TscRotation rotation = TscRotation.angle0,
    TscTextAlignment? justification,
  }) {
    final arguments = <String>[
      '$x',
      '$y',
      ecc.value,
      '${cellWidth.value}',
      'A',
      '${rotation.value}',
      if (justification != null) 'J${justification.value + 1}',
      quoteTsc(content),
    ];
    return rawCommand('QRCODE ${arguments.join(',')}');
  }

  TscGenerator pdf417(
    int x,
    int y,
    int width,
    int height,
    String content, {
    TscRotation rotation = TscRotation.angle0,
    TscPdf417Options options = const TscPdf417Options(),
  }) {
    requirePositive(width, 'width');
    requirePositive(height, 'height');
    if (options.errorCorrectionLevel != null) {
      requireRange(
        options.errorCorrectionLevel!,
        0,
        8,
        'options.errorCorrectionLevel',
      );
    }
    if (options.moduleWidth != null) {
      requireRange(options.moduleWidth!, 2, 9, 'options.moduleWidth');
    }
    if (options.barHeight != null) {
      requireRange(options.barHeight!, 4, 99, 'options.barHeight');
    }
    if (options.maxRows != null) {
      requirePositive(options.maxRows!, 'options.maxRows');
    }
    if (options.maxColumns != null) {
      requirePositive(options.maxColumns!, 'options.maxColumns');
    }

    final arguments = <String>[
      '$x',
      '$y',
      '$width',
      '$height',
      '${rotation.value}',
    ];

    final optionTokens = <String>[
      'P${options.compression.value}',
      if (options.errorCorrectionLevel != null)
        'E${options.errorCorrectionLevel}',
      if (options.centerPattern) 'M1',
      if (options.moduleWidth != null) 'W${options.moduleWidth}',
      if (options.barHeight != null) 'H${options.barHeight}',
      if (options.maxRows != null) 'R${options.maxRows}',
      if (options.maxColumns != null) 'C${options.maxColumns}',
      if (options.truncated) 'T1',
    ];

    arguments.addAll(optionTokens);
    arguments.add(quoteTsc(content));
    return rawCommand('PDF417 ${arguments.join(',')}');
  }

  TscGenerator dataMatrix(
    int x,
    int y,
    int width,
    int height,
    String content, {
    TscDataMatrixOptions options = const TscDataMatrixOptions(),
  }) {
    requirePositive(width, 'width');
    requirePositive(height, 'height');
    if (options.controlCharacter != null) {
      requireRange(
        options.controlCharacter!,
        0,
        255,
        'options.controlCharacter',
      );
    }
    if (options.moduleSize != null) {
      requirePositive(options.moduleSize!, 'options.moduleSize');
    }
    if (options.rows != null) {
      requirePositive(options.rows!, 'options.rows');
    }
    if (options.columns != null) {
      requirePositive(options.columns!, 'options.columns');
    }

    final arguments = <String>['$x', '$y', '$width', '$height'];

    final optionTokens = <String>[
      if (options.controlCharacter != null) 'C${options.controlCharacter}',
      if (options.moduleSize != null) 'X${options.moduleSize}',
      'R${options.rotation.value}',
      'A${options.shape.value}',
      if (options.rows != null) '${options.rows}',
      if (options.columns != null) '${options.columns}',
    ];

    arguments.addAll(optionTokens);
    arguments.add(quoteTsc(content));
    return rawCommand('DMATRIX ${arguments.join(',')}');
  }

  TscGenerator putBmp(int x, int y, String filename) {
    return rawCommand('PUTBMP $x,$y,${quoteTsc(filename)}');
  }

  TscGenerator bitmap(
    int x,
    int y,
    img.Image image, {
    TscBitmapMode mode = TscBitmapMode.overwrite,
    int threshold = 127,
  }) {
    requireRange(threshold, 0, 255, 'threshold');
    final raster = _rasterize(image, threshold: threshold);
    _commands.addEncodedText(
      'BITMAP $x,$y,${raster.widthBytes},${raster.height},${mode.value},',
    );
    _commands.addRawBytes(raster.bytes);
    _commands.addEncodedText(newLine);
    return this;
  }

  Future<TscGenerator> khmerText(
    int x,
    int y,
    String value, {
    required TscRenderedTextOptions options,
  }) async {
    final rendered = await _renderFlutterText(value, options: options);
    return bitmap(
      x,
      y,
      rendered,
      mode: options.mode,
      threshold: options.threshold,
    );
  }

  TscGenerator print({int copies = 1, int sets = 1}) {
    requirePositive(copies, 'copies');
    requirePositive(sets, 'sets');
    return rawCommand('PRINT $sets,$copies');
  }

  TscGenerator _setCutCommand({
    required String command,
    required int? every,
    required bool batch,
  }) {
    if (every != null && batch) {
      throw ArgumentError(
        'Choose either batch mode or every=<n> for $command, not both.',
      );
    }

    if (every != null) {
      requireRange(every, 0, 65535, 'every');
      return rawCommand('$command $every');
    }

    if (batch) {
      return rawCommand('$command BATCH');
    }

    return rawCommand('$command OFF');
  }

  void _validateTextStyle(TscTextStyle style) {
    requireRange(style.xMultiplier, 1, 10, 'style.xMultiplier');
    requireRange(style.yMultiplier, 1, 10, 'style.yMultiplier');
  }

  String _withUnit(num value, TscUnit unit) {
    return '${formatTscNumber(value)}${unit.suffix}';
  }

  Future<img.Image> _renderFlutterText(
    String value, {
    required TscRenderedTextOptions options,
  }) async {
    if (value.isEmpty) {
      throw ArgumentError.value(value, 'value', 'Must not be empty');
    }

    requirePositive(options.pixelRatio, 'options.pixelRatio');
    requireNonNegative(options.padding, 'options.padding');
    requireRange(options.threshold, 0, 255, 'options.threshold');

    final textPainter = TextPainter(
      text: TextSpan(text: value, style: options.style),
      textAlign: options.textAlign,
      textDirection: options.textDirection,
    );

    textPainter.layout(maxWidth: options.maxWidth ?? double.infinity);

    final contentWidth = textPainter.width.ceil();
    final contentHeight = textPainter.height.ceil();
    final padding = options.padding.ceil();
    final imageWidth = (contentWidth + padding * 2).clamp(1, 65535);
    final imageHeight = (contentHeight + padding * 2).clamp(1, 65535);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final backgroundPaint = Paint()..color = options.backgroundColor;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble()),
      backgroundPaint,
    );
    textPainter.paint(canvas, Offset(options.padding, options.padding));

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(
      (imageWidth * options.pixelRatio).ceil(),
      (imageHeight * options.pixelRatio).ceil(),
    );
    final byteData = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) {
      throw StateError('Failed to convert rendered text to bytes.');
    }

    final bytes = byteData.buffer.asUint8List();
    return img.Image.fromBytes(
      width: rendered.width,
      height: rendered.height,
      bytes: bytes.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }

  _RasterizedBitmap _rasterize(img.Image source, {required int threshold}) {
    final grayscaleImage = img.grayscale(img.Image.from(source));
    final widthBytes = (grayscaleImage.width + 7) ~/ 8;
    final paddedWidth = widthBytes * 8;
    final bytes = Uint8List(widthBytes * grayscaleImage.height);

    for (var y = 0; y < grayscaleImage.height; y++) {
      for (var x = 0; x < paddedWidth; x++) {
        final isBlack = x < grayscaleImage.width
            ? grayscaleImage.getPixel(x, y).r <= threshold
            : false;
        if (isBlack) {
          final byteIndex = y * widthBytes + (x ~/ 8);
          final bitIndex = 7 - (x % 8);
          bytes[byteIndex] |= 1 << bitIndex;
        }
      }
    }

    return _RasterizedBitmap(
      widthBytes: widthBytes,
      height: grayscaleImage.height,
      bytes: bytes,
    );
  }
}

class _RasterizedBitmap {
  const _RasterizedBitmap({
    required this.widthBytes,
    required this.height,
    required this.bytes,
  });

  final int widthBytes;
  final int height;
  final Uint8List bytes;
}
