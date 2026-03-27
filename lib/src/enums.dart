enum TscUnit {
  inch(''),
  mm(' mm'),
  dot(' dot');

  const TscUnit(this.suffix);

  final String suffix;
}

enum TscDirection {
  forward(0),
  backward(1);

  const TscDirection(this.value);

  final int value;
}

enum TscMirror {
  normal(0),
  mirrored(1);

  const TscMirror(this.value);

  final int value;
}

enum TscRotation {
  angle0(0),
  angle90(90),
  angle180(180),
  angle270(270);

  const TscRotation(this.value);

  final int value;
}

enum TscTextAlignment {
  left(0),
  center(1),
  right(2);

  const TscTextAlignment(this.value);

  final int value;
}

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

  final String value;
}

enum TscReadable {
  hidden(0),
  above(1),
  below(2),
  both(3);

  const TscReadable(this.value);

  final int value;
}

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

  final String value;
}

enum TscBitmapMode {
  overwrite(0),
  or(1),
  xor(2);

  const TscBitmapMode(this.value);

  final int value;
}

enum TscQrErrorCorrection {
  low('L'),
  medium('M'),
  quartile('Q'),
  high('H');

  const TscQrErrorCorrection(this.value);

  final String value;
}

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

  final int value;
}
