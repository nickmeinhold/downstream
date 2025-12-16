import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class TorrentSearchDialog extends StatefulWidget {
  final String initialQuery;
  final String? category;
  final String? expectedYear;

  const TorrentSearchDialog({
    super.key,
    required this.initialQuery,
    this.category,
    this.expectedYear,
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
  Set<String> _detectedYears = {};
  String? _selectedYear;

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

  // Extract year from torrent title (looks for 4-digit year patterns like 2023, 2024)
  String? _extractYear(String title) {
    final yearMatch = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(title);
    return yearMatch?.group(1);
  }

  Future<void> _search() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _selectedYear = null;
      _detectedYears = {};
    });

    try {
      final api = context.read<ApiService>();
      final results = await api.searchTorrents(
        _searchController.text,
        category: widget.category,
      );

      // Detect years in results
      final years = <String>{};
      for (final result in results) {
        final title = result['title'] as String? ?? '';
        final year = _extractYear(title);
        if (year != null) {
          years.add(year);
        }
      }

      if (mounted) {
        setState(() {
          _results = results;
          _detectedYears = years;
          _isLoading = false;
          // Auto-select expected year if multiple years detected
          if (years.length > 1 && widget.expectedYear != null && years.contains(widget.expectedYear)) {
            _selectedYear = widget.expectedYear;
          }
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

  Future<void> _download(Map<String, dynamic> result) async {
    final url = result['magnetUri'] ?? result['link'];

    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No download URL available')),
      );
      return;
    }

    // Find the index in original results for loading indicator
    final index = _results.indexOf(result);
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
            // Year filter (shown when multiple years detected)
            if (_detectedYears.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Multiple versions found - select year:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _selectedYear == null,
                          onSelected: (_) => setState(() => _selectedYear = null),
                        ),
                        ...(_detectedYears.toList()..sort((a, b) => b.compareTo(a)))
                            .map((year) => FilterChip(
                                  label: Text(year),
                                  selected: _selectedYear == year,
                                  onSelected: (_) => setState(() => _selectedYear = year),
                                )),
                      ],
                    ),
                    const SizedBox(height: 8),
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

    // Filter results by selected year
    final filteredResults = _selectedYear == null
        ? _results
        : _results.where((result) {
            final title = result['title'] as String? ?? '';
            final year = _extractYear(title);
            return year == _selectedYear;
          }).toList();

    if (filteredResults.isEmpty) {
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
            Text(_results.isEmpty ? 'No results found' : 'No results for $_selectedYear'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final result = filteredResults[index] as Map<String, dynamic>;
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
          trailing: _downloadingIndex == _results.indexOf(result)
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _download(result),
                ),
        );
      },
    );
  }
}
