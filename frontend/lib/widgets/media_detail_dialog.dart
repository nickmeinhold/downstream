import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import 'torrent_search_dialog.dart';

class MediaDetailDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onWatchedChanged;

  const MediaDetailDialog({
    super.key,
    required this.item,
    required this.onWatchedChanged,
  });

  @override
  State<MediaDetailDialog> createState() => _MediaDetailDialogState();
}

class _MediaDetailDialogState extends State<MediaDetailDialog> {
  late bool _watched;
  bool _isUpdating = false;
  Map<String, dynamic>? _ratings;
  bool _loadingRatings = true;

  @override
  void initState() {
    super.initState();
    _watched = widget.item['watched'] as bool? ?? false;
    _fetchRatings();
  }

  Future<void> _fetchRatings() async {
    final api = context.read<ApiService>();
    final mediaType = widget.item['mediaType'] as String;
    final id = widget.item['id'] as int;

    final ratings = await api.getRatings(mediaType, id);
    if (mounted) {
      setState(() {
        _ratings = ratings;
        _loadingRatings = false;
      });
    }
  }

  Future<void> _toggleWatched() async {
    setState(() => _isUpdating = true);

    try {
      final api = context.read<ApiService>();
      final mediaType = widget.item['mediaType'] as String;
      final id = widget.item['id'] as int;

      if (_watched) {
        await api.unmarkWatched(mediaType, id);
      } else {
        await api.markWatched(mediaType, id);
      }

      setState(() {
        _watched = !_watched;
        _isUpdating = false;
      });
      widget.onWatchedChanged();
    } catch (e) {
      setState(() => _isUpdating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showTorrentSearch() {
    final title = widget.item['title'] as String;
    final year = widget.item['year'] as String? ?? '';
    final mediaType = widget.item['mediaType'] as String;

    Navigator.of(context).pop();

    // Search without year - dialog will detect ambiguous results and offer filtering
    showDialog(
      context: context,
      builder: (context) => TorrentSearchDialog(
        initialQuery: title,
        category: mediaType,
        expectedYear: year.isNotEmpty ? year : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item['title'] as String? ?? 'Unknown';
    final year = widget.item['year'] as String? ?? '';
    final tmdbRating = widget.item['rating'] as String? ?? '';
    final overview = widget.item['overview'] as String? ?? 'No description available.';
    final posterUrl = widget.item['posterUrl'] as String?;
    final mediaType = widget.item['mediaType'] as String? ?? 'movie';
    final providers = widget.item['providers'] as List<dynamic>? ?? [];

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with poster and info
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Poster
                  if (posterUrl != null)
                    AspectRatio(
                      aspectRatio: 2 / 3,
                      child: CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    AspectRatio(
                      aspectRatio: 2 / 3,
                      child: Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.movie, size: 48),
                      ),
                    ),
                  // Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: mediaType == 'tv'
                                      ? Colors.blue
                                      : Colors.purple,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  mediaType == 'tv' ? 'TV Show' : 'Movie',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (year.isNotEmpty)
                            Text(
                              year,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          const Spacer(),
                          if (providers.isNotEmpty)
                            Wrap(
                              spacing: 4,
                              children: providers
                                  .take(4)
                                  .map((p) => Chip(
                                        label: Text(
                                          p.toString(),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Ratings row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _buildRatingsRow(tmdbRating),
            ),
            const Divider(height: 1),
            // Overview
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(overview),
              ),
            ),
            const Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUpdating ? null : _toggleWatched,
                      icon: _isUpdating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_watched ? Icons.check_circle : Icons.circle_outlined),
                      label: Text(_watched ? 'Watched' : 'Mark as Watched'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _showTorrentSearch,
                      icon: const Icon(Icons.download),
                      label: const Text('Find Torrent'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsRow(String tmdbRating) {
    if (_loadingRatings) {
      return const Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final imdbRating = _ratings?['imdbRating'] as num?;
    final rottenTomatoes = _ratings?['rottenTomatoes'] as int?;
    final metacritic = _ratings?['metacritic'] as int?;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // TMDB
        _RatingBadge(
          label: 'TMDB',
          value: tmdbRating.isNotEmpty ? tmdbRating : null,
          icon: Icons.star,
          color: Colors.amber,
        ),
        // IMDB
        _RatingBadge(
          label: 'IMDB',
          value: imdbRating?.toStringAsFixed(1),
          icon: Icons.star,
          color: Colors.yellow.shade700,
        ),
        // Rotten Tomatoes
        _RatingBadge(
          label: 'RT',
          value: rottenTomatoes != null ? '$rottenTomatoes%' : null,
          icon: rottenTomatoes != null && rottenTomatoes >= 60
              ? Icons.thumb_up
              : Icons.thumb_down,
          color: rottenTomatoes != null && rottenTomatoes >= 60
              ? Colors.red
              : Colors.green.shade700,
        ),
        // Metacritic
        _RatingBadge(
          label: 'Meta',
          value: metacritic?.toString(),
          icon: Icons.square,
          color: _metacriticColor(metacritic),
        ),
      ],
    );
  }

  Color _metacriticColor(int? score) {
    if (score == null) return Colors.grey;
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.amber;
    return Colors.red;
  }
}

class _RatingBadge extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final Color color;

  const _RatingBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value ?? '-',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: value != null ? null : Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
