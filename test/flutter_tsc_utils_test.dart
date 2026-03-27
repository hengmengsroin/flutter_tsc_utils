import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_tsc_utils/flutter_tsc_utils.dart';

void main() {
  test('builds common TSC commands with chainable API', () {
    final generator = TscGenerator()
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

  test('supports richer label and setup commands', () {
    final generator = TscGenerator()
      ..setPeel(TscToggle.on)
      ..setTear(TscToggle.off)
      ..setCutter(batch: true)
      ..setPartialCutter(every: 2)
      ..block(
        10,
        20,
        200,
        80,
        'Wrapped content',
        style: const TscTextStyle(
          font: TscFont.font4,
          xMultiplier: 2,
          yMultiplier: 3,
        ),
        space: 4,
        alignment: TscBlockAlignment.center,
        fit: true,
      )
      ..reverse(5, 6, 30, 40)
      ..erase(7, 8, 10, 20)
      ..pdf417(
        50,
        60,
        300,
        160,
        'PDF payload',
        options: const TscPdf417Options(
          errorCorrectionLevel: 4,
          moduleWidth: 4,
          barHeight: 12,
          maxRows: 20,
          maxColumns: 8,
          centerPattern: true,
          truncated: true,
        ),
      )
      ..dataMatrix(
        70,
        90,
        120,
        120,
        'DM payload',
        options: const TscDataMatrixOptions(
          controlCharacter: 126,
          moduleSize: 6,
          rotation: TscRotation.angle90,
          shape: TscDataMatrixShape.rectangular,
          rows: 16,
          columns: 48,
        ),
      )
      ..putBmp(100, 120, 'logo.bmp');

    expect(
      generator.preview(),
      'SET PEEL ON\r\n'
      'SET TEAR OFF\r\n'
      'SET CUTTER BATCH\r\n'
      'SET PARTIAL_CUTTER 2\r\n'
      'BLOCK 10,20,200,80,"4",0,2,3,4,CENTER,1,"Wrapped content"\r\n'
      'REVERSE 5,6,30,40\r\n'
      'ERASE 7,8,10,20\r\n'
      'PDF417 50,60,300,160,0,P0,E4,M1,W4,H12,R20,C8,T1,"PDF payload"\r\n'
      'DMATRIX 70,90,120,120,C126,X6,R90,A1,16,48,"DM payload"\r\n'
      'PUTBMP 100,120,"logo.bmp"\r\n',
    );
  });

  test('supports alignment in text and barcode commands', () {
    final generator = TscGenerator()
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

  test('bitmap rasterization emits expected bytes', () {
    final image = img.Image(width: 8, height: 1);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    image.setPixelRgb(0, 0, 0, 0, 0);
    image.setPixelRgb(1, 0, 0, 0, 0);

    final generator = TscGenerator()..bitmap(10, 20, image);
    final bytes = generator.build();

    expect(
      latin1.decode(bytes.sublist(0, 'BITMAP 10,20,1,1,0,'.length)),
      'BITMAP 10,20,1,1,0,',
    );
    expect(bytes['BITMAP 10,20,1,1,0,'.length], 0xC0);
    expect(latin1.decode(bytes.sublist(bytes.length - 2)), '\r\n');
  });

  test('rejects invalid numeric ranges', () {
    expect(() => TscGenerator().density(16), throwsA(isA<RangeError>()));
    expect(
      () => TscGenerator().pdf417(
        0,
        0,
        100,
        100,
        'bad',
        options: const TscPdf417Options(errorCorrectionLevel: 9),
      ),
      throwsA(isA<RangeError>()),
    );
    expect(
      () => TscGenerator().setCutter(batch: true, every: 2),
      throwsA(isA<ArgumentError>()),
    );
  });
}
