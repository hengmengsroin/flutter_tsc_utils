import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_tsc_utils/flutter_tsc_utils.dart';

void main() {
  test('builds common TSC commands', () {
    final generator = TscGenerator();

    generator
      ..size(const TscLabelSize(60, 40))
      ..gap(2, 0)
      ..density(8)
      ..direction(TscDirection.forward)
      ..cls()
      ..text(20, 30, 'Hello')
      ..barcode(20, 80, '1234567890')
      ..qrCode(20, 180, 'https://example.com')
      ..print();

    expect(
      generator.preview(),
      'SIZE 60 mm,40 mm\r\n'
      'GAP 2 mm,0 mm\r\n'
      'DENSITY 8\r\n'
      'DIRECTION 0,0\r\n'
      'CLS\r\n'
      'TEXT 20,30,"3",0,1,1,"Hello"\r\n'
      'BARCODE 20,80,"128",100,2,0,2,2,"1234567890"\r\n'
      'QRCODE 20,180,L,4,A,0,"https://example.com"\r\n'
      'PRINT 1,1\r\n',
    );
  });

  test('supports alignment in text and barcode commands', () {
    final generator = TscGenerator();

    generator
      ..text(
        10,
        12,
        'Aligned',
        style: const TscTextStyle(alignment: TscTextAlignment.center),
      )
      ..barcode(50, 60, '42', alignment: TscTextAlignment.right);

    expect(
      generator.preview(),
      'TEXT 10,12,"3",0,1,1,1,"Aligned"\r\n'
      'BARCODE 50,60,"128",100,2,0,2,2,2,"42"\r\n',
    );
  });
}
