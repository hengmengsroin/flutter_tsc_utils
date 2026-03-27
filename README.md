# flutter_tsc_utils

Utilities for generating TSC `TSPL` / `TSPL2` printer commands from Flutter and Dart.

This package is shaped after `flutter_esc_pos_utils`, but targets TSC label printers and produces TSPL command bytes instead of ESC/POS receipt data.

## Features

- Setup commands like `SIZE`, `GAP`, `DENSITY`, `DIRECTION`, `REFERENCE`, and `CLS`
- Drawing commands like `TEXT`, `BARCODE`, `QRCODE`, `BAR`, and `BOX`
- Bitmap rasterization for the `BITMAP` command
- Raw command and raw byte hooks for unsupported TSPL features

## Usage

```dart
import 'package:flutter_tsc_utils/flutter_tsc_utils.dart';

void main() {
  final generator = TscGenerator();

  generator
    ..size(const TscLabelSize(60, 40))
    ..gap(2, 0)
    ..density(8)
    ..direction(TscDirection.forward)
    ..cls()
    ..text(20, 20, 'Hello TSC')
    ..barcode(20, 80, '123456789012')
    ..qrCode(20, 180, 'https://example.com')
    ..print();

  final bytes = generator.build();
  // Send bytes over Bluetooth, USB, or TCP to the printer.
}
```

## Notes

- TSC models vary a bit in supported commands, fonts, and barcode types.
- Layout commands like `SIZE` and `GAP` accept units, while object placement uses printer dots.
- If you need a command that is not wrapped yet, use `rawCommand()` or `rawBytes()`.
