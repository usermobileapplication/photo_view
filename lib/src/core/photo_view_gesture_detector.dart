import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'photo_view_hit_corners.dart';

class PhotoViewGestureDetector extends StatelessWidget {
  const PhotoViewGestureDetector({
    Key key,
    this.hitDetector,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onDoubleTap,
    this.child,
    this.onTapUp,
    this.onTapDown,
    this.behavior,
  }) : super(key: key);

  final GestureDoubleTapCallback onDoubleTap;
  final HitCornersDetector hitDetector;

  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;
  final GestureScaleEndCallback onScaleEnd;

  final GestureTapUpCallback onTapUp;
  final GestureTapDownCallback onTapDown;

  final Widget child;

  final HitTestBehavior behavior;

  @override
  Widget build(BuildContext context) {
    final scope = PhotoViewGestureDetectorScope.of(context);

    final Axis axis = scope?.axis;

    final Map<Type, GestureRecognizerFactory> gestures =
        <Type, GestureRecognizerFactory>{};

    if (onTapDown != null || onTapUp != null) {
      gestures[TapGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(debugOwner: this),
        (TapGestureRecognizer instance) {
          instance
            ..onTapDown = onTapDown
            ..onTapUp = onTapUp;
        },
      );
    }

    gestures[DoubleTapGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
      () => DoubleTapGestureRecognizer(debugOwner: this),
      (DoubleTapGestureRecognizer instance) {
        instance..onDoubleTap = onDoubleTap;
      },
    );

    gestures[PhotoViewGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<PhotoViewGestureRecognizer>(
      () => PhotoViewGestureRecognizer(
          hitDetector: hitDetector, debugOwner: this, validateAxis: axis),
      (PhotoViewGestureRecognizer instance) {
        instance
          ..onStart = onScaleStart
          ..onUpdate = onScaleUpdate
          ..onEnd = onScaleEnd;
      },
    );

    return RawGestureDetector(
      behavior: behavior,
      child: child,
      gestures: gestures,
    );
  }
}

class PhotoViewGestureRecognizer extends ScaleGestureRecognizer {
  PhotoViewGestureRecognizer({
    this.hitDetector,
    Object debugOwner,
    this.validateAxis,
    PointerDeviceKind kind,
  }) : super(debugOwner: debugOwner, kind: kind);
  final HitCornersDetector hitDetector;
  final Axis validateAxis;

  Map<int, Offset> _pointerLocations = <int, Offset>{};

  Offset _initialFocalPoint;
  Offset _currentFocalPoint;

  bool ready = true;

  @override
  void addAllowedPointer(PointerEvent event) {
    if (ready) {
      ready = false;
      _pointerLocations = <int, Offset>{};
    }
    super.addAllowedPointer(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    ready = true;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    assert(!ready);
    if (validateAxis != null) {
      _computeEvent(event);
      if (event is PointerMoveEvent) {
        final move = _initialFocalPoint - _currentFocalPoint;
        final shouldMove = hitDetector.shouldMove(move, validateAxis);
        print(move.distance);
        if (!shouldMove) {
          //return resolve(GestureDisposition.rejected);
        } else if(move.distance > 0) {
//          resolve(GestureDisposition.accepted);
//          acceptGesture(event.pointer);
//          return;
        }
      }
    }
    super.handleEvent(event);
  }

  void _computeEvent(PointerEvent event) {
    bool didChangeConfiguration = false;
    if (event is PointerMoveEvent) {
      _pointerLocations[event.pointer] = event.position;
    } else if (event is PointerDownEvent) {
      _pointerLocations[event.pointer] = event.position;
      didChangeConfiguration = true;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerLocations.remove(event.pointer);
      didChangeConfiguration = true;
    }
    _updateDistances();
    if (didChangeConfiguration) {
      _initialFocalPoint = _currentFocalPoint;
    }
  }

  void _updateDistances() {
    final int count = _pointerLocations.keys.length;
    Offset focalPoint = Offset.zero;
    for (int pointer in _pointerLocations.keys)
      focalPoint += _pointerLocations[pointer];
    _currentFocalPoint =
        count > 0 ? focalPoint / count.toDouble() : Offset.zero;
  }
}

/// An [InheritedWidget] responsible to give a axis aware scope to [PhotoViewGestureRecognizer].
///
/// When using this, PhotoView will test if the content zoomed has hit edge every time user pinches,
/// if so, it will let parent gesture detectors win the gesture arena
///
/// Useful when placing PhotoView inside a gesture sensitive context,
/// such as [PageView], [Dismissible], [BottomSheet].
///
/// Usage example:
/// ```
/// PhotoViewGestureDetectorScope(
///   axis: Axis.vertical,
///   child: PhotoView(
///     imageProvider: AssetImage("assets/pudim.jpg"),
///   ),
/// );
/// ```
class PhotoViewGestureDetectorScope extends InheritedWidget {
  PhotoViewGestureDetectorScope({
    this.axis,
    @required Widget child,
  }) : super(child: child);

  static PhotoViewGestureDetectorScope of(BuildContext context) {
    final PhotoViewGestureDetectorScope scope = context
        .dependOnInheritedWidgetOfExactType<PhotoViewGestureDetectorScope>();
    return scope;
  }

  final Axis axis;

  @override
  bool updateShouldNotify(PhotoViewGestureDetectorScope oldWidget) {
    return axis != oldWidget.axis;
  }
}

class PhotoViewPageViewScrollPhysics extends ScrollPhysics {
  const PhotoViewPageViewScrollPhysics({
    this.touchSlopFactor = 1.1,
    ScrollPhysics parent,
  }) : super(parent: parent);

  // in [0, 1]
  // 0: most reactive but will not let PhotoView recognizers accept gestures
  // 1: less reactive but gives the most leeway to PhotoView recognizers
  final double touchSlopFactor;

  @override
  PhotoViewPageViewScrollPhysics applyTo(ScrollPhysics ancestor) {
    return PhotoViewPageViewScrollPhysics(
      touchSlopFactor: touchSlopFactor,
      parent: buildParent(ancestor),
    );
  }

  @override
  double get dragStartDistanceMotionThreshold => kPanSlop * touchSlopFactor;
}
