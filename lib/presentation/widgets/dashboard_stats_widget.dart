import 'package:flutter/material.dart';
import '../../data/models/item_with_details.dart';

/// The three-stat summary row shown at the top of the dashboard.
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
          color: cs.primaryContainer,
          countColor: cs.onPrimaryContainer,
          icon: Icons.check_circle_rounded,
          iconColor: cs.primary,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Expiring',
          count: stats.expiringSoon,
          color: cs.tertiaryContainer,
          countColor: cs.onTertiaryContainer,
          icon: Icons.schedule_rounded,
          iconColor: cs.tertiary,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Expired',
          count: stats.expired,
          color: cs.errorContainer,
          countColor: cs.onErrorContainer,
          icon: Icons.warning_amber_rounded,
          iconColor: cs.error,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color countColor;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.countColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: countColor,
                height: 1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: countColor.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}