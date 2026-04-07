import 'package:flutter/material.dart';

class SplitView extends StatefulWidget {
  final Widget leftChild;
  final Widget rightChild;
  final double initialDividerPos;
  final bool isVertical;

  const SplitView({
    required this.leftChild,
    required this.rightChild,
    this.initialDividerPos = 0.5,
    this.isVertical = false,
    super.key,
  });

  @override
  State<SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<SplitView> {
  late double _dividerPos;

  @override
  void initState() {
    super.initState();
    _dividerPos = widget.initialDividerPos;
  }

  @override
  Widget build(BuildContext context) {
    return widget.isVertical ? _buildVerticalSplit() : _buildHorizontalSplit();
  }

  Widget _buildHorizontalSplit() {
    final leftFlex = (_dividerPos * 100).round().clamp(1, 99);
    final rightFlex = 100 - leftFlex;

    return Row(
      children: [
        Flexible(flex: leftFlex, child: widget.leftChild),
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dividerPos =
                    (_dividerPos + details.delta.dx / context.size!.width)
                        .clamp(0.2, 0.8);
              });
            },
            child: Container(
              width: 10,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
        Flexible(flex: rightFlex, child: widget.rightChild),
      ],
    );
  }

  Widget _buildVerticalSplit() {
    final topFlex = (_dividerPos * 100).round().clamp(1, 99);
    final bottomFlex = 100 - topFlex;

    return Column(
      children: [
        Flexible(flex: topFlex, child: widget.leftChild),
        MouseRegion(
          cursor: SystemMouseCursors.resizeRow,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() {
                _dividerPos =
                    (_dividerPos + details.delta.dy / context.size!.height)
                        .clamp(0.2, 0.8);
              });
            },
            child: Container(
              height: 10,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
        Flexible(flex: bottomFlex, child: widget.rightChild),
      ],
    );
  }
}
