import 'dart:convert';
import 'dart:typed_data';

class TscCommandBuffer {
  TscCommandBuffer({required this.codec, required this.newLine});

  final Encoding codec;
  final String newLine;
  final BytesBuilder _buffer = BytesBuilder();

  void clear() => _buffer.clear();

  void addCommand(String command) {
    _buffer.add(codec.encode(command));
    _buffer.add(codec.encode(newLine));
  }

  void addRawBytes(List<int> bytes) {
    _buffer.add(bytes);
  }

  void addEncodedText(String value) {
    _buffer.add(codec.encode(value));
  }

  Uint8List build() => _buffer.toBytes();
}

String quoteTsc(String value) => '"${escapeTsc(value)}"';

String escapeTsc(String value) => value.replaceAll('"', r'\"');

String formatTscNumber(num value) {
  if (value is int) {
    return value.toString();
  }

  final normalized = value.toStringAsFixed(3);
  return normalized.contains('.')
      ? normalized.replaceFirst(RegExp(r'\.?0+$'), '')
      : normalized;
}

void requireRange(int value, int min, int max, String name) {
  if (value < min || value > max) {
    throw RangeError('$name must be between $min and $max. Got: $value');
  }
}

void requirePositive(num value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'Must be greater than 0');
  }
}

void requireNonNegative(num value, String name) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'Must be 0 or greater');
  }
}
