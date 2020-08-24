import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
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
  double _initialSpan;
  double _currentSpan;

  bool ready = true;

  @override
  void addAllowedPointer(PointerEvent event) {
    if (ready) {
      ready = false;
      _pointerLocations = <int, Offset>{};
      _initialSpan = 0.0;
      _currentSpan = 0.0;
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
        final isPinch = _pointerLocations.length > 1;
        final double spanDelta = (_currentSpan - _initialSpan).abs();
        final move = _initialFocalPoint - _currentFocalPoint;
        final shouldMove = hitDetector.shouldMove(move, validateAxis, kTouchSlop);
        if (!shouldMove && !isPinch) {
          return resolve(GestureDisposition.rejected);
        } else if(spanDelta > kScaleSlop || move.distance >= kTouchSlop) {
          resolve(GestureDisposition.accepted);
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
      _initialSpan = _currentSpan;
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
    ScrollPhysics parent,
  }) : super(parent: parent);

  static final SpringDescription springDefault = SpringDescription.withDampingRatio(
    mass: 0.1,
    stiffness: 100.0,
    ratio: 1.0           ,
  );

  @override
  SpringDescription get spring => springDefault;

  @override
  PhotoViewPageViewScrollPhysics applyTo(ScrollPhysics ancestor) {
    return PhotoViewPageViewScrollPhysics(
      parent: buildParent(ancestor),
    );
  }
}
