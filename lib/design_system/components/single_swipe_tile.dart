import 'package:flutter/material.dart';
import '../tokens/soft_metrics.dart';
import '../tokens/soft_tokens.dart';

/// 全局左滑互斥控制器：同一时刻仅允许展开一张卡片，切 Tab/后台时可一键复位
class SwipeCoordinator extends ChangeNotifier {
  String? _activeItemId;

  String? get activeItemId => _activeItemId;

  void open(String itemId) {
    if (_activeItemId == itemId) return;
    _activeItemId = itemId;
    notifyListeners();
  }

  void closeAll() {
    if (_activeItemId == null) return;
    _activeItemId = null;
    notifyListeners();
  }
}

/// 单向左滑露底操作卡片（杜绝右滑穿帮、杜绝取消/切页后卡死在半开态）
class SingleSwipeTile extends StatefulWidget {
  const SingleSwipeTile({
    super.key,
    required this.itemId,
    required this.coordinator,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.child,
    this.actionWidth = 84.0,
  });

  final String itemId;
  final SwipeCoordinator coordinator;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final Widget child;
  final double actionWidth;

  @override
  State<SingleSwipeTile> createState() => _SingleSwipeTileState();
}

class _SingleSwipeTileState extends State<SingleSwipeTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _dragExtent = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        setState(() {
          _dragExtent = -_ctrl.value * widget.actionWidth;
        });
      });
    widget.coordinator.addListener(_onCoordinatorChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled &&
        (_ctrl.isAnimating || _ctrl.value != 0.0 || _dragExtent != 0.0)) {
      _ctrl.stop();
      _ctrl.value = 0.0;
      _dragExtent = 0.0;
    }
  }

  @override
  void didUpdateWidget(covariant SingleSwipeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator) {
      oldWidget.coordinator.removeListener(_onCoordinatorChanged);
      widget.coordinator.addListener(_onCoordinatorChanged);
    }
    if (oldWidget.itemId != widget.itemId && _dragExtent != 0.0) {
      _snapTo(false);
    }
  }

  void _onCoordinatorChanged() {
    if (widget.coordinator.activeItemId != widget.itemId &&
        _dragExtent < -0.5) {
      _snapTo(false);
    }
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_onCoordinatorChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _snapTo(bool open) {
    if (open) {
      widget.coordinator.open(widget.itemId);
      _ctrl.animateTo(1.0, curve: Curves.easeOutCubic);
      return;
    }
    // 离屏分支 TickerMode 冻结时直接瞬间归零，杜绝切 Tab 后切回闪现动画残影
    if (!TickerMode.valuesOf(context).enabled) {
      _ctrl.stop();
      _ctrl.value = 0.0;
      if (mounted && _dragExtent != 0.0) {
        setState(() => _dragExtent = 0.0);
      } else {
        _dragExtent = 0.0;
      }
      return;
    }
    _ctrl.animateTo(0.0, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final openProgress =
        (-_dragExtent / widget.actionWidth).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(SoftRadius.card),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          if (openProgress > 0.02)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Opacity(
                  opacity: openProgress,
                  child: GestureDetector(
                    onTap: () {
                      widget.coordinator.closeAll();
                      widget.onAction();
                    },
                    child: Container(
                      width: widget.actionWidth - 4.0,
                      margin: const EdgeInsets.only(left: 8.0),
                      decoration: BoxDecoration(
                        color: tokens.danger,
                        borderRadius: BorderRadius.circular(SoftRadius.card),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.actionIcon,
                            color: tokens.onDanger,
                            size: 20.0,
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            widget.actionLabel,
                            style: SoftTypography.micro
                                .copyWith(color: tokens.onDanger),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragExtent, 0.0),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) {
                widget.coordinator.open(widget.itemId);
              },
              onHorizontalDragUpdate: (details) {
                final next = (_dragExtent + details.delta.dx)
                    .clamp(-widget.actionWidth, 0.0);
                setState(() {
                  _dragExtent = next;
                  _ctrl.value = (-next / widget.actionWidth).clamp(0.0, 1.0);
                });
              },
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0.0;
                final shouldOpen =
                    v < -250 || -_dragExtent > widget.actionWidth * 0.45;
                _snapTo(shouldOpen);
              },
              onHorizontalDragCancel: () => _snapTo(false),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
