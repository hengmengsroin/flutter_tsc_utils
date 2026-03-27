import 'enums.dart';

class TscTextStyle {
  const TscTextStyle({
    this.font = TscFont.font3,
    this.rotation = TscRotation.angle0,
    this.xMultiplier = 1,
    this.yMultiplier = 1,
    this.alignment,
  }) : assert(xMultiplier >= 1 && xMultiplier <= 10),
       assert(yMultiplier >= 1 && yMultiplier <= 10);

  final TscFont font;
  final TscRotation rotation;
  final int xMultiplier;
  final int yMultiplier;
  final TscTextAlignment? alignment;

  TscTextStyle copyWith({
    TscFont? font,
    TscRotation? rotation,
    int? xMultiplier,
    int? yMultiplier,
    TscTextAlignment? alignment,
  }) {
    return TscTextStyle(
      font: font ?? this.font,
      rotation: rotation ?? this.rotation,
      xMultiplier: xMultiplier ?? this.xMultiplier,
      yMultiplier: yMultiplier ?? this.yMultiplier,
      alignment: alignment ?? this.alignment,
    );
  }
}
