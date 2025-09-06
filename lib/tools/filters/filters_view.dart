import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'filters_tool.dart';

class FiltersView extends StatelessWidget {
  final FiltersTool tool;
  final VoidCallback? onBack;
  final VoidCallback? onStateChanged;

  const FiltersView({
    super.key,
    required this.tool,
    this.onBack,
    this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          final filter = tool.filters[index];
          final isSelected = tool.selectedFilter == filter['name'];
          
                     return GestureDetector(
             onTap: () {
               tool.selectFilter(filter['name']);
               onStateChanged?.call();
             },
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 // Filter preview card
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
                     child: _buildFilterPreview(context, filter),
                   ),
                 ),
                 const SizedBox(height: 8),
                 // Filter name
                 Text(
                   filter['name'],
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
        itemCount: tool.filters.length,
      ),
    );
  }

  Widget _buildFilterPreview(BuildContext context, Map<String, dynamic> filter) {
    // Create a small preview of the image with the filter applied
    // Use a local asset image for consistent previews
    Widget previewImage = Image.asset(
      'assets/images/filter.png',
      fit: BoxFit.cover,
      width: 80,
      height: 80,
    );

    // Apply filter if it has a matrix
    if (filter['matrix'] != null) {
      previewImage = ColorFiltered(
        colorFilter: ColorFilter.matrix(filter['matrix']),
        child: previewImage,
      );
    }

    return previewImage;
  }
}
