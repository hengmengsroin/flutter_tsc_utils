# flutter_tsc_utils

Utilities for generating TSC `TSPL` / `TSPL2` printer commands from Flutter and Dart.

This package is shaped after `flutter_esc_pos_utils`, but targets TSC label printers and produces TSPL command bytes instead of ESC/POS receipt data.

## Features

- Setup commands like `SIZE`, `GAP`, `DENSITY`, `DIRECTION`, `REFERENCE`, and `CLS`
- Drawing commands like `TEXT`, `BARCODE`, `QRCODE`, `BAR`, and `BOX`
- Richer label commands like `BLOCK`, `PDF417`, `DMATRIX`, `REVERSE`, `ERASE`, and `PUTBMP`
- Printer control commands like `SET PEEL`, `SET TEAR`, `SET CUTTER`, `SET PARTIAL_CUTTER`, `SET REWIND`, and `SET RIBBON`
- Bitmap rasterization for the `BITMAP` command
- Flutter-rendered `khmerText()` support for Khmer and other Unicode text that printer fonts do not handle well
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

- A live label preview
- A TSPL command preview
- A Khmer text demo using `khmerText()`

Run it with:

```bash
cd example
flutter pub get
flutter run
```

## Notes

- TSC models vary a bit in supported commands, fonts, and barcode types.
- Layout commands like `SIZE` and `GAP` accept units, while object placement uses printer dots.
- `khmerText()` depends on a Khmer-capable Flutter font such as `NotoSansKhmer`.
- If you need a command that is not wrapped yet, use `rawCommand()` or `rawBytes()`.
