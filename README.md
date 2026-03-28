# flutter_tsc_utils

Utilities for generating TSC `TSPL` / `TSPL2` printer commands from Flutter and Dart.

This package is shaped after `flutter_esc_pos_utils`, but targets TSC label printers and produces TSPL command bytes instead of ESC/POS receipt data.

## Features

- Setup commands like `SIZE`, `GAP`, `DENSITY`, `DIRECTION`, `REFERENCE`, and `CLS`
- Drawing commands like `TEXT`, `BARCODE`, `QRCODE`, `BAR`, and `BOX`
- Richer label commands like `BLOCK`, `PDF417`, `DMATRIX`, `REVERSE`, `ERASE`, and `PUTBMP`
- Printer control commands like `SET PEEL`, `SET TEAR`, `SET CUTTER`, `SET PARTIAL_CUTTER`, `SET REWIND`, and `SET RIBBON`
- File and device commands like `DOWNLOAD`, `FILES`, `KILL`, `MOVE`, `FORMFEED`, `SELFTEST`, and immediate status/query bytes
- Bitmap rasterization for the `BITMAP` command
- Flutter-rendered `khmerText()` support for Khmer and other Unicode text that printer fonts do not handle well
- Layout helpers for sections, rows, anchors, and padding
- Image/logo fitting helpers for scaling and centering into label regions
- Input validation for common parameter ranges
- Chainable API plus raw command and raw byte hooks for unsupported TSPL features

## Usage

```dart
import 'package:flutter_tsc_utils/flutter_tsc_utils.dart';

Future<void> main() async {
  final generator = TscGenerator();

  generator
    ..size(const TscLabelSize(60, 40))
    ..gap(2, 0)
    ..density(8)
    ..direction(TscDirection.forward)
    ..setPeel(TscToggle.off)
    ..cls()
    ..text(20, 20, 'Hello TSC')
    ..block(
      20,
      50,
      300,
      80,
      'Multi-line text block',
      alignment: TscBlockAlignment.center,
    )
    ..barcode(20, 80, '123456789012')
    ..qrCode(20, 180, 'https://example.com')
    ..pdf417(20, 260, 300, 140, 'payload')
    ..print();

  final bytes = generator.build();
  // Send bytes over Bluetooth, USB, or TCP to the printer.
}
```

## Declarative Generator

If you prefer a `config + commands + await build()` flow, use `TscLabelGenerator`:

```dart
import 'package:flutter_tsc_utils/flutter_tsc_utils.dart';

final generator = TscLabelGenerator(
  config: const TscLabelConfiguration(
    printWidth: 406, // 2 inches at 203 DPI
    labelLength: 203, // 1 inch at 203 DPI
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

final tspl = await generator.build();
final bytes = await generator.buildBytes();
```

## Live Preview Widget

For a fast local preview in Flutter, wrap the same declarative generator in `TscPreview`:

```dart
class LabelPreviewScreen extends StatelessWidget {
  LabelPreviewScreen({super.key});

  final generator = TscLabelGenerator(
    config: const TscLabelConfiguration(
      printWidth: 406,
      labelLength: 203,
    ),
    commands: const [
      TscText(x: 20, y: 20, text: 'Hello World!'),
      TscBarcode(x: 20, y: 60, data: '12345'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: TscPreview(generator: generator),
      ),
    );
  }
}
```

`TscPreview` rebuilds from the same `TscLabelGenerator`, renders an approximate local label view for common commands, and also shows the generated TSPL command text below it.

## Rich Layout API

For receipt-style labels, you can compose higher-level layout commands:

```dart
final generator = TscLabelGenerator(
  config: const TscLabelConfiguration(
    printWidth: 576,
    labelLength: 1200,
    printDensity: TscPrintDensity.d8,
  ),
  commands: const [
    TscText(x: 0, y: 30, text: 'RECEIPT', fontHeight: 50, fontWidth: 45),
    TscText(x: 0, y: 100, text: 'Receipt number: 117 - 44332'),
    TscText(x: 0, y: 130, text: 'Date of purchase: December 8, 2023'),
    TscGridRow(
      y: 200,
      children: [
        TscGridCol(
          width: 6,
          child: TscColumn(
            children: [
              TscText(text: 'Big Machinery, LLC', fontHeight: 25, fontWidth: 22),
              TscText(
                text: '3345, Diamond St, Orange City, ST 9987',
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
        TscTableHeader('Item'),
        TscTableHeader('Qty', alignment: TscAlignment.center),
        TscTableHeader('Unit', alignment: TscAlignment.center),
        TscTableHeader('Total', alignment: TscAlignment.center),
      ],
      data: [
        ['Fuel Plastic Jug (10 gal)', '01', '\$34.00', '\$34.00'],
        ['Gas Hose (5 feet)', '01', '\$15.00', '\$15.00'],
        ['Aluminum Screw (4 in)', '100', '\$0.87', '\$87.00'],
      ],
      dataFontHeight: 18,
      dataFontWidth: 16,
    ),
    TscSeparator(y: 685, thickness: 2, paddingLeft: 50, paddingRight: 50),
    TscText(x: 50, y: 710, text: 'Total: \$152.32', fontHeight: 26, fontWidth: 24),
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

final tspl = await generator.build();
```

You can also use the higher-level receipt helpers when you want a cleaner totals or address section API:

```dart
final generator = TscLabelGenerator(
  config: const TscLabelConfiguration(
    printWidth: 400,
    labelLength: 700,
  ),
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
```

## Preview Service Note

`Labelary` is a ZPL renderer, so it cannot render this package's TSC `TSPL/TSPL2` output directly. This package therefore provides a local `TscPreview` widget instead of a misleading `LabelaryService` wrapper for TSPL.

## Khmer Text

For Khmer, the safest path is rendering text with Flutter and printing it as a bitmap:

```dart
import 'package:flutter/painting.dart';
import 'package:flutter_tsc_utils/flutter_tsc_utils.dart';

Future<void> printKhmer() async {
  final generator = TscGenerator()
    ..size(const TscLabelSize(60, 40))
    ..gap(2, 0)
    ..cls();

  await generator.khmerText(
    20,
    20,
    'សួស្តី​ពិភពលោក',
    options: const TscRenderedTextOptions(
      style: TextStyle(
        fontSize: 24,
        color: Color(0xFF000000),
        fontFamily: 'NotoSansKhmer',
      ),
      pixelRatio: 2,
      padding: 4,
    ),
  );

  generator.print();
}
```

## Example App

A Flutter example app is included in [example/lib/main.dart](/Users/hengmengsroin/Documents/projects/flutter-plugins/flutter_tsc_utils/example/lib/main.dart). It provides:

- A declarative `TscLabelGenerator` demo
- A live `TscPreview` widget
- Receipt-style layout composition with text, barcode, QR, and rendered Khmer text

Run it with:

```bash
cd example
flutter pub get
flutter run
```

## Layout And Image Helpers

You can define label regions without hard-coding every coordinate:

```dart
final layout = TscLabelLayout(
  width: 600,
  height: 400,
  padding: const TscPadding.all(20),
);

final rows = layout.rows([60, 120, 140], spacing: 12);
final logoBox = layout.section(340, 20, 220, 220);
final centered = logoBox.anchor(120, 80, anchor: TscAnchor.center);
```

For logos or product images, fit them automatically into a target region:

```dart
generator.bitmapFitted(
  const TscRect(340, 20, 220, 220),
  logoImage,
  fit: TscImageFit.contain,
  anchor: TscAnchor.center,
);
```

## Notes

- TSC models vary a bit in supported commands, fonts, and barcode types.
- Layout commands like `SIZE` and `GAP` accept units, while object placement uses printer dots.
- `khmerText()` depends on a Khmer-capable Flutter font such as `NotoSansKhmer`.
- If you need a command that is not wrapped yet, use `rawCommand()` or `rawBytes()`.
