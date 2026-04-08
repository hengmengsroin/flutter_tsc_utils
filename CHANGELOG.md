## 0.2.2

- Improved public API documentation coverage with Dartdoc comments across generator, declarative, enum, and options APIs.

## 0.2.1

- Improved `TscPreview` rendering on narrow layouts by keeping the label preview readable and allowing horizontal inspection for wider labels.
- Improved `TscPreview` text measurement and table wrapping so aligned text and wrapped content more closely match the Flutter-rendered preview.
- Added regression coverage for narrow preview layouts.

## 0.2.0

- Added a declarative `TscLabelGenerator` API with async `build()` and `buildBytes()` helpers.
- Added `TscLabelConfiguration` and `TscPrintDensity` for readable label setup in the declarative flow.
- Added reusable command objects including `TscText`, `TscBarcode`, `TscQrCode`, `TscBitmap`, `TscRenderedText`, and `TscRawCommand`.
- Added richer layout primitives including `TscColumn`, `TscGridRow`, `TscGridCol`, `TscTable`, `TscTableHeader`, and `TscSeparator`.
- Added receipt-oriented helpers `TscReceiptSection`, `TscReceiptTotals`, and `TscReceiptTotalLine`.
- Added automatic table cell wrapping with row height expansion for longer content.
- Added a local `TscPreview` widget that renders an approximate live label preview and TSPL command output for declarative generators, including richer layout commands.
- Updated the example app and package documentation to cover the new declarative, preview, and receipt-style APIs.

## 0.1.0

- Initial public release of `flutter_tsc_utils`.
- Added a chainable `TscGenerator` for generating TSPL/TSPL2 commands.
- Added label setup and printer control commands such as `SIZE`, `GAP`, `DENSITY`, `DIRECTION`, `SET PEEL`, `SET TEAR`, `SET CUTTER`, and `SET PARTIAL_CUTTER`.
- Added drawing and barcode commands including `TEXT`, `BLOCK`, `BARCODE`, `QRCODE`, `PDF417`, `DMATRIX`, `BAR`, `BOX`, `ERASE`, and `REVERSE`.
- Added bitmap printing support and Flutter-rendered `khmerText()` for Khmer and other unsupported printer-font text.
- Added tests and publish-ready package documentation.
