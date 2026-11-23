import 'package:flutter/material.dart';
import '../tokens/soft_metrics.dart';
import '../tokens/soft_tokens.dart';

/// 柔和填充输入框（无硬黑粗线框，实时响应清空按钮显示）
class SoftTextField extends StatelessWidget {
  const SoftTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon = Icons.search_rounded,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.onCleared,
    this.trailing,
    this.maxLines = 1,
    this.radius = SoftRadius.pill,
    this.textInputAction = TextInputAction.search,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCleared;
  final Widget? trailing;
  final int maxLines;
  final double radius;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tokens.borderSubtle, width: 0.8),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 14.0,
        vertical: maxLines > 1 ? 10.0 : 2.0,
      ),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (prefixIcon != null) ...[
            Padding(
              padding: EdgeInsets.only(top: maxLines > 1 ? 4.0 : 0.0),
              child: Icon(
                prefixIcon,
                size: 18.0,
                color: tokens.textTertiary,
              ),
            ),
            const SizedBox(width: 8.0),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: maxLines,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              style: SoftTypography.body.copyWith(color: tokens.textPrimary),
              cursorColor: tokens.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle:
                    SoftTypography.body.copyWith(color: tokens.textTertiary),
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, val, _) {
              if (val.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '清空',
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');
                  onCleared?.call();
                },
                icon: Icon(
                  Icons.cancel_rounded,
                  size: 18.0,
                  color: tokens.textTertiary,
                ),
              );
            },
          ),
          ?trailing,
        ],
      ),
    );
  }
}
