import 'package:flutter/material.dart';
import '../tokens/soft_metrics.dart';
import '../tokens/soft_tokens.dart';

/// 全站统一底部抽屉容器（28dp 圆角、拖拽条、44dp 关闭钮、自适应安全区）
class SoftBottomSheet extends StatelessWidget {
  const SoftBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.headerIcon,
    this.headerAction,
    this.maxHeightFactor = 0.85,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final IconData? headerIcon;
  final Widget? headerAction;
  final double maxHeightFactor;
  final Widget child;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData? headerIcon,
    Widget? headerAction,
    double maxHeightFactor = 0.85,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SoftBottomSheet(
        title: title,
        subtitle: subtitle,
        headerIcon: headerIcon,
        headerAction: headerAction,
        maxHeightFactor: maxHeightFactor,
        child: builder(sheetContext),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final media = MediaQuery.of(context);
    final usableH =
        (media.size.height - media.viewInsets.bottom).clamp(0.0, media.size.height);
    final safeUpper = (usableH - media.padding.top).clamp(0.0, usableH);
    final minFloor = safeUpper < 180.0 ? safeUpper : 180.0;
    final maxH = (usableH * maxHeightFactor).clamp(minFloor, safeUpper);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH, maxWidth: 560.0),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SoftRadius.sheet),
              ),
              border: Border.all(color: tokens.borderSubtle, width: 0.8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10.0),
                Container(
                  width: 38.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: tokens.textTertiary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999.0),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SoftSpacing.xl,
                    SoftSpacing.md,
                    SoftSpacing.md,
                    SoftSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      if (headerIcon != null) ...[
                        Container(
                          width: 36.0,
                          height: 36.0,
                          decoration: BoxDecoration(
                            color: tokens.accentSoft,
                            borderRadius: BorderRadius.circular(11.0),
                          ),
                          child: Icon(
                            headerIcon,
                            size: 18.0,
                            color: tokens.accent,
                          ),
                        ),
                        const SizedBox(width: 12.0),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SoftTypography.sectionTitle
                                  .copyWith(color: tokens.textPrimary),
                            ),
                            if (subtitle != null && subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 2.0),
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SoftTypography.caption
                                    .copyWith(color: tokens.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ?headerAction,
                      IconButton(
                        tooltip: '关闭',
                        constraints: const BoxConstraints(
                          minWidth: 44.0,
                          minHeight: 44.0,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20.0,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1.0, thickness: 0.8, color: tokens.borderSubtle),
                Flexible(
                  child: SafeArea(
                    top: false,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
