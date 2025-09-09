import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../repositories/media_repository.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';

class MediaHistoryPage extends StatefulWidget {
  const MediaHistoryPage({super.key});

  @override
  State<MediaHistoryPage> createState() => _MediaHistoryPageState();
}

class _MediaHistoryPageState extends State<MediaHistoryPage> {
  final MediaRepository _repo = MediaRepository();
  final ScrollController _controller = ScrollController();

  final List<MediaItem> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _controller.addListener(() {
      if (_controller.position.pixels > _controller.position.maxScrollExtent - 300 && !_isLoading && _hasMore) {
        _loadMore();
      }
    });
  }

  Future<void> _loadMore() async {
    setState(() => _isLoading = true);
    try {
      final page = await _repo.listMedia(limit: _limit, offset: _offset);
      setState(() {
        _items.addAll(page);
        _offset += page.length;
        _hasMore = page.length == _limit;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Media')),
      backgroundColor: AppColors.background(context),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _items.clear();
            _offset = 0;
            _hasMore = true;
          });
          await _loadMore();
        },
        child: ListView.builder(
          controller: _controller,
          itemCount: _items.length + (_isLoading ? 3 : 0),
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              return _skeletonItem(context);
            }
            final item = _items[index];
            return ListTile(
              leading: item.thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.thumbnailUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 56,
                            height: 56,
                            color: AppColors.muted(context),
                            child: Icon(
                              Icons.wifi_off_rounded,
                              color: AppColors.secondaryText(context),
                              size: 20,
                            ),
                          );
                        },
                      ),
                    )
                  : const Icon(Icons.image, size: 32),
              title: Text(
                item.mimeType,
                style: GoogleFonts.inter(color: AppColors.onBackground(context), fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                item.createdAt.toLocal().toString(),
                style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            );
          },
        ),
      ),
    );
  }

  Widget _skeletonItem(BuildContext context) {
    return ListTile(
      leading: Container(width: 56, height: 56, color: AppColors.muted(context),),
      title: Container(height: 14, color: AppColors.muted(context)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Container(height: 10, color: AppColors.muted(context)),
      ),
    );
  }
}


