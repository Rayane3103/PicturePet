import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'add_text_tool.dart';

class AddTextView extends StatelessWidget {
  final AddTextTool tool;
  final VoidCallback onApply;
  final VoidCallback onBack;
  final VoidCallback onChanged;

  const AddTextView({super.key, required this.tool, required this.onApply, required this.onBack, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _backButton(context),
            const SizedBox(width: 12),
            Text(
              'Add Text',
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
        TextField(
          decoration: const InputDecoration(hintText: 'Enter text...'),
          onChanged: (v) { tool.text = v; onChanged(); },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                min: 8,
                max: 96,
                value: tool.fontSize.toDouble(),
                onChanged: (v) { tool.fontSize = v.round(); onChanged(); },
              ),
            ),
            SizedBox(width: 60, child: Text('${tool.fontSize}', style: GoogleFonts.inter(color: AppColors.onBackground(context)))),
          ],
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
}


