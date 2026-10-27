import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Carries its child from where it was last seen on screen to where it now is,
/// instead of letting it jump. Wrap a widget in a [GlobalKey]ed [SlideToPlace]
/// so it keeps its state when it moves between parents.
///
/// The motion is a spring that first strains a little toward the new spot, as
/// if the child were stuck where it was, then breaks free, overshoots slightly
/// and settles.
class SlideToPlace extends StatefulWidget {
  const SlideToPlace({
    super.key,
    required this.zone,
    required this.child,
    this.followLayout = true,
  });

  /// Where the child lives. A change slides it from its old spot to the new one.
  final Object zone;

  /// Also slide when the parent re-flows the child within the same zone. Off for
  /// children whose parent animates them itself.
  final bool followLayout;

  final Widget child;

  @override
  State<SlideToPlace> createState() => _SlideToPlaceState();
}

class _SlideToPlaceState extends State<SlideToPlace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );

  /// Where the child sat when last measured, ignoring the slide in progress.
  Offset? _layoutAt;
  Offset _delta = Offset.zero;
  bool _zoneChanged = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SlideToPlace old) {
    super.didUpdateWidget(old);
    if (old.zone != widget.zone) _zoneChanged = true;
  }

  Offset get _offset => _delta * (1 - _controller.value);

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final at = box.localToGlobal(Offset.zero);
    final before = _layoutAt;
    final moved =
        before != null &&
        (_zoneChanged || widget.followLayout) &&
        (at - before).distance > 0.5;
    if (moved && !MediaQuery.of(context).disableAnimations) {
      final from = before + _offset;
      final delta = from - at;
      if (delta.distance > 0.5) {
        _delta = delta;
        final pull = (5 / delta.distance).clamp(0.0, 0.05);
        _controller.animateWith(_Breakaway(pull));
      }
    }
    _zoneChanged = false;
    _layoutAt = at;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Transform.translate(offset: _offset, child: child),
      child: widget.child,
    );
  }
}

/// Progress from 0 (the old spot) to 1 (the new one): a short strain, then a
/// lightly underdamped spring.
class _Breakaway extends Simulation {
  _Breakaway(this.pull)
    : _spring = SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 380, damping: 29),
        pull,
        1,
        0,
      );

  /// How far the strain pulls toward the target, as a share of the distance.
  final double pull;
  final SpringSimulation _spring;

  static const _hold = 0.08;

  @override
  double x(double time) => time < _hold
      ? pull * Curves.easeInOut.transform(time / _hold)
      : _spring.x(time - _hold);

  @override
  double dx(double time) => time < _hold ? 0 : _spring.dx(time - _hold);

  @override
  bool isDone(double time) => time >= _hold && _spring.isDone(time - _hold);
}
