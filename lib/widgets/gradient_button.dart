import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  final double radius;
  final bool isOutlined;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.radius = AppTheme.cornerRadius,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.inter(
      color: isOutlined ? AppColors.primaryPurple : Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );
    
    if (isOutlined) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.primaryPurple,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: AppColors.primaryPurple, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(label, style: textStyle),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [mediaPetShadow(context)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                ],
                Text(label, style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


