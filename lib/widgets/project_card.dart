import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProjectCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageAsset;
  final VoidCallback? onTap;
  final bool isNew;

  const ProjectCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    this.onTap,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
        //boxShadow: [softShadow(context)],
      ),
      clipBehavior: Clip.antiAlias,
      child: isNew ? _buildNew(context) : _buildExisting(context),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
      child: card,
    );
  }

  Widget _buildExisting(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: imageAsset.startsWith('http')
              ? Image.network(imageAsset, fit: BoxFit.cover)
              : Image.asset(imageAsset, fit: BoxFit.cover),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNew(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 10),
              const Text(
                'New Project',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}


