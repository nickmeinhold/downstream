import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class TorrentSearchDialog extends StatefulWidget {
  final String initialQuery;
  final String? category;

  const TorrentSearchDialog({
    super.key,
    required this.initialQuery,
    this.category,
  });

  @override
  State<TorrentSearchDialog> createState() => _TorrentSearchDialogState();
}

class _TorrentSearchDialogState extends State<TorrentSearchDialog> {
  late TextEditingController _searchController;
  List<dynamic> _results = [];
  bool _isLoading = false;
  String? _error;
  int? _downloadingIndex;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final results = await api.searchTorrents(
        _searchController.text,
        category: widget.category,
      );

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _download(int index) async {
    final result = _results[index] as Map<String, dynamic>;
    final url = result['magnetUri'] ?? result['link'];

    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No download URL available')),
      );
      return;
    }

    setState(() => _downloadingIndex = index);

    try {
      final api = context.read<ApiService>();
      await api.downloadTorrent(url as String);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download started!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadingIndex = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Search Torrents',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isLoading ? null : _search,
                    child: const Text('Search'),
                  ),
                ],
              ),
            ),
            // Results
            Expanded(
              child: _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _search,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text('No results found'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index] as Map<String, dynamic>;
        final title = result['title'] as String? ?? 'Unknown';
        final size = result['sizeText'] as String? ?? '';
        final seeders = result['seeders'] as int? ?? 0;
        final peers = result['peers'] as int? ?? 0;
        final indexer = result['indexer'] as String? ?? '';

        return ListTile(
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              if (size.isNotEmpty) ...[
                const Icon(Icons.storage, size: 14),
                const SizedBox(width: 4),
                Text(size),
                const SizedBox(width: 16),
              ],
              Icon(
                Icons.arrow_upward,
                size: 14,
                color: seeders > 10 ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text('$seeders'),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_downward, size: 14),
              const SizedBox(width: 4),
              Text('$peers'),
              if (indexer.isNotEmpty) ...[
                const Spacer(),
                Text(
                  indexer,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          trailing: _downloadingIndex == index
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _download(index),
                ),
        );
      },
    );
  }
}
