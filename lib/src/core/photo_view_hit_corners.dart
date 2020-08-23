import 'package:flutter/widgets.dart';

import 'package:photo_view/src/controller/photo_view_controller_delegate.dart'
    show PhotoViewControllerDelegate;

mixin HitCornersDetector on PhotoViewControllerDelegate {

  HitCorners _hitCornersX() {
    final double childWidth = scaleBoundaries.childSize.width * scale;
    final double screenWidth = scaleBoundaries.outerSize.width;
    if (screenWidth >= childWidth) {
      return const HitCorners(true, true);
    }
    final x = -position.dx;
    final cornersX = this.cornersX();
    return HitCorners(x <= cornersX.min, x >= cornersX.max);
  }

  HitCorners _hitCornersY() {
    final double childHeight = scaleBoundaries.childSize.height * scale;
    final double screenHeight = scaleBoundaries.outerSize.height;
    if (screenHeight >= childHeight) {
      return const HitCorners(true, true);
    }
    final y = -position.dy;
    final cornersY = this.cornersY();
    return HitCorners(y <= cornersY.min, y >= cornersY.max);
  }

  bool _shouldMoveX(Offset move) {
    final hitCornersX = _hitCornersX();

    if (hitCornersX.hasHitAny && move != Offset.zero) {
      if (hitCornersX.hasHitBoth) {
        return false;
      }
      if (hitCornersX.hasHitMax) {
        return move.dx < 0;
      }
      return move.dx > 0;
    }
    return true;
  }

  bool _shouldMoveY(Offset move) {
    final hitCornersY = _hitCornersY();
    if (hitCornersY.hasHitAny && move != Offset.zero) {
      if (hitCornersY.hasHitBoth) {
        return false;
      }
      if (hitCornersY.hasHitMax) {
        return move.dy < 0;
      }
      return move.dy > 0;
    }
    return true;
  }

  bool shouldMove(Offset move, Axis axis) {
    assert(axis != null);
    assert(move != null);
    if(axis == Axis.vertical) {
      return _shouldMoveY(move);
    }
    return _shouldMoveX(move);
  }
}

class HitCorners {
  const HitCorners(this.hasHitMin, this.hasHitMax);

  final bool hasHitMin;
  final bool hasHitMax;

  bool get hasHitAny => hasHitMin || hasHitMax;

  bool get hasHitBoth => hasHitMin && hasHitMax;
}
