import 'dart:async';
import 'package:flutter/material.dart';
import '../tokens/soft_metrics.dart';
import '../tokens/soft_tokens.dart';

/// 全局三通道反馈门面：
/// 1. 顶部悬浮轻量 TopToast（绝不压住阅读器进度滑块或悬浮底栏）
/// 2. 带可撤销动作的 DockedUndoBar（仅在需要交互撤销时贴合底栏上缘出现）
class AppFeedback {
  static OverlayEntry? _activeToast;
  static Timer? _toastTimer;

  static void showToast(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(milliseconds: 2100),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _toastTimer?.cancel();
    _activeToast?.remove();
    _activeToast = null;

    final tokens = SoftTokens.of(context);
    final topPad = MediaQuery.paddingOf(context).top;

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: topPad + 64.0,
        left: 24.0,
        right: 24.0,
        child: IgnorePointer(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                decoration: BoxDecoration(
                  color: isError ? tokens.danger : tokens.card,
                  borderRadius: BorderRadius.circular(SoftRadius.pill),
                  border: Border.all(
                    color: isError ? tokens.danger : tokens.borderSubtle,
                    width: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.shadowColor,
                      blurRadius: 16.0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16.0,
                      color: isError ? tokens.onDanger : tokens.accent,
                    ),
                    const SizedBox(width: 8.0),
                    Flexible(
                      child: Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SoftTypography.caption.copyWith(
                          color: isError ? tokens.onDanger : tokens.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    _activeToast = entry;
    _toastTimer = Timer(duration, () {
      _activeToast?.remove();
      _activeToast = null;
    });
  }

  /// 主屏底栏上方撤销条（真延迟销毁触发器）
  static void showUndoSnackBar(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    required VoidCallback onCommitted,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      onCommitted();
      return;
    }
    final tokens = SoftTokens.of(context);
    var undone = false;

    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: duration,
        persist: false,
        dismissDirection: DismissDirection.horizontal,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          18.0,
          0,
          18.0,
          SoftSpacing.dockClearance - 8.0,
        ),
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoftRadius.subCard),
          side: BorderSide(color: tokens.borderSubtle, width: 0.9),
        ),
        content: Text(
          message,
          style: SoftTypography.body.copyWith(color: tokens.textPrimary),
        ),
        action: SnackBarAction(
          label: '撤销',
          textColor: tokens.accent,
          onPressed: () {
            undone = true;
            onUndo();
          },
        ),
      ),
    );

    controller.closed.then((_) {
      if (!undone) {
        onCommitted();
      }
    });
  }

  /// 离开书架或切换标签页时即时收起撤销条，防止跨页遮挡并立即触发待提交清理
  static void dismissSnackBar(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  }
}
