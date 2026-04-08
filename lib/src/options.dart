import 'enums.dart';

/// Optional tuning values for the `PDF417` command.
class TscPdf417Options {
  /// Creates PDF417 options.
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

  /// Compression mode.
  final TscPdf417CompressionMode compression;

  /// Optional error correction level (0-8).
  final int? errorCorrectionLevel;

  /// Whether to use center pattern.
  final bool centerPattern;

  /// Optional module width (2-9).
  final int? moduleWidth;

  /// Optional bar height (4-99).
  final int? barHeight;

  /// Optional maximum number of rows.
  final int? maxRows;

  /// Optional maximum number of columns.
  final int? maxColumns;

  /// Whether to generate truncated output.
  final bool truncated;
}

/// Optional tuning values for the `DMATRIX` command.
class TscDataMatrixOptions {
  /// Creates Data Matrix options.
  const TscDataMatrixOptions({
    this.controlCharacter,
    this.moduleSize,
    this.rotation = TscRotation.angle0,
    this.shape = TscDataMatrixShape.square,
    this.rows,
    this.columns,
  });

  /// Optional control character value (0-255).
  final int? controlCharacter;

  /// Optional module size.
  final int? moduleSize;

  /// Symbol rotation.
  final TscRotation rotation;

  /// Preferred shape.
  final TscDataMatrixShape shape;

  /// Optional fixed row count.
  final int? rows;

  /// Optional fixed column count.
  final int? columns;
}
