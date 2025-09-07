import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'ai_styles_tool.dart';

class AIStylesView extends StatelessWidget {
  final AIStylesTool tool;
  final VoidCallback? onBack;
  final VoidCallback? onStateChanged;

  const AIStylesView({super.key, required this.tool, this.onBack, this.onStateChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          final style = tool.styles[index];
          final isSelected = tool.selectedStyle == style['name'];

          return GestureDetector(
            onTap: () {
              tool.selectStyle(style['name']);
              onStateChanged?.call();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryPurple
                          : AppColors.muted(context).withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _buildStylePreview(context, style),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  style['name'],
                  style: GoogleFonts.inter(
                    color: isSelected
                        ? AppColors.primaryPurple
                        : AppColors.onBackground(context),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: tool.styles.length,
      ),
    );
  }

  Widget _buildStylePreview(BuildContext context, Map<String, dynamic> style) {
    return Image.asset(
      'assets/images/filter.png',
      fit: BoxFit.cover,
      width: 80,
      height: 80,
    );
  }
}


