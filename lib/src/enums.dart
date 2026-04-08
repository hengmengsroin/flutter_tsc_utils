/// Measurement unit used by TSPL size and spacing commands.
enum TscUnit {
  inch(''),
  mm(' mm'),
  dot(' dot');

  const TscUnit(this.suffix);

  /// Suffix token appended to numeric values in TSPL commands.
  final String suffix;
}

/// Target memory area for file/program operations.
enum TscMemory {
  dram(''),
  flash('F'),
  expansion('E');

  const TscMemory(this.value);

  /// Command token expected by the printer for this memory type.
  final String value;
}

/// Two-state on/off value used by `SET` commands.
enum TscToggle {
  on('ON'),
  off('OFF');

  const TscToggle(this.value);

  /// Command token expected by the printer for this toggle.
  final String value;
}

/// Print direction for label output.
enum TscDirection {
  forward(0),
  backward(1);

  const TscDirection(this.value);

  /// Integer value encoded in TSPL command arguments.
  final int value;
}

/// Mirroring mode used by the `DIRECTION` command.
enum TscMirror {
  normal(0),
  mirrored(1);

  const TscMirror(this.value);

  /// Integer value encoded in TSPL command arguments.
  final int value;
}

/// Rotation angle used by text, barcode, and other draw commands.
enum TscRotation {
  angle0(0),
  angle90(90),
  angle180(180),
  angle270(270);

  const TscRotation(this.value);

  /// Rotation angle in degrees.
  final int value;
}

/// Horizontal alignment used by text and barcode commands.
enum TscTextAlignment {
  left(0),
  center(1),
  right(2);

  const TscTextAlignment(this.value);

  /// Integer value encoded in TSPL command arguments.
  final int value;
}

/// Alignment mode used by multiline block text.
enum TscBlockAlignment {
  left('LEFT'),
  center('CENTER'),
  right('RIGHT'),
  justified('JUSTIFIED');

  const TscBlockAlignment(this.value);

  /// Command token expected by the printer for this alignment.
  final String value;
}

/// Built-in and external fonts accepted by TSC printers.
enum TscFont {
  font1('1'),
  font2('2'),
  font3('3'),
  font4('4'),
  font5('5'),
  font6('6'),
  font7('7'),
  font8('8'),
  roman('ROMAN.TTF'),
  simplifiedChinese('SIMPLIFIED CHINESE'),
  traditionalChinese('TRADITIONAL CHINESE');

  const TscFont(this.value);

  /// Command token used as the font identifier.
  final String value;
}

/// Human-readable text placement for barcode labels.
enum TscReadable {
  hidden(0),
  above(1),
  below(2),
  both(3);

  const TscReadable(this.value);

  /// Integer value encoded in TSPL command arguments.
  final int value;
}

/// Supported 1D barcode symbologies.
enum TscBarcodeType {
  code128('128'),
  code128M('128M'),
  ean128('EAN128'),
  interleaved2of5('25'),
  interleaved2of5WithChecksum('25C'),
  code39('39'),
  code39WithChecksum('39C'),
  code93('93'),
  ean13('EAN13'),
  ean13WithAddon2('EAN13+2'),
  ean13WithAddon5('EAN13+5'),
  ean8('EAN8'),
  ean8WithAddon2('EAN8+2'),
  ean8WithAddon5('EAN8+5'),
  codabar('CODA'),
  postnet('POST'),
  upcA('UPCA'),
  upcAWithAddon2('UPCA+2'),
  upcAWithAddon5('UPCA+5'),
  upcE('UPCE13'),
  upcEWithAddon2('UPCE13+2'),
  upcEWithAddon5('UPCE13+5'),
  cpost('CPOST'),
  msi('MSI'),
  msi1010('MSI10'),
  msi1110('MSI11'),
  pleSsey('PLESSEY'),
  itf14('ITF14'),
  ean14('EAN14');

  const TscBarcodeType(this.value);

  /// Command token expected by the printer for this barcode type.
  final String value;
}

/// Print darkness level from light (`d0`) to dark (`d15`).
enum TscPrintDensity {
  d0(0),
  d1(1),
  d2(2),
  d3(3),
  d4(4),
  d5(5),
  d6(6),
  d7(7),
  d8(8),
  d9(9),
  d10(10),
  d11(11),
  d12(12),
  d13(13),
  d14(14),
  d15(15);

  const TscPrintDensity(this.value);

  /// Integer value encoded in TSPL command arguments.
  final int value;
}

/// Blend mode used by `BITMAP` drawing.
enum TscBitmapMode {
  overwrite(0),
  or(1),
  xor(2);

  const TscBitmapMode(this.value);

  /// Integer value encoded in TSPL command arguments.
  final int value;
}

/// Rewind mode used by the `SET REWIND` command.
enum TscRewindMode {
  on('ON'),
  off('OFF'),
  rs232('RS232');

  const TscRewindMode(this.value);

  /// Command token expected by the printer for this mode.
  final String value;
}

/// QR code error correction level.
enum TscQrErrorCorrection {
  low('L'),
  medium('M'),
  quartile('Q'),
  high('H');

  const TscQrErrorCorrection(this.value);

  /// Command token expected by the printer for this level.
  final String value;
}

/// QR code cell size.
enum TscQrCellWidth {
  size1(1),
  size2(2),
  size3(3),
  size4(4),
  size5(5),
  size6(6),
  size7(7),
  size8(8),
  size9(9),
  size10(10);

  const TscQrCellWidth(this.value);

  /// Integer value encoded in TSPL command arguments.
  final int value;
}

/// PDF417 payload compression mode.
enum TscPdf417CompressionMode {
  auto(0),
  binary(1);

  const TscPdf417CompressionMode(this.value);

  /// Integer value encoded in TSPL command arguments.
  final int value;
}

/// Shape preference for Data Matrix symbols.
enum TscDataMatrixShape {
  square(0),
  rectangular(1);

  const TscDataMatrixShape(this.value);

  /// Integer value encoded in TSPL command arguments.
  final int value;
}

/// Image fitting strategy when drawing into a fixed box.
enum TscImageFit { contain, cover, fill, none, scaleDown }

/// Anchor point used for alignment inside a container.
enum TscAnchor {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// Built-in self-test page variants.
enum TscSelfTestPage {
  full(''),
  pattern('PATTERN'),
  ethernet('ETHERNET'),
  wlan('WLAN'),
  rs232('RS232'),
  system('SYSTEM'),
  emulation('Z'),
  bluetooth('BT');

  const TscSelfTestPage(this.value);

  /// Command token expected by the printer for this page.
  final String value;
}

enum TscImmediateStatusCode {
  normal(0x00),
  headOpen(0x01),
  paperJam(0x02),
  paperJamHeadOpen(0x03),
  outOfPaper(0x04),
  outOfPaperHeadOpen(0x05),
  outOfRibbon(0x08),
  outOfRibbonHeadOpen(0x09),
  outOfRibbonPaperJam(0x0A),
  outOfRibbonPaperJamHeadOpen(0x0B),
  outOfRibbonOutOfPaper(0x0C),
  outOfRibbonOutOfPaperHeadOpen(0x0D),
  pause(0x10),
  printing(0x20),
  otherError(0x80);

  const TscImmediateStatusCode(this.value);

  final int value;

  static TscImmediateStatusCode? fromByte(int value) {
    for (final code in values) {
      if (code.value == value) {
        return code;
      }
    }
    return null;
  }
}
