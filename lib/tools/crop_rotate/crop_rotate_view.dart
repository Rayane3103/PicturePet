import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'crop_rotate_tool.dart';

class CropRotateView extends StatelessWidget {
  final CropRotateTool tool;
  final VoidCallback onBack;
  final VoidCallback onApply;
  final VoidCallback onStateChanged;

  const CropRotateView({
    super.key,
    required this.tool,
    required this.onBack,
    required this.onApply,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Aspect ratio presets
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemBuilder: (context, index) {
              final aspectRatio = tool.aspectRatios[index];
              final isSelected = tool.selectedAspectRatio == aspectRatio['name'];
              
              return GestureDetector(
                onTap: () {
                  tool.selectedAspectRatio = aspectRatio['name'];
                  tool.updateCropAreaForAspectRatio(aspectRatio['ratio']);
                  onStateChanged(); // Trigger state update in parent
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? AppColors.primaryPurple.withOpacity(0.2)
                      : AppColors.muted(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                        ? AppColors.primaryPurple
                        : AppColors.muted(context).withOpacity(0.5),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      aspectRatio['name'],
                      style: GoogleFonts.inter(
                        color: isSelected 
                          ? AppColors.primaryPurple
                          : AppColors.onBackground(context),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: tool.aspectRatios.length,
          ),
        ),
        const SizedBox(height: 16),
        
        // Rotation controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildRotationButton(
              context: context,
              icon: Icons.rotate_left_rounded,
              onTap: () {
                tool.rotateLeft90();
                onStateChanged();
              },
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.muted(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${tool.getCurrentRotation().round()}°',
                style: GoogleFonts.inter(
                  color: AppColors.onBackground(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            _buildRotationButton(
              context: context,
              icon: Icons.rotate_right_rounded,
              onTap: () {
                tool.rotateRight90();
                onStateChanged();
              },
            ),
          ],
        ),

        const SizedBox(height: 12),
        // Continuous rotation slider
        Row(
          children: [
            Expanded(
              child: Slider(
                min: -45,
                max: 45,
                value: _clampAngle(tool.getCurrentRotation(), -45, 45),
                onChanged: (v) {
                  tool.setRotationDegrees(v);
                  onStateChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            Text('${_clampAngle(tool.getCurrentRotation(), -45, 45).toStringAsFixed(0)}°',
              style: GoogleFonts.inter(
                color: AppColors.onBackground(context),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),
        // Grid toggle and reset
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSmallButton(
              context: context,
              icon: tool.isGridVisible ? Icons.grid_on_rounded : Icons.grid_off_rounded,
              label: tool.isGridVisible ? 'Grid On' : 'Grid Off',
              onTap: () {
                tool.toggleGrid();
                onStateChanged();
              },
            ),
            _buildSmallButton(
              context: context,
              icon: Icons.restore_rounded,
              label: 'Reset',
              onTap: () {
                tool.reset();
                onStateChanged();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRotationButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.muted(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.muted(context).withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: AppColors.onBackground(context),
          size: 20,
        ),
      ),
    );
  }

  double _clampAngle(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  Widget _buildSmallButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.muted(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.muted(context).withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.onBackground(context), size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.onBackground(context),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
