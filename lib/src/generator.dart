import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart';

import 'enums.dart';
import 'label_size.dart';
import 'text_style.dart';

typedef Generator = TscGenerator;

class TscGenerator {
  TscGenerator({this.newLine = '\r\n', this.codec = latin1});

  final String newLine;
  final Encoding codec;
  final BytesBuilder _buffer = BytesBuilder();

  void reset() {
    _buffer.clear();
  }

  Uint8List build() => _buffer.toBytes();

  List<int> bytes() => build();

  void rawBytes(List<int> bytes) {
    _buffer.add(bytes);
  }

  void rawCommand(String command) {
    _appendCommand(command);
  }

  void size(TscLabelSize size) {
    _appendCommand(
      'SIZE ${_withUnit(size.width, size.unit)},${_withUnit(size.height, size.unit)}',
    );
  }

  void gap(num gap, num offset, {TscUnit unit = TscUnit.mm}) {
    _appendCommand('GAP ${_withUnit(gap, unit)},${_withUnit(offset, unit)}');
  }

  void bline(num height, num offset, {TscUnit unit = TscUnit.mm}) {
    _appendCommand(
      'BLINE ${_withUnit(height, unit)},${_withUnit(offset, unit)}',
    );
  }

  void offset(num value, {TscUnit unit = TscUnit.mm}) {
    _appendCommand('OFFSET ${_withUnit(value, unit)}');
  }

  void speed(num inchesPerSecond) {
    _appendCommand('SPEED ${_formatNumber(inchesPerSecond)}');
  }

  void density(int value) {
    _appendCommand('DENSITY $value');
  }

  void direction(
    TscDirection direction, {
    TscMirror mirror = TscMirror.normal,
  }) {
    _appendCommand('DIRECTION ${direction.value},${mirror.value}');
  }

  void reference(int x, int y) {
    _appendCommand('REFERENCE $x,$y');
  }

  void shift(int x) {
    _appendCommand('SHIFT $x');
  }

  void codePage(String value) {
    _appendCommand('CODEPAGE $value');
  }

  void cls() {
    _appendCommand('CLS');
  }

  void feed(int dots) {
    _appendCommand('FEED $dots');
  }

  void backFeed(int dots) {
    _appendCommand('BACKFEED $dots');
  }

  void home() {
    _appendCommand('HOME');
  }

  void sound(int level, int interval) {
    _appendCommand('SOUND $level,$interval');
  }

  void cut() {
    _appendCommand('CUT');
  }

  void text(
    int x,
    int y,
    String value, {
    TscTextStyle style = const TscTextStyle(),
  }) {
    final alignment = style.alignment == null
        ? ''
        : ',${style.alignment!.value}';
    _appendCommand(
      'TEXT $x,$y,"${style.font.value}",${style.rotation.value},${style.xMultiplier},${style.yMultiplier}$alignment,"${_escapeText(value)}"',
    );
  }

  void bar(int x, int y, int width, int height) {
    _appendCommand('BAR $x,$y,$width,$height');
  }

  void box(int x, int y, int xEnd, int yEnd, {int thickness = 1}) {
    _appendCommand('BOX $x,$y,$xEnd,$yEnd,$thickness');
  }

  void barcode(
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
    final alignArg = alignment == null ? '' : ',${alignment.value}';
    _appendCommand(
      'BARCODE $x,$y,"${type.value}",$height,${readable.value},${rotation.value},$narrow,$wide$alignArg,"${_escapeText(content)}"',
    );
  }

  void qrCode(
    int x,
    int y,
    String content, {
    TscQrErrorCorrection ecc = TscQrErrorCorrection.low,
    TscQrCellWidth cellWidth = TscQrCellWidth.size4,
    TscRotation rotation = TscRotation.angle0,
  }) {
    _appendCommand(
      'QRCODE $x,$y,${ecc.value},${cellWidth.value},A,${rotation.value},"${_escapeText(content)}"',
    );
  }

  void bitmap(
    int x,
    int y,
    Image image, {
    TscBitmapMode mode = TscBitmapMode.overwrite,
    int threshold = 127,
  }) {
    final raster = _rasterize(image, threshold: threshold);
    _buffer.add(
      codec.encode(
        'BITMAP $x,$y,${raster.widthBytes},${raster.height},${mode.value},',
      ),
    );
    _buffer.add(raster.bytes);
    _buffer.add(codec.encode(newLine));
  }

  void print({int copies = 1, int sets = 1}) {
    _appendCommand('PRINT $sets,$copies');
  }

  String preview() => String.fromCharCodes(build());

  void _appendCommand(String command) {
    _buffer.add(codec.encode(command));
    _buffer.add(codec.encode(newLine));
  }

  String _withUnit(num value, TscUnit unit) {
    return '${_formatNumber(value)}${unit.suffix}';
  }

  String _formatNumber(num value) {
    if (value is int) {
      return value.toString();
    }

    final normalized = value.toStringAsFixed(3);
    return normalized.contains('.')
        ? normalized.replaceFirst(RegExp(r'\.?0+$'), '')
        : normalized;
  }

  String _escapeText(String value) {
    return value.replaceAll('"', r'\"');
  }

  _RasterizedBitmap _rasterize(Image source, {required int threshold}) {
    final grayscaleImage = grayscale(Image.from(source));
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
