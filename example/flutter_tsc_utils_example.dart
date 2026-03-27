// ignore_for_file: avoid_print

import 'package:flutter/painting.dart';
import 'package:flutter_tsc_utils/flutter_tsc_utils.dart';

Future<void> main() async {
  final generator = TscGenerator()
    ..size(const TscLabelSize(60, 40))
    ..gap(2, 0)
    ..density(8)
    ..direction(TscDirection.forward)
    ..setPeel(TscToggle.off)
    ..cls()
    ..text(20, 20, 'Hello TSC')
    ..barcode(20, 70, '123456789012', height: 70)
    ..qrCode(20, 170, 'https://example.com');

  await generator.khmerText(
    20,
    260,
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

  final bytes = generator.build();
  final preview = generator.preview();

  print('Generated ${bytes.length} bytes');
  print(preview);
}
