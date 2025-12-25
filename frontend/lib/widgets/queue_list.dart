import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class QueueList extends StatelessWidget {
  final List<dynamic> items;
  final VoidCallback onRefresh;
  final Future<void> Function(String mediaType, int id)? onRetry;

  const QueueList({
    super.key,
    required this.items,
    required this.onRefresh,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _QueueItem(
        item: items[index],
        onRetry: onRetry,
      ),
    );
  }
}

class _QueueItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final Future<void> Function(String mediaType, int id)? onRetry;

  const _QueueItem({required this.item, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String? ?? 'Unknown';
    final mediaType = (item['mediaType'] as String? ?? 'movie').toUpperCase();
    final status = item['status'] as String? ?? 'pending';
    final posterUrl = item['posterUrl'] as String?;
    // final requestedBy = item['requestedBy'] as String? ?? '';
    final requestedAt = item['requestedAt'] as String?;
    final errorMessage = item['errorMessage'] as String?;

    final downloadProgress = (item['downloadProgress'] as num?)?.toDouble() ?? 0.0;
    final transcodingProgress = (item['transcodingProgress'] as num?)?.toDouble() ?? 0.0;
    final uploadProgress = (item['uploadProgress'] as num?)?.toDouble() ?? 0.0;

    final downloadStartedAt = item['downloadStartedAt'] as String?;
    final transcodingStartedAt = item['transcodingStartedAt'] as String?;
    final uploadStartedAt = item['uploadStartedAt'] as String?;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 120,
                child: posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.movie, size: 32),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.movie, size: 32),
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.movie, size: 32),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and media type
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          mediaType,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Status
                  _StatusChip(status: status),
                  const SizedBox(height: 12),
                  // Progress bars
                  _ProgressRow(
                    label: 'Download',
                    progress: downloadProgress,
                    isActive: status == 'downloading',
                    isComplete: _isPhaseComplete(status, 'downloading'),
                    isFailed: status == 'failed' && downloadProgress < 1.0,
                    startedAt: downloadStartedAt,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  _ProgressRow(
                    label: 'Transcode',
                    progress: transcodingProgress,
                    isActive: status == 'transcoding',
                    isComplete: _isPhaseComplete(status, 'transcoding'),
                    isFailed: status == 'failed' && downloadProgress >= 1.0 && transcodingProgress < 1.0,
                    startedAt: transcodingStartedAt,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _ProgressRow(
                    label: 'Upload',
                    progress: uploadProgress,
                    isActive: status == 'uploading',
                    isComplete: status == 'available',
                    isFailed: status == 'failed' && transcodingProgress >= 1.0,
                    startedAt: uploadStartedAt,
                    color: Colors.green,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Error: $errorMessage',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Requested info and retry button
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Requested ${_formatTimeAgo(requestedAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      if (status == 'failed' && onRetry != null)
                        TextButton.icon(
                          onPressed: () {
                            final mediaType = item['mediaType'] as String? ?? 'movie';
                            final tmdbId = item['tmdbId'] as int? ?? 0;
                            onRetry!(mediaType, tmdbId);
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isPhaseComplete(String status, String phase) {
    const phaseOrder = ['pending', 'downloading', 'transcoding', 'uploading', 'available'];
    final statusIndex = phaseOrder.indexOf(status);
    final phaseIndex = phaseOrder.indexOf(phase);
    return statusIndex > phaseIndex;
  }

  String _formatTimeAgo(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'just now';
      }
    } catch (_) {
      return '';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      'pending' => (Colors.grey, Icons.hourglass_empty, 'Pending'),
      'downloading' => (Colors.blue, Icons.download, 'Downloading'),
      'transcoding' => (Colors.orange, Icons.transform, 'Transcoding'),
      'uploading' => (Colors.green, Icons.cloud_upload, 'Uploading'),
      'available' => (Colors.teal, Icons.check_circle, 'Available'),
      'failed' => (Colors.red, Icons.error, 'Failed'),
      _ => (Colors.grey, Icons.help, status),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double progress;
  final bool isActive;
  final bool isComplete;
  final bool isFailed;
  final String? startedAt;
  final Color color;

  const _ProgressRow({
    required this.label,
    required this.progress,
    required this.isActive,
    required this.isComplete,
    required this.isFailed,
    this.startedAt,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progressText = isComplete
        ? null
        : isFailed
            ? null
            : isActive
                ? '${(progress * 100).toStringAsFixed(0)}%'
                : null;

    final etaText = isActive && progress > 0.05 && startedAt != null
        ? _estimateRemaining(progress, startedAt!)
        : null;

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isComplete ? 1.0 : progress,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                isFailed
                    ? Colors.red
                    : isComplete
                        ? color.withValues(alpha: 0.7)
                        : color,
              ),
              minHeight: 8,
            ),
          ),
        ),
        SizedBox(
          width: 80,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: isComplete
                ? Icon(Icons.check, size: 16, color: color)
                : isFailed
                    ? Icon(Icons.close, size: 16, color: Colors.red)
                    : progressText != null
                        ? Text(
                            etaText != null ? '$progressText $etaText' : progressText,
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.right,
                          )
                        : Text(
                            '—',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.right,
                          ),
          ),
        ),
      ],
    );
  }

  String? _estimateRemaining(double progress, String startedAtIso) {
    try {
      final startedAt = DateTime.parse(startedAtIso);
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed.inSeconds < 5) return null;

      final totalEstimate = elapsed.inSeconds / progress;
      final remaining = (totalEstimate * (1 - progress)).round();

      if (remaining < 60) {
        return '~${remaining}s';
      } else if (remaining < 3600) {
        return '~${(remaining / 60).round()}m';
      } else {
        return '~${(remaining / 3600).round()}h';
      }
    } catch (_) {
      return null;
    }
  }
}
