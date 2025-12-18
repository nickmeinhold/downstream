import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/media_grid.dart';
import '../widgets/media_detail_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _contentType = 'all'; // 'all', 'movie', 'tv'
  String _timeWindow = 'week'; // 'day', 'week'
  int _days = 30;
  double _minRating = 6.0; // Default: filter out low-rated content
  int _minVotes = 50; // Default: filter out obscure content
  int? _selectedGenre; // null = all genres
  List<dynamic> _items = [];
  bool _isLoading = false;
  String? _error;
  final _searchController = TextEditingController();

  // Common genres (shared between movies and TV)
  static const _genres = <int, String>{
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    27: 'Horror',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Sci-Fi',
    53: 'Thriller',
  };

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      List<dynamic> items;

      switch (_selectedIndex) {
        case 0: // New
          items = await api.getNewReleases(
            type: _contentType == 'all' ? null : _contentType,
            days: _days,
            minRating: _minRating,
            minVotes: _minVotes,
            genre: _selectedGenre,
          );
          break;
        case 1: // Trending
          items = await api.getTrending(
            window: _timeWindow,
            type: _contentType == 'all' ? null : _contentType,
          );
          break;
        case 2: // Search
          if (_searchController.text.isEmpty) {
            items = [];
          } else {
            items = await api.search(_searchController.text);
          }
          break;
        default:
          items = [];
      }

      if (mounted) {
        setState(() {
          _items = items;
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

  void _showMediaDetail(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) =>
          MediaDetailDialog(item: item, onWatchedChanged: () => _loadContent()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downstream'),
        actions: [
          PopupMenuButton<String>(
            icon: auth.photoUrl != null
                ? CircleAvatar(
                    backgroundImage: NetworkImage(auth.photoUrl!),
                    radius: 16,
                  )
                : const Icon(Icons.account_circle),
            tooltip: auth.username,
            onSelected: (value) {
              if (value == 'logout') {
                auth.logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Row(
                  children: [
                    if (auth.photoUrl != null) ...[
                      CircleAvatar(
                        backgroundImage: NetworkImage(auth.photoUrl!),
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(auth.username),
                          if (auth.email != null)
                            Text(
                              auth.email!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
              _loadContent();
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.new_releases_outlined),
                selectedIcon: Icon(Icons.new_releases),
                label: Text('New'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.trending_up_outlined),
                selectedIcon: Icon(Icons.trending_up),
                label: Text('Trending'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: Text('Search'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                _buildFilters(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_selectedIndex == 2) ...[
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search movies and TV shows...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadContent();
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) => _loadContent(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _loadContent, child: const Text('Search')),
          ] else ...[
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'movie', label: Text('Movies')),
                        ButtonSegment(value: 'tv', label: Text('TV Shows')),
                      ],
                      selected: {_contentType},
                      onSelectionChanged: (selection) {
                        setState(() => _contentType = selection.first);
                        _loadContent();
                      },
                    ),
                    const SizedBox(width: 16),
                    if (_selectedIndex == 0) ...[
                      DropdownButton<int>(
                        value: _days,
                        items: const [
                          DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                          DropdownMenuItem(value: 14, child: Text('Last 14 days')),
                          DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                          DropdownMenuItem(value: 90, child: Text('Last 90 days')),
                          DropdownMenuItem(value: 180, child: Text('Last 6 months')),
                          DropdownMenuItem(value: 365, child: Text('Last year')),
                          DropdownMenuItem(value: 730, child: Text('Last 2 years')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _days = value);
                            _loadContent();
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<int?>(
                        value: _selectedGenre,
                        hint: const Text('All Genres'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Genres'),
                          ),
                          ..._genres.entries.map((e) => DropdownMenuItem<int?>(
                                value: e.key,
                                child: Text(e.value),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedGenre = value);
                          _loadContent();
                        },
                      ),
                    ],
                    if (_selectedIndex == 1)
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'day', label: Text('Today')),
                          ButtonSegment(value: 'week', label: Text('This Week')),
                        ],
                        selected: {_timeWindow},
                        onSelectionChanged: (selection) {
                          setState(() => _timeWindow = selection.first);
                          _loadContent();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Quality filters',
              onPressed: _showFilterSettings,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadContent,
          ),
        ],
      ),
    );
  }

  void _showFilterSettings() {
    showDialog(
      context: context,
      builder: (context) => _FilterSettingsDialog(
        minRating: _minRating,
        minVotes: _minVotes,
        onSave: (rating, votes) {
          setState(() {
            _minRating = rating;
            _minVotes = votes;
          });
          _loadContent();
        },
      ),
    );
  }

  Widget _buildContent() {
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
            FilledButton(onPressed: _loadContent, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedIndex == 2 ? Icons.search : Icons.movie_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedIndex == 2
                  ? 'Search for movies and TV shows'
                  : 'No content found',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return MediaGrid(items: _items, onTap: _showMediaDetail);
  }
}

class _FilterSettingsDialog extends StatefulWidget {
  final double minRating;
  final int minVotes;
  final void Function(double rating, int votes) onSave;

  const _FilterSettingsDialog({
    required this.minRating,
    required this.minVotes,
    required this.onSave,
  });

  @override
  State<_FilterSettingsDialog> createState() => _FilterSettingsDialogState();
}

class _FilterSettingsDialogState extends State<_FilterSettingsDialog> {
  late double _rating;
  late int _votes;

  @override
  void initState() {
    super.initState();
    _rating = widget.minRating;
    _votes = widget.minVotes;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quality Filters'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Minimum Rating: ${_rating.toStringAsFixed(1)}'),
          Slider(
            value: _rating,
            min: 0,
            max: 9,
            divisions: 18,
            label: _rating.toStringAsFixed(1),
            onChanged: (value) => setState(() => _rating = value),
          ),
          const SizedBox(height: 16),
          Text('Minimum Votes: $_votes'),
          Slider(
            value: _votes.toDouble(),
            min: 0,
            max: 500,
            divisions: 10,
            label: _votes.toString(),
            onChanged: (value) => setState(() => _votes = value.round()),
          ),
          const SizedBox(height: 8),
          Text(
            'Higher values filter out more obscure and low-quality content.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _rating = 0;
              _votes = 0;
            });
          },
          child: const Text('Show All'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_rating, _votes);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
