import 'enums.dart';

class TscPdf417Options {
  const TscPdf417Options({
    this.compression = TscPdf417CompressionMode.auto,
    this.errorCorrectionLevel,
    this.centerPattern = false,
    this.moduleWidth,
    this.barHeight,
    this.maxRows,
    this.maxColumns,
    this.truncated = false,
  });

  final TscPdf417CompressionMode compression;
  final int? errorCorrectionLevel;
  final bool centerPattern;
  final int? moduleWidth;
  final int? barHeight;
  final int? maxRows;
  final int? maxColumns;
  final bool truncated;
}

class TscDataMatrixOptions {
  const TscDataMatrixOptions({
    this.controlCharacter,
    this.moduleSize,
    this.rotation = TscRotation.angle0,
    this.shape = TscDataMatrixShape.square,
    this.rows,
    this.columns,
  });

  final int? controlCharacter;
  final int? moduleSize;
  final TscRotation rotation;
  final TscDataMatrixShape shape;
  final int? rows;
  final int? columns;
}
