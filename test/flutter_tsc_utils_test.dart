import 'dart:convert';

import 'package:flutter/material.dart';
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

  test('builds labels with declarative generator API', () async {
    final generator = TscLabelGenerator(
      config: const TscLabelConfiguration(
        printWidth: 406,
        labelLength: 203,
        printDensity: TscPrintDensity.d8,
      ),
      commands: const [
        TscText(x: 20, y: 20, text: 'Hello World!'),
        TscBarcode(
          x: 20,
          y: 60,
          height: 50,
          data: '12345',
          type: TscBarcodeType.code128,
          printInterpretationLine: true,
        ),
      ],
    );

    expect(
      await generator.build(),
      'SIZE 406 dot,203 dot\r\n'
      'GAP 0 dot,0 dot\r\n'
      'DENSITY 8\r\n'
      'DIRECTION 0,0\r\n'
      'REFERENCE 0,0\r\n'
      'CLS\r\n'
      'TEXT 20,20,"3",0,1,1,"Hello World!"\r\n'
      'BARCODE 20,60,"128",50,2,0,2,2,"12345"\r\n'
      'PRINT 1,1\r\n',
    );
  });

  test('declarative generator can build printer bytes', () async {
    final source = img.Image(width: 8, height: 1);
    img.fill(source, color: img.ColorRgb8(255, 255, 255));
    source.setPixelRgb(0, 0, 0, 0, 0);

    final generator = TscLabelGenerator(
      config: const TscLabelConfiguration(printWidth: 100, labelLength: 50),
      commands: [TscBitmap(x: 10, y: 12, image: source)],
    );

    expect(
      _asciiPrefix(await generator.buildBytes(), maxLength: 96),
      startsWith('SIZE 100 dot,50 dot'),
    );
  });

  test('supports rich declarative receipt layout commands', () async {
    final generator = TscLabelGenerator(
      config: const TscLabelConfiguration(
        printWidth: 576,
        labelLength: 1200,
        printDensity: TscPrintDensity.d8,
      ),
      commands: const [
        TscText(x: 0, y: 30, text: 'RECEIPT', fontHeight: 50, fontWidth: 45),
        TscText(
          x: 0,
          y: 100,
          text: 'Receipt number: 117 - 44332',
          fontHeight: 24,
          fontWidth: 22,
        ),
        TscGridRow(
          y: 200,
          children: [
            TscGridCol(
              width: 6,
              child: TscColumn(
                children: [
                  TscText(
                    text: 'Big Machinery, LLC',
                    fontHeight: 25,
                    fontWidth: 22,
                  ),
                  TscText(
                    text: '3345 Diamond St',
                    fontHeight: 18,
                    fontWidth: 16,
                  ),
                ],
              ),
            ),
            TscGridCol(
              width: 6,
              child: TscColumn(
                children: [
                  TscText(text: 'Bill To', fontHeight: 25, fontWidth: 22),
                  TscText(text: 'Doe John', fontHeight: 18, fontWidth: 16),
                ],
              ),
            ),
          ],
        ),
        TscTable(
          y: 360,
          columnWidths: [6, 2, 2, 2],
          borderThickness: 2,
          cellPadding: 6,
          headers: [
            TscTableHeader('Item', fontHeight: 22, fontWidth: 20),
            TscTableHeader(
              'Qty',
              alignment: TscAlignment.center,
              fontHeight: 22,
              fontWidth: 20,
            ),
            TscTableHeader(
              'Unit',
              alignment: TscAlignment.center,
              fontHeight: 22,
              fontWidth: 20,
            ),
            TscTableHeader(
              'Total',
              alignment: TscAlignment.center,
              fontHeight: 22,
              fontWidth: 20,
            ),
          ],
          data: [
            ['Fuel Plastic Jug (10 gal)', '01', '\$34.00', '\$34.00'],
            ['Gas Hose (5 feet)', '01', '\$15.00', '\$15.00'],
          ],
          dataFontHeight: 18,
          dataFontWidth: 16,
        ),
        TscSeparator(y: 685, thickness: 2, paddingLeft: 50, paddingRight: 50),
        TscText(
          x: 50,
          y: 710,
          text: 'Total: \$152.32',
          fontHeight: 26,
          fontWidth: 24,
        ),
        TscText(
          y: 785,
          text: 'Scan for digital receipt:',
          alignment: TscAlignment.center,
        ),
        TscQrCode(
          y: 815,
          data: 'https://receipt.example.com/117-44332',
          alignment: TscAlignment.center,
        ),
      ],
    );

    final output = await generator.build();

    expect(output, contains('TEXT 0,30,"3",0,2,2,"RECEIPT"'));
    expect(
      output,
      contains('TEXT 0,100,"3",0,1,1,"Receipt number: 117 - 44332"'),
    );
    expect(output, contains('TEXT 0,200,"3",0,1,1,"Big Machinery, LLC"'));
    expect(output, contains('TEXT 294,200,"3",0,1,1,"Bill To"'));
    expect(output, contains('BOX 0,360,288,398,2'));
    expect(output, contains('BAR 50,685,476,2'));
    expect(output, contains('QRCODE'));
    expect(output, endsWith('PRINT 1,1\r\n'));
  });

  test('wraps long table cells and auto-expands row height', () async {
    final generator = TscLabelGenerator(
      config: const TscLabelConfiguration(printWidth: 300, labelLength: 500),
      commands: const [
        TscTable(
          y: 40,
          columnWidths: [8, 4],
          headers: [
            TscTableHeader('Description'),
            TscTableHeader('Price', alignment: TscAlignment.right),
          ],
          data: [
            ['Very long product name that should wrap across lines', '\$99.00'],
          ],
          dataFontHeight: 18,
          dataFontWidth: 16,
        ),
      ],
    );

    final output = await generator.build();

    expect(output, contains('BOX 0,75,200,143,1'));
    expect(output, contains('TEXT 6,81,"3",0,1,1,"Very long product"'));
    expect(output, contains('TEXT 6,99,"3",0,1,1,"name that should"'));
    expect(output, contains('TEXT 6,117,"3",0,1,1,"wrap across lines"'));
  });

  test('supports receipt section and totals helpers', () async {
    final generator = TscLabelGenerator(
      config: const TscLabelConfiguration(printWidth: 400, labelLength: 700),
      commands: const [
        TscReceiptSection(
          y: 40,
          title: 'Bill To',
          lines: ['Doe John', '3345 Diamond St'],
        ),
        TscReceiptTotals(
          y: 300,
          x: 40,
          width: 320,
          lines: [
            TscReceiptTotalLine(label: 'Subtotal', value: '\$136.00'),
            TscReceiptTotalLine(label: 'Tax (12%)', value: '\$16.32'),
            TscReceiptTotalLine(
              label: 'Total',
              value: '\$152.32',
              fontHeight: 24,
              fontWidth: 22,
              emphasis: true,
            ),
          ],
        ),
      ],
    );

    final output = await generator.build();

    expect(output, contains('TEXT 0,40,"3",0,1,1,"Bill To"'));
    expect(output, contains('TEXT 0,82,"3",0,1,1,"Doe John"'));
    expect(output, contains('TEXT 40,300,"3",0,1,1,"Subtotal"'));
    expect(output, contains('TEXT 282,300,"3",0,1,1,2,"\$136.00"'));
    expect(output, contains('BAR 40,360,320,2'));
    expect(output, contains('TEXT 40,372,"3",0,1,1,"Total"'));
  });

  testWidgets('TscPreview renders generator content and command preview', (
    tester,
  ) async {
    final generator = TscLabelGenerator(
      config: const TscLabelConfiguration(printWidth: 406, labelLength: 203),
      commands: const [
        TscText(x: 20, y: 20, text: 'Hello Preview'),
        TscBarcode(x: 20, y: 60, data: '12345'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 500, child: TscPreview(generator: generator)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello Preview'), findsOneWidget);
    expect(find.textContaining('TEXT 20,20'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('TscPreview renders rich table and totals content', (
    tester,
  ) async {
    final generator = TscLabelGenerator(
      config: const TscLabelConfiguration(printWidth: 400, labelLength: 700),
      commands: const [
        TscTable(
          y: 40,
          columnWidths: [8, 4],
          headers: [
            TscTableHeader('Description'),
            TscTableHeader('Price', alignment: TscAlignment.right),
          ],
          data: [
            ['Very long product name that should wrap across lines', '\$99.00'],
          ],
        ),
        TscReceiptTotals(
          y: 300,
          x: 40,
          width: 320,
          lines: [
            TscReceiptTotalLine(label: 'Subtotal', value: '\$136.00'),
            TscReceiptTotalLine(
              label: 'Total',
              value: '\$152.32',
              emphasis: true,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 500, child: TscPreview(generator: generator)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.textContaining('BAR 40,'), findsOneWidget);
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
