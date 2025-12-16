import 'dart:convert';
import 'package:http/http.dart' as http;

class JackettClient {
  final String baseUrl;
  final String apiKey;

  JackettClient({
    this.baseUrl = 'http://localhost:9117',
    required this.apiKey,
  });

  /// Search all configured indexers for torrents
  Future<List<TorrentResult>> search(String query, {String? category}) async {
    final params = {
      'apikey': apiKey,
      'Query': query,
      if (category != null) 'Category[]': category,
    };

    final uri = Uri.parse('$baseUrl/api/v2.0/indexers/all/results')
        .replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw JackettException('Search failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['Results'] as List<dynamic>? ?? [];

    return results
        .map((r) => TorrentResult.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Search for movies (category 2000)
  Future<List<TorrentResult>> searchMovies(String query) async {
    return search(query, category: '2000');
  }

  /// Search for TV shows (category 5000)
  Future<List<TorrentResult>> searchTv(String query) async {
    return search(query, category: '5000');
  }

  /// Get configured indexers
  Future<List<IndexerInfo>> getIndexers() async {
    final uri = Uri.parse('$baseUrl/api/v2.0/indexers')
        .replace(queryParameters: {'apikey': apiKey});

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw JackettException('Failed to get indexers: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((i) => IndexerInfo.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  /// Test connection to Jackett
  Future<bool> testConnection() async {
    try {
      await getIndexers();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class TorrentResult {
  final String title;
  final String? guid;
  final String? link;
  final String? magnetUri;
  final int size;
  final int seeders;
  final int peers;
  final String? indexer;
  final DateTime? publishDate;
  final String? category;

  TorrentResult({
    required this.title,
    this.guid,
    this.link,
    this.magnetUri,
    required this.size,
    required this.seeders,
    required this.peers,
    this.indexer,
    this.publishDate,
    this.category,
  });

  factory TorrentResult.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (_) {
        return null;
      }
    }

    return TorrentResult(
      title: json['Title'] as String? ?? 'Unknown',
      guid: json['Guid'] as String?,
      link: json['Link'] as String?,
      magnetUri: json['MagnetUri'] as String?,
      size: json['Size'] as int? ?? 0,
      seeders: json['Seeders'] as int? ?? 0,
      peers: json['Peers'] as int? ?? 0,
      indexer: json['Tracker'] as String?,
      publishDate: parseDate(json['PublishDate'] as String?),
      category: (json['CategoryDesc'] as String?) ??
          (json['Category'] as List?)?.firstOrNull?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'guid': guid,
        'link': link,
        'magnetUri': magnetUri,
        'size': size,
        'sizeText': _formatBytes(size),
        'seeders': seeders,
        'peers': peers,
        'indexer': indexer,
        'publishDate': publishDate?.toIso8601String(),
        'category': category,
      };

  /// Get the download URL (prefer magnet, fallback to link)
  String? get downloadUrl => magnetUri ?? link;

  bool get hasMagnet => magnetUri != null && magnetUri!.isNotEmpty;

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class IndexerInfo {
  final String id;
  final String name;
  final bool configured;

  IndexerInfo({
    required this.id,
    required this.name,
    required this.configured,
  });

  factory IndexerInfo.fromJson(Map<String, dynamic> json) {
    return IndexerInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      configured: json['configured'] as bool? ?? false,
    );
  }
}

class JackettException implements Exception {
  final String message;

  JackettException(this.message);

  @override
  String toString() => 'JackettException: $message';
}
