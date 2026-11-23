import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/soft_tokens.dart';

/// 清晰直觉的现代开关：开启态采用实心强调色轨道 + 纯白浮球（绝不灰白混淆）
class SoftSwitch extends StatelessWidget {
  const SoftSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final enabled = onChanged != null;

    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 48.0,
              height: 28.0,
              padding: const EdgeInsets.all(3.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999.0),
                color: value
                    ? tokens.accent
                    : (tokens.isDark
                        ? Color.alphaBlend(
                            Colors.white.withValues(alpha: 0.14),
                            tokens.surface,
                          )
                        : tokens.textTertiary.withValues(alpha: 0.28)),
                border: Border.all(
                  color: value
                      ? tokens.accent
                      : (tokens.isDark
                          ? Colors.white.withValues(alpha: 0.22)
                          : tokens.borderSubtle),
                  width: 0.8,
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22.0,
                  height: 22.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value
                        ? tokens.onAccent
                        : (tokens.isDark
                            ? const Color(0xFFDCE2DF)
                            : tokens.card),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x28000000),
                        blurRadius: 4.0,
                        offset: Offset(0, 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
