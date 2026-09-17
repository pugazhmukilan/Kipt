import 'package:flutter/material.dart';
import '../../data/models/item_with_details.dart';

/// The three-stat summary row shown at the top of the dashboard.
///
/// Equal status tiles with a shared label, icon, and count rhythm.
class DashboardStatsWidget extends StatelessWidget {
  final DashboardStats stats;

  const DashboardStatsWidget({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        _StatCard(
          label: 'Active',
          count: stats.active,
          chipColor: cs.primaryContainer,
          iconColor: cs.primary,
          icon: Icons.check_circle_rounded,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Expiring',
          count: stats.expiringSoon,
          chipColor: cs.tertiaryContainer,
          iconColor: cs.tertiary,
          icon: Icons.schedule_rounded,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Expired',
          count: stats.expired,
          chipColor: cs.errorContainer,
          iconColor: cs.error,
          icon: Icons.warning_amber_rounded,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color chipColor;
  final Color iconColor;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.count,
    required this.chipColor,
    required this.iconColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        height: 96,
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                height: 1.05,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
