import 'package:image/image.dart' as img;

import 'enums.dart';
import 'layout.dart';

class TscFittedImage {
  const TscFittedImage({required this.image, required this.offset});

  final img.Image image;
  final TscPoint offset;
}

class TscImageHelper {
  static TscFittedImage fitInto(
    img.Image source, {
    required int boxWidth,
    required int boxHeight,
    TscImageFit fit = TscImageFit.contain,
    TscAnchor anchor = TscAnchor.center,
    int backgroundColor = 0xFFFFFFFF,
    bool allowUpscale = true,
  }) {
    if (boxWidth <= 0 || boxHeight <= 0) {
      throw ArgumentError('boxWidth and boxHeight must be greater than 0');
    }

    if (fit == TscImageFit.none) {
      final canvas = _filledCanvas(boxWidth, boxHeight, backgroundColor);
      final point = _anchorPoint(
        containerWidth: boxWidth,
        containerHeight: boxHeight,
        childWidth: source.width,
        childHeight: source.height,
        anchor: anchor,
      );
      img.compositeImage(canvas, source, dstX: point.x, dstY: point.y);
      return TscFittedImage(image: canvas, offset: const TscPoint(0, 0));
    }

    final scaleX = boxWidth / source.width;
    final scaleY = boxHeight / source.height;
    var scale = switch (fit) {
      TscImageFit.contain => scaleX < scaleY ? scaleX : scaleY,
      TscImageFit.cover => scaleX > scaleY ? scaleX : scaleY,
      TscImageFit.fill => 0,
      TscImageFit.scaleDown =>
        (scaleX < scaleY ? scaleX : scaleY) < 1
            ? (scaleX < scaleY ? scaleX : scaleY)
            : 1,
      TscImageFit.none => 1,
    };

    if (!allowUpscale && scale > 1) {
      scale = 1;
    }

    if (fit == TscImageFit.fill) {
      final resized = img.copyResize(
        source,
        width: boxWidth,
        height: boxHeight,
      );
      return TscFittedImage(image: resized, offset: const TscPoint(0, 0));
    }

    final resized = img.copyResize(
      source,
      width: (source.width * scale).round().clamp(1, 65535),
      height: (source.height * scale).round().clamp(1, 65535),
    );

    if (fit == TscImageFit.cover) {
      final point = _anchorPoint(
        containerWidth: resized.width,
        containerHeight: resized.height,
        childWidth: boxWidth,
        childHeight: boxHeight,
        anchor: anchor,
      );
      final cropped = img.copyCrop(
        resized,
        x: point.x.clamp(0, resized.width - boxWidth),
        y: point.y.clamp(0, resized.height - boxHeight),
        width: boxWidth,
        height: boxHeight,
      );
      return TscFittedImage(image: cropped, offset: const TscPoint(0, 0));
    }

    final canvas = _filledCanvas(boxWidth, boxHeight, backgroundColor);
    final point = _anchorPoint(
      containerWidth: boxWidth,
      containerHeight: boxHeight,
      childWidth: resized.width,
      childHeight: resized.height,
      anchor: anchor,
    );
    img.compositeImage(canvas, resized, dstX: point.x, dstY: point.y);
    return TscFittedImage(image: canvas, offset: const TscPoint(0, 0));
  }

  static TscPoint _anchorPoint({
    required int containerWidth,
    required int containerHeight,
    required int childWidth,
    required int childHeight,
    required TscAnchor anchor,
  }) {
    final dx = switch (anchor) {
      TscAnchor.topLeft || TscAnchor.centerLeft || TscAnchor.bottomLeft => 0,
      TscAnchor.topCenter ||
      TscAnchor.center ||
      TscAnchor.bottomCenter => (containerWidth - childWidth) ~/ 2,
      TscAnchor.topRight ||
      TscAnchor.centerRight ||
      TscAnchor.bottomRight => containerWidth - childWidth,
    };
    final dy = switch (anchor) {
      TscAnchor.topLeft || TscAnchor.topCenter || TscAnchor.topRight => 0,
      TscAnchor.centerLeft ||
      TscAnchor.center ||
      TscAnchor.centerRight => (containerHeight - childHeight) ~/ 2,
      TscAnchor.bottomLeft ||
      TscAnchor.bottomCenter ||
      TscAnchor.bottomRight => containerHeight - childHeight,
    };
    return TscPoint(dx, dy);
  }

  static img.Color _colorFromInt(int value) {
    final a = (value >> 24) & 0xFF;
    final r = (value >> 16) & 0xFF;
    final g = (value >> 8) & 0xFF;
    final b = value & 0xFF;
    return img.ColorInt32.rgba(r, g, b, a == 0 ? 255 : a);
  }

  static img.Image _filledCanvas(int width, int height, int color) {
    final canvas = img.Image(width: width, height: height);
    final fillColor = _colorFromInt(color);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        canvas.setPixel(x, y, fillColor);
      }
    }
    return canvas;
  }
}
