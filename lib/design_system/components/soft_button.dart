import 'package:flutter/material.dart';
import '../tokens/soft_metrics.dart';
import '../tokens/soft_tokens.dart';

enum SoftButtonTone { primary, tonal, ghost, danger }

/// 统一软拟态按钮：自动适配 WCAG onAccent / onDanger、保证 44dp 触控热区、带明确禁用态
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = SoftButtonTone.primary,
    this.compact = false,
    this.expand = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SoftButtonTone tone;
  final bool compact;
  final bool expand;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final disabled = onPressed == null || isLoading;

    final Color bg;
    final Color fg;
    final BorderSide side;

    switch (tone) {
      case SoftButtonTone.primary:
        bg = tokens.accent;
        fg = tokens.onAccent;
        side = BorderSide.none;
      case SoftButtonTone.tonal:
        bg = tokens.surface;
        fg = tokens.textPrimary;
        side = BorderSide(color: tokens.borderSubtle, width: 0.8);
      case SoftButtonTone.ghost:
        bg = Colors.transparent;
        fg = tokens.textSecondary;
        side = BorderSide.none;
      case SoftButtonTone.danger:
        bg = tokens.danger;
        fg = tokens.onDanger;
        side = BorderSide.none;
    }

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SoftRadius.pill),
      side: side,
    );

    final minHeight = compact ? 38.0 : 46.0;
    final hPad = compact ? 14.0 : 20.0;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: Opacity(
        opacity: disabled ? 0.52 : 1.0,
        child: Material(
          color: bg,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: disabled ? null : onPressed,
            customBorder: shape,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minHeight,
                minWidth: expand ? double.infinity : 44.0,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8.0),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading) ...[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(fg),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else if (icon != null) ...[
                      Icon(icon, size: compact ? 15 : 17, color: fg),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 12.5 : 13.5,
                        fontWeight: FontWeight.w700,
                        color: fg,
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
  }
}
