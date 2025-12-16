import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MediaGrid extends StatelessWidget {
  final List<dynamic> items;
  final void Function(Map<String, dynamic>) onTap;

  const MediaGrid({
    super.key,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index] as Map<String, dynamic>;
        return MediaCard(
          item: item,
          onTap: () => onTap(item),
        );
      },
    );
  }
}

class MediaCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const MediaCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String? ?? 'Unknown';
    final year = item['year'] as String? ?? '';
    final rating = item['rating'] as String? ?? '';
    final posterUrl = item['posterUrl'] as String?;
    final mediaType = item['mediaType'] as String? ?? 'movie';
    final watched = item['watched'] as bool? ?? false;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster image
            if (posterUrl != null)
              CachedNetworkImage(
                imageUrl: posterUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.movie, size: 48),
                ),
              )
            else
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.movie, size: 48),
              ),
            // Gradient overlay at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (year.isNotEmpty) ...[
                          Text(
                            year,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (rating.isNotEmpty) ...[
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            rating,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Media type badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: mediaType == 'tv' ? Colors.blue : Colors.purple,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  mediaType == 'tv' ? 'TV' : 'MOVIE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Watched badge
            if (watched)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
