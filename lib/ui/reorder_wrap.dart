import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// A wrapping row of items the learner can drag to reorder.
///
/// The dragged item grows and follows the finger; the others glide aside to
/// open a gap where it would land. Items are identified by [ids], and
/// [onReorder] reports the new order when a drag ends somewhere new.
class ReorderWrap extends StatefulWidget {
  const ReorderWrap({
    super.key,
    required this.ids,
    required this.itemBuilder,
    required this.onReorder,
    this.enabled = true,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  final List<int> ids;
  final Widget Function(int id) itemBuilder;
  final ValueChanged<List<int>> onReorder;
  final bool enabled;
  final double spacing;
  final double runSpacing;

  @override
  State<ReorderWrap> createState() => _ReorderWrapState();
}

class _ReorderWrapState extends State<ReorderWrap>
    with SingleTickerProviderStateMixin {
  final _flowKey = GlobalKey();
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  /// Order the items are laid out in; differs from `widget.ids` mid-drag.
  late List<int> _order = List.of(widget.ids);
  int? _dragId;
  Offset _dragStart = Offset.zero;
  Offset _dragDelta = Offset.zero;

  _RenderFlow? get _flow =>
      _flowKey.currentContext?.findRenderObject() as _RenderFlow?;

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ReorderWrap old) {
    super.didUpdateWidget(old);
    if (_dragId == null || !widget.ids.contains(_dragId)) {
      _dragId = null;
      _order = List.of(widget.ids);
    }
  }

  void _startDrag(int id) {
    final flow = _flow;
    final slot = flow?.slots(_order)[id];
    if (slot == null) return;
    setState(() {
      _dragId = id;
      _dragStart = slot;
      _dragDelta = Offset.zero;
    });
  }

  void _updateDrag(Offset delta) {
    final id = _dragId;
    final flow = _flow;
    final size = id == null ? null : flow?.sizeOf(id);
    if (id == null || flow == null || size == null) return;
    _dragDelta += delta;
    final center = _dragTopLeft(size) + Offset(size.width / 2, size.height / 2);
    final others = [
      for (final o in _order)
        if (o != id) o,
    ];
    var best = _order;
    var bestDistance = double.infinity;
    for (var k = 0; k <= others.length; k++) {
      final candidate = [...others]..insert(k, id);
      final slot = flow.slots(candidate)[id];
      if (slot == null) continue;
      final distance = (slot + Offset(size.width / 2, size.height / 2) - center)
          .distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }
    setState(() => _order = best);
  }

  Offset _dragTopLeft(Size size) {
    final raw = _dragStart + _dragDelta;
    final maxX = math.max(0.0, (_flow?.size.width ?? 0) - size.width);
    return Offset(raw.dx.clamp(0.0, maxX), raw.dy);
  }

  void _endDrag() {
    if (_dragId == null) return;
    final changed = !_sameOrder(_order, widget.ids);
    setState(() => _dragId = null);
    if (changed) widget.onReorder(List.of(_order));
  }

  bool _sameOrder(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final dragId = _dragId;
    final dragSize = dragId == null ? null : _flow?.sizeOf(dragId);
    // The dragged item is painted last so it rides above the others.
    final paintOrder = [
      for (final id in widget.ids)
        if (id != dragId) id,
      ?dragId,
    ];
    return _Flow(
      key: _flowKey,
      rtl: Directionality.of(context) == TextDirection.rtl,
      order: _order,
      dragId: dragId,
      dragTopLeft: dragSize == null ? null : _dragTopLeft(dragSize),
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      glide: _glide,
      children: [
        for (final id in paintOrder)
          _FlowItem(
            key: ValueKey(id),
            id: id,
            child: _lifted(id, id == dragId),
          ),
      ],
    );
  }

  Widget _lifted(int id, bool dragging) {
    Widget child = widget.itemBuilder(id);
    if (widget.enabled) {
      child = GestureDetector(
        onPanStart: (_) => _startDrag(id),
        onPanUpdate: (d) => _updateDrag(d.delta),
        onPanEnd: (_) => _endDrag(),
        onPanCancel: _endDrag,
        child: child,
      );
    }
    return AnimatedScale(
      scale: dragging ? 1.15 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            if (dragging)
              const BoxShadow(
                color: Color(0x40000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _FlowItem extends ParentDataWidget<_FlowParentData> {
  const _FlowItem({super.key, required this.id, required super.child});

  final int id;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _FlowParentData;
    if (data.id != id) {
      data.id = id;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _Flow;
}

class _Flow extends MultiChildRenderObjectWidget {
  const _Flow({
    super.key,
    required this.rtl,
    required this.order,
    required this.dragId,
    required this.dragTopLeft,
    required this.spacing,
    required this.runSpacing,
    required this.glide,
    required super.children,
  });

  /// Fill each row from the right edge, for right-to-left writing.
  final bool rtl;
  final List<int> order;
  final int? dragId;
  final Offset? dragTopLeft;
  final double spacing;
  final double runSpacing;
  final AnimationController glide;

  @override
  _RenderFlow createRenderObject(BuildContext context) => _RenderFlow(
    rtl: rtl,
    order: order,
    dragId: dragId,
    dragTopLeft: dragTopLeft,
    spacing: spacing,
    runSpacing: runSpacing,
    glide: glide,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderFlow render) {
    render
      ..rtl = rtl
      ..order = order
      ..dragId = dragId
      ..dragTopLeft = dragTopLeft
      ..spacing = spacing
      ..runSpacing = runSpacing;
  }
}

class _FlowParentData extends ContainerBoxParentData<RenderBox> {
  int id = -1;
  bool placed = false;
  Offset from = Offset.zero;
  Offset to = Offset.zero;
}

/// Lays children out like a [Wrap] in `order`, but each child eases from where
/// it was to where it now belongs, and one child can be held at the finger.
class _RenderFlow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FlowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FlowParentData> {
  _RenderFlow({
    required bool rtl,
    required List<int> order,
    required int? dragId,
    required Offset? dragTopLeft,
    required double spacing,
    required double runSpacing,
    required AnimationController glide,
  }) : _rtl = rtl,
       _order = order,
       _dragId = dragId,
       _dragTopLeft = dragTopLeft,
       _spacing = spacing,
       _runSpacing = runSpacing,
       _glide = glide;

  bool _rtl;
  List<int> _order;
  int? _dragId;
  Offset? _dragTopLeft;
  double _spacing;
  double _runSpacing;
  final AnimationController _glide;

  /// Progress of the current glide, 0 right after a child is retargeted.
  double _t = 1;

  set rtl(bool v) {
    if (_rtl == v) return;
    _rtl = v;
    markNeedsLayout();
  }

  set order(List<int> v) {
    _order = v;
    markNeedsLayout();
  }

  set dragId(int? v) {
    _dragId = v;
    markNeedsLayout();
  }

  set dragTopLeft(Offset? v) {
    _dragTopLeft = v;
    markNeedsLayout();
  }

  set spacing(double v) {
    _spacing = v;
    markNeedsLayout();
  }

  set runSpacing(double v) {
    _runSpacing = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FlowParentData)
      child.parentData = _FlowParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _glide.addListener(_onGlide);
  }

  @override
  void detach() {
    _glide.removeListener(_onGlide);
    super.detach();
  }

  void _onGlide() {
    _t = Curves.easeOutCubic.transform(_glide.value);
    markNeedsPaint();
  }

  Offset _shown(_FlowParentData d) => Offset.lerp(d.from, d.to, _t)!;

  RenderBox? _childOf(int id) {
    for (var c = firstChild; c != null; c = childAfter(c)) {
      if ((c.parentData! as _FlowParentData).id == id) return c;
    }
    return null;
  }

  Size? sizeOf(int id) => _childOf(id)?.size;

  /// Top-left of every child when laid out in [order], for the current width.
  Map<int, Offset> slots(List<int> order) {
    final maxWidth = size.width;
    final out = <int, Offset>{};
    var x = 0.0, y = 0.0, rowHeight = 0.0;
    for (final id in order) {
      final s = sizeOf(id);
      if (s == null) continue;
      if (x > 0 && x + s.width > maxWidth) {
        x = 0;
        y += rowHeight + _runSpacing;
        rowHeight = 0;
      }
      out[id] = Offset(_rtl ? maxWidth - x - s.width : x, y);
      x += s.width + _spacing;
      rowHeight = math.max(rowHeight, s.height);
    }
    return out;
  }

  @override
  void performLayout() {
    final maxWidth = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: maxWidth);
    for (var c = firstChild; c != null; c = childAfter(c)) {
      c.layout(loose, parentUsesSize: true);
    }

    var x = 0.0, y = 0.0, rowHeight = 0.0;
    final targets = <int, Offset>{};
    for (final id in _order) {
      final s = sizeOf(id);
      if (s == null) continue;
      if (x > 0 && x + s.width > maxWidth) {
        x = 0;
        y += rowHeight + _runSpacing;
        rowHeight = 0;
      }
      targets[id] = Offset(_rtl ? maxWidth - x - s.width : x, y);
      x += s.width + _spacing;
      rowHeight = math.max(rowHeight, s.height);
    }
    size = constraints.constrain(Size(maxWidth, y + rowHeight));

    var retargeted = false;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      final d = c.parentData! as _FlowParentData;
      if (d.id == _dragId && _dragTopLeft != null) {
        d.from = d.to = _dragTopLeft!;
        d.placed = true;
        continue;
      }
      final target = targets[d.id] ?? Offset.zero;
      if (!d.placed) {
        d.from = d.to = target;
        d.placed = true;
      } else if (target != d.to) {
        d.from = _shown(d);
        d.to = target;
        retargeted = true;
      }
    }
    if (retargeted) {
      _t = 0;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) _glide.forward(from: 0);
      });
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (var c = firstChild; c != null; c = childAfter(c)) {
      final d = c.parentData! as _FlowParentData;
      context.paintChild(c, offset + _shown(d));
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (var c = lastChild; c != null; c = childBefore(c)) {
      final d = c.parentData! as _FlowParentData;
      final hit = result.addWithPaintOffset(
        offset: _shown(d),
        position: position,
        hitTest: (result, transformed) =>
            c!.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final d = child.parentData! as _FlowParentData;
    final o = _shown(d);
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      Size(constraints.maxWidth, 0);
}
