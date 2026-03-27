import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_tsc_utils/flutter_tsc_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('layout sections support rows, padding, and anchors', () {
    final layout = TscLabelLayout(
      width: 600,
      height: 400,
      padding: const TscPadding.all(20),
    );

    final rows = layout.rows([50, 80], spacing: 10);
    final anchored = layout.anchor(100, 40, anchor: TscAnchor.bottomRight);

    expect(rows[0].x, 20);
    expect(rows[0].y, 20);
    expect(rows[0].width, 560);
    expect(rows[1].y, 80);
    expect(anchored.x, 480);
    expect(anchored.y, 340);
  });

  test('image helper contain fit centers resized image in target box', () {
    final source = img.Image(width: 100, height: 50);
    img.fill(source, color: img.ColorRgb8(0, 0, 0));

    final fitted = TscImageHelper.fitInto(
      source,
      boxWidth: 200,
      boxHeight: 200,
      fit: TscImageFit.contain,
    );

    expect(fitted.image.width, 200);
    expect(fitted.image.height, 200);
    expect(fitted.image.getPixel(100, 100).r, 0);
    expect(fitted.image.getPixel(100, 20).r, 255);
  });

  test('bitmapFitted generates TSPL bitmap for a target rect', () {
    final source = img.Image(width: 20, height: 10);
    img.fill(source, color: img.ColorRgb8(0, 0, 0));

    final generator = TscGenerator()
      ..bitmapFitted(const TscRect(30, 40, 60, 60), source);

    expect(
      _asciiPrefix(generator.build(), maxLength: 64),
      'BITMAP 30,40,8,60,0,',
    );
  });

  test('khmerText renders text through bitmap output', () async {
    final generator = TscGenerator();

    await generator.khmerText(
      12,
      18,
      'សួស្តី',
      options: const TscRenderedTextOptions(
        style: TextStyle(fontSize: 20, color: Color(0xFF000000)),
        pixelRatio: 1,
      ),
    );

    final bytes = generator.build();
    final prefix = _asciiPrefix(bytes, maxLength: 64);

    expect(prefix, startsWith('BITMAP 12,18,'));
    expect(bytes.length, greaterThan(prefix.length + 2));
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
    expect(
      () => TscGenerator().downloadProgramStart('demo.txt'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('supports file management and immediate query commands', () {
    const expectedPreview =
        'FORMFEED\r\n'
        'SELFTEST PATTERN\r\n'
        'FILES\r\n'
        'DOWNLOAD F,"AUTO.BAS"\r\n'
        'EOP\r\n'
        'DOWNLOAD "LOGO.TXT",3,ABC\r\n'
        'KILL F,"OLD.BAS"\r\n'
        'MOVE "TMP.BAS",F,"AUTO.BAS"\r\n'
        'RUN "AUTO.BAS"\r\n';

    final generator = TscGenerator()
      ..formFeed()
      ..selfTest(page: TscSelfTestPage.pattern)
      ..files()
      ..downloadProgramStart('AUTO.BAS', memory: TscMemory.flash)
      ..eop()
      ..downloadDataString('LOGO.TXT', 'ABC', memory: TscMemory.dram)
      ..kill('OLD.BAS', memory: TscMemory.flash)
      ..move(
        'TMP.BAS',
        'AUTO.BAS',
        fromMemory: TscMemory.dram,
        toMemory: TscMemory.flash,
      )
      ..run('AUTO.BAS')
      ..statusPoll()
      ..statusPollPrinter()
      ..queryFileList()
      ..queryPrinterModel()
      ..queryCodePageAndCountry();

    final bytes = generator.build();
    final preview = latin1.decode(bytes.sublist(0, expectedPreview.length));

    expect(preview, expectedPreview);
    expect(bytes.sublist(expectedPreview.length), <int>[
      0x1B,
      0x21,
      0x3F,
      0x1B,
      0x21,
      0x53,
      0x7E,
      0x21,
      0x46,
      0x7E,
      0x21,
      0x54,
      0x7E,
      0x21,
      0x49,
    ]);
  });
}

String _asciiPrefix(List<int> bytes, {required int maxLength}) {
  final values = <int>[];

  for (final byte in bytes.take(maxLength)) {
    if (byte == 10 || byte == 13) {
      break;
    }
    if (byte < 32 || byte > 126) {
      break;
    }
    values.add(byte);
  }

  return latin1.decode(values);
}
