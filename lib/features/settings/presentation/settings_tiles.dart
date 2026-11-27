import 'package:flutter/material.dart';
import '../../../design_system/components/soft_switch.dart';
import '../../../design_system/tokens/soft_metrics.dart';
import '../../../design_system/tokens/soft_tokens.dart';

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: SoftTypography.sectionTitle.copyWith(color: tokens.textPrimary),
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, size: 20.0, color: tokens.textSecondary),
          const SizedBox(width: SoftSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SoftTypography.body.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: SoftTypography.micro
                      .copyWith(color: tokens.textTertiary),
                ),
              ],
            ),
          ),
          SoftSwitch(
            value: value,
            onChanged: onChanged,
            semanticLabel: title,
          ),
        ],
      ),
    );
  }
}

class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDanger = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDanger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = SoftTokens.of(context);
    final fg = isDanger ? tokens.danger : tokens.textPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(SoftRadius.control),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20.0,
              color: isDanger ? tokens.danger : tokens.textSecondary,
            ),
            const SizedBox(width: SoftSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SoftTypography.body.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: SoftTypography.micro
                        .copyWith(color: tokens.textTertiary),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: SoftSpacing.sm),
              trailing!,
            ],
            Icon(Icons.chevron_right_rounded, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}
