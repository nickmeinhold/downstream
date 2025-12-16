import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class DownloadsPanel extends StatefulWidget {
  final ScrollController scrollController;

  const DownloadsPanel({
    super.key,
    required this.scrollController,
  });

  @override
  State<DownloadsPanel> createState() => _DownloadsPanelState();
}

class _DownloadsPanelState extends State<DownloadsPanel> {
  List<dynamic> _torrents = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTorrents();
    // Auto-refresh every 3 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadTorrents();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTorrents() async {
    try {
      final api = context.read<ApiService>();
      final torrents = await api.getActiveTorrents();

      if (mounted) {
        setState(() {
          _torrents = torrents;
          _isLoading = false;
          _error = null;
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

  Future<void> _removeTorrent(int id, {bool deleteData = false}) async {
    try {
      final api = context.read<ApiService>();
      await api.removeTorrent(id, deleteData: deleteData);
      _loadTorrents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showRemoveDialog(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Download'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remove "$name"?'),
            const SizedBox(height: 16),
            const Text(
              'Choose whether to also delete the downloaded files.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeTorrent(id, deleteData: false);
            },
            child: const Text('Keep Files'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeTorrent(id, deleteData: true);
            },
            child: const Text('Delete Files'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.download),
              const SizedBox(width: 8),
              Text(
                'Downloads',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadTorrents,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading && _torrents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _torrents.isEmpty) {
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
              onPressed: _loadTorrents,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_torrents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_done,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text('No active downloads'),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: _torrents.length,
      itemBuilder: (context, index) {
        final torrent = _torrents[index] as Map<String, dynamic>;
        return _TorrentItem(
          torrent: torrent,
          onRemove: () => _showRemoveDialog(
            torrent['id'] as int,
            torrent['name'] as String,
          ),
        );
      },
    );
  }
}

class _TorrentItem extends StatelessWidget {
  final Map<String, dynamic> torrent;
  final VoidCallback onRemove;

  const _TorrentItem({
    required this.torrent,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = torrent['name'] as String? ?? 'Unknown';
    final status = torrent['statusText'] as String? ?? '';
    final percentDone = (torrent['percentDone'] as num?)?.toDouble() ?? 0.0;
    final totalSize = torrent['totalSizeText'] as String? ?? '';
    final eta = torrent['etaText'] as String? ?? '';
    final rateDownload = torrent['rateDownload'] as int? ?? 0;

    final isComplete = percentDone >= 1.0;
    final downloadSpeed = _formatSpeed(rateDownload);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentDone,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${(percentDone * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isComplete ? Colors.green : null,
                    fontWeight: isComplete ? FontWeight.bold : null,
                  ),
                ),
                if (totalSize.isNotEmpty) ...[
                  const Text(' • '),
                  Text(totalSize),
                ],
                const Spacer(),
                if (!isComplete && downloadSpeed.isNotEmpty) ...[
                  const Icon(Icons.arrow_downward, size: 14),
                  const SizedBox(width: 4),
                  Text(downloadSpeed),
                ],
                if (!isComplete && eta.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.timer, size: 14),
                  const SizedBox(width: 4),
                  Text(eta),
                ],
                if (isComplete)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
              ],
            ),
            if (status.isNotEmpty && !isComplete) ...[
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}
