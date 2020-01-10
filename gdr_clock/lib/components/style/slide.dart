import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gdr_clock/clock.dart';

class Slide extends LeafRenderObjectWidget {
  final Color curveColor;

  Slide({
    Key key,
    @required this.curveColor,
  })  : assert(curveColor != null),
        super(key: key);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderSlide(
      curveColor: curveColor,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderSlide renderObject) {
    renderObject..curveColor = curveColor;
  }
}

class SlideParentData extends ClockChildrenParentData {
  /// Positions relative to the top left of the render box.
  Offset start, end, destination;

  double ballRadius;

  BallTripStage stage;

  /// Animation value for the current [stage].
  ///
  /// This is needed to easily determine when the
  /// travel slide needs to be contracted.
  double animationValue;
}

class RenderSlide extends RenderCompositionChild<ClockComponent, SlideParentData> {
  RenderSlide({
    Color curveColor,
  })  : _curveColor = curveColor,
        super(ClockComponent.slide);

  Color _curveColor;

  set curveColor(Color value) {
    assert(value != null);

    if (_curveColor == value) {
      return;
    }

    _curveColor = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);

    compositionData.hasSemanticsInformation = false;
  }

  @override
  void performResize() {
    size = constraints.biggest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    canvas.save();
    // Translate to the top left of this box.
    canvas.translate(offset.dx, offset.dy);

    // The positions are already given relative to the top left.
    final start = compositionData.start, end = compositionData.end, destination = compositionData.destination;

    // Need to know where the start line is located in order to
    // properly add padding to account for the ball's size.
    final startLeft = start.dx < end.dx;

    final ballRadius = compositionData.ballRadius,
        // The ball's circumference.
        ballLength = ballRadius * 2 * pi;

    // The stroke width is drawn out equally in both directions from
    // the 0 width line and thus, the lines need to be shifted a bit more
    // if they should only touch the ball instead of overlapping.
    final strokeWidth = size.shortestSide / 51, shiftFactor = 1 + strokeWidth / 2 / ballRadius;

    var startLine = Line2d(start: start, end: destination)
          ..padEnd(.7)
          ..padStart(1.6),
        endLine = Line2d(start: end, end: destination)
          ..padEnd(.7)
          ..padStart(1.5),
        travelLine = Line2d(start: end, end: start);

    // The start line should touch the ball on its side.
    // The same also goes for the end line, which is
    // why startLeft is required.
    startLine.shift(startLine.normal.offset * ballRadius * (startLeft ? shiftFactor : -shiftFactor));
    endLine.shift(endLine.normal.offset * ballRadius * (startLeft ? -shiftFactor : shiftFactor));

    travelLine
        // The line should touch the ball's bottom.
        .shift(travelLine.normal.offset * ballRadius * -shiftFactor);

    switch (compositionData.stage) {
      case BallTripStage.travel:
        final travelLength = travelLine.length, ballLengthFraction = ballLength / travelLength;
        final leftSequence = TweenSequence([
          TweenSequenceItem(tween: null, weight: ballRadius),
          TweenSequenceItem(tween: null, weight: travelLength),
        ]),
            rightSequence = TweenSequence([
          TweenSequenceItem(tween: null, weight: travelLength),
          TweenSequenceItem(tween: null, weight: ballRadius),
        ]);
        ;
        break;
      case BallTripStage.arrival:
        final arrivalLength = startLine.length, ballLengthFraction = ballLength / arrivalLength;
        final sequence = TweenSequence([
          TweenSequenceItem(tween: null, weight: ballRadius),
          TweenSequenceItem(tween: null, weight: arrivalLength),
        ]);
        break;
      case BallTripStage.departure:
        final departureLength = endLine.length, ballLengthFraction = ballLength / departureLength;
        final sequence = TweenSequence([
          TweenSequenceItem(tween: ConstantTween(1), weight: departureLength),
          TweenSequenceItem(
            tween: Tween(begin: 1, end: 1 - ballLengthFraction).chain(CurveTween(curve: const AccelerateCurve())),
            weight: ballRadius,
          ),
        ]);

        travelLine.padEnd(sequence.transform(compositionData.animationValue));
        break;
    }

    final paint = Paint()..color = _curveColor;

    canvas.drawPath(travelLine.pathWithWidth(strokeWidth), paint);
    canvas.drawPath(startLine.pathWithWidth(strokeWidth), paint);
    canvas.drawPath(endLine.pathWithWidth(strokeWidth), paint);

    canvas.restore();
  }
}
