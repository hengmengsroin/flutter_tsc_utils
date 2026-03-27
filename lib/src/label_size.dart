import 'enums.dart';

class TscLabelSize {
  const TscLabelSize(this.width, this.height, {this.unit = TscUnit.mm});

  final num width;
  final num height;
  final TscUnit unit;
}
