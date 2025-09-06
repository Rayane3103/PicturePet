import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_theme.dart';

// Redesigned AI tool presentation: compact pill for horizontal list,
// and a wide glass card alternative for vertical contexts.
class AIToolCard extends StatelessWidget {
  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool compact;

  const AIToolCard({
    super.key,
    required this.id,
    required this.icon,
    required this.label,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return compact
        ? _CompactPill(icon: icon, label: label, onTap: onTap)
        : _WideCard(icon: icon, label: label, id: id, onTap: onTap);
  }
}

class _CompactPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _CompactPill({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(14);
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.2),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 110,
                  maxWidth: 170,
                  minHeight: 32,
                  maxHeight: 36,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: Colors.black.withOpacity(0.25),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: Colors.white70, size: 14),
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

class _WideCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String id;
  final VoidCallback? onTap;

  const _WideCard({required this.icon, required this.label, required this.id, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
          boxShadow: [softShadow(context)],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: Theme.of(context).hintColor)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

