import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ReframeSelection {
  final int width;
  final int height;
  final String? label;
  ReframeSelection({required this.width, required this.height, this.label});
}

class ReframePreset {
  final String label;
  final String subtitle;
  final int width;
  final int height;
  const ReframePreset({required this.label, required this.subtitle, required this.width, required this.height});
}

class ReframePresetCard extends StatelessWidget {
  final ReframePreset preset;
  final bool selected;
  final VoidCallback onTap;
  const ReframePresetCard({super.key, required this.preset, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color border = (selected ? AppColors.primaryPurple : AppColors.muted(context).withOpacity(0.25));
    final Color bg = selected ? AppColors.primaryPurple.withOpacity(0.12) : AppColors.card(context);
    final Color onBg = AppColors.onBackground(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 156,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(preset.label, style: GoogleFonts.inter(color: onBg, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(preset.subtitle, style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.muted(context).withOpacity(0.25), width: 1),
              ),
              child: Text(
                '${preset.width} × ${preset.height}',
                style: GoogleFonts.inter(color: onBg, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


