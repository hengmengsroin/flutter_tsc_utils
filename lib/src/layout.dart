import 'enums.dart';

class TscPoint {
  const TscPoint(this.x, this.y);

  final int x;
  final int y;
}

class TscPadding {
  const TscPadding.fromLTRB(this.left, this.top, this.right, this.bottom);

  const TscPadding.all(int value)
    : left = value,
      top = value,
      right = value,
      bottom = value;

  const TscPadding.symmetric({int horizontal = 0, int vertical = 0})
    : left = horizontal,
      top = vertical,
      right = horizontal,
      bottom = vertical;

  static const zero = TscPadding.all(0);

  final int left;
  final int top;
  final int right;
  final int bottom;
}

class TscRect {
  const TscRect(this.x, this.y, this.width, this.height);

  final int x;
  final int y;
  final int width;
  final int height;

  int get right => x + width;
  int get bottom => y + height;

  TscRect inset(TscPadding padding) {
    return TscRect(
      x + padding.left,
      y + padding.top,
      width - padding.left - padding.right,
      height - padding.top - padding.bottom,
    );
  }
}

class TscSection {
  TscSection(this.bounds, {this.padding = TscPadding.zero});

  final TscRect bounds;
  final TscPadding padding;
  int _cursorY = 0;

  TscRect get contentBounds => bounds.inset(padding);

  TscRect row(int height, {int spacingAfter = 0}) {
    final content = contentBounds;
    final row = TscRect(content.x, content.y + _cursorY, content.width, height);
    _cursorY += height + spacingAfter;
    return row;
  }

  List<TscRect> rows(List<int> heights, {int spacing = 0}) {
    final rects = <TscRect>[];
    for (var i = 0; i < heights.length; i++) {
      rects.add(
        row(heights[i], spacingAfter: i == heights.length - 1 ? 0 : spacing),
      );
    }
    return rects;
  }

  TscPoint anchor(
    int childWidth,
    int childHeight, {
    TscAnchor anchor = TscAnchor.center,
  }) {
    final content = contentBounds;
    final dx = switch (anchor) {
      TscAnchor.topLeft || TscAnchor.centerLeft || TscAnchor.bottomLeft => 0,
      TscAnchor.topCenter ||
      TscAnchor.center ||
      TscAnchor.bottomCenter => (content.width - childWidth) ~/ 2,
      TscAnchor.topRight ||
      TscAnchor.centerRight ||
      TscAnchor.bottomRight => content.width - childWidth,
    };
    final dy = switch (anchor) {
      TscAnchor.topLeft || TscAnchor.topCenter || TscAnchor.topRight => 0,
      TscAnchor.centerLeft ||
      TscAnchor.center ||
      TscAnchor.centerRight => (content.height - childHeight) ~/ 2,
      TscAnchor.bottomLeft ||
      TscAnchor.bottomCenter ||
      TscAnchor.bottomRight => content.height - childHeight,
    };
    return TscPoint(content.x + dx, content.y + dy);
  }

  TscSection section(
    int x,
    int y,
    int width,
    int height, {
    TscPadding padding = TscPadding.zero,
  }) {
    return TscSection(TscRect(x, y, width, height), padding: padding);
  }
}

class TscLabelLayout extends TscSection {
  TscLabelLayout({
    required int width,
    required int height,
    TscPadding padding = TscPadding.zero,
  }) : super(TscRect(0, 0, width, height), padding: padding);
}
