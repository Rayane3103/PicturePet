import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'adjust_tool.dart';

class AdjustView extends StatelessWidget {
  final AdjustTool tool;
  final VoidCallback onApply;
  final VoidCallback onBack;
  final VoidCallback onChanged;

  const AdjustView({super.key, required this.tool, required this.onApply, required this.onBack, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _backButton(context),
            const SizedBox(width: 12),
            Text(
              'Adjust',
              style: GoogleFonts.inter(
                color: AppColors.onBackground(context),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            _applyButton(context),
          ],
        ),
        const SizedBox(height: 12),
        _slider(
          context: context,
          label: 'Brightness',
          min: -1,
          max: 1,
          value: tool.brightness,
          onChanged: (v) {
            tool.brightness = v;
            onChanged();
          },
        ),
        _slider(
          context: context,
          label: 'Contrast',
          min: 0,
          max: 2,
          value: tool.contrast,
          onChanged: (v) {
            tool.contrast = v;
            onChanged();
          },
        ),
        _slider(
          context: context,
          label: 'Saturation',
          min: 0,
          max: 2,
          value: tool.saturation,
          onChanged: (v) {
            tool.saturation = v;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _smallButton(
              context: context,
              icon: Icons.restore_rounded,
              label: 'Reset',
              onTap: () {
                tool.reset();
                onChanged();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _slider({
    required BuildContext context,
    required String label,
    required double min,
    required double max,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: GoogleFonts.inter(color: AppColors.onBackground(context), fontWeight: FontWeight.w600, fontSize: 12))),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _applyButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
        onPressed: onApply,
      ),
    );
  }

  Widget _backButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.muted(context).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.onBackground(context), size: 20),
        onPressed: onBack,
      ),
    );
  }

  Widget _smallButton({required BuildContext context, required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.muted(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.muted(context).withOpacity(0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.onBackground(context), size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(color: AppColors.onBackground(context), fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}


