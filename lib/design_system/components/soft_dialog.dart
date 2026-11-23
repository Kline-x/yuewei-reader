import 'package:flutter/material.dart';
import '../tokens/soft_metrics.dart';
import '../tokens/soft_tokens.dart';
import 'soft_button.dart';

/// 全站统一柔和确认弹窗（替代粗放原生 AlertDialog）
class SoftDialog {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = '确认',
    String cancelLabel = '取消',
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final tokens = SoftTokens.of(ctx);
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360.0),
            child: Container(
              padding: const EdgeInsets.all(SoftSpacing.xl),
              decoration: BoxDecoration(
                color: tokens.card,
                borderRadius: BorderRadius.circular(SoftRadius.card),
                border: Border.all(color: tokens.borderSubtle, width: 0.8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SoftTypography.sectionTitle
                        .copyWith(color: tokens.textPrimary),
                  ),
                  const SizedBox(height: SoftSpacing.sm),
                  Text(
                    message,
                    style: SoftTypography.body
                        .copyWith(color: tokens.textSecondary),
                  ),
                  const SizedBox(height: SoftSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: SoftButton(
                          label: cancelLabel,
                          tone: SoftButtonTone.tonal,
                          onPressed: () => Navigator.of(ctx).pop(false),
                        ),
                      ),
                      const SizedBox(width: SoftSpacing.md),
                      Expanded(
                        child: SoftButton(
                          label: confirmLabel,
                          tone: isDangerous
                              ? SoftButtonTone.danger
                              : SoftButtonTone.primary,
                          onPressed: () => Navigator.of(ctx).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return result ?? false;
  }
}
