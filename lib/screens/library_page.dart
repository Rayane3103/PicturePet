import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class LibraryPage extends StatelessWidget {
  final void Function()? onNewProject;
  final void Function(String imageAsset)? onOpenProject;

  const LibraryPage({
    super.key,
    this.onNewProject,
    this.onOpenProject,
  });

  @override
  Widget build(BuildContext context) {
    // Updated image URLs with more reliable sources
    final examples = [
      'https://picsum.photos/400/300?random=1',
      'https://picsum.photos/400/300?random=4',
      'https://picsum.photos/400/300?random=5',
      'https://picsum.photos/400/300?random=2',
      'https://picsum.photos/400/300?random=3',
    ];

    return CustomScrollView(
      slivers: [
        // MediaPet-style header with credits and subscription
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title section
                Text(
                  'Projects Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onBackground(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your projects and track your progress',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.secondaryText(context),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Credits and subscription section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Credits badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.muted(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco,
                            color: AppColors.successGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '9,625 Credits available',
                            style: GoogleFonts.inter(
                              color: AppColors.onBackground(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.muted(context),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        '+ Buy Credits',
                        style: GoogleFonts.inter(
                          color: AppColors.secondaryText(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Create New Project button - Full width at the top
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
              ),
              child: InkWell(
                onTap: onNewProject,
                borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Project',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Projects grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            itemBuilder: (context, index) {
              // Dynamic project cards with MediaPet styling
              final projectIndex = index;
              final imageIndex = projectIndex % examples.length;
              final imageUrl = examples[imageIndex];
              
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onOpenProject?.call(imageUrl),
                  borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
                  child: Container(
                    height: 300, // Fixed height to avoid unbounded constraints
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
                    ),
                    child: Stack(
                      children: [
                        // Project image - full height with improved loading
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: AppColors.muted(context),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.primaryPurple,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Loading...',
                                          style: GoogleFonts.inter(
                                            color: AppColors.secondaryText(context),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppColors.muted(context),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image_outlined,
                                        color: AppColors.textMuted,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Image failed to load',
                                        style: GoogleFonts.inter(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        
                        // Project info overlay at the bottom
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Project title
                                Text(
                                  'Project ${imageIndex + 1}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                
                                const SizedBox(height: 4),
                                
                                // Last modified date
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      color: Colors.white70,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Modified ${(imageIndex % 3) + 1}d ago',
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Bottom spacing
        const SliverToBoxAdapter(
          child: SizedBox(height: 32),
        ),
      ],
    );
  }
}