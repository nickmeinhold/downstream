import 'dart:convert';
import 'package:http/http.dart' as http;

class TransmissionClient {
  final String baseUrl;
  String? _sessionId;

  TransmissionClient({this.baseUrl = 'http://localhost:9091'});

  Future<Map<String, dynamic>> _rpc(String method,
      [Map<String, dynamic>? arguments]) async {
    final body = jsonEncode({
      'method': method,
      if (arguments != null) 'arguments': arguments,
    });

    final headers = {
      'Content-Type': 'application/json',
      if (_sessionId != null) 'X-Transmission-Session-Id': _sessionId!,
    };

    http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/transmission/rpc'),
        headers: headers,
        body: body,
      );
    } catch (e) {
      throw TransmissionException(
        'Connection failed',
        'Could not connect to Transmission at $baseUrl',
      );
    }

    // Handle session ID requirement (409 Conflict)
    if (response.statusCode == 409) {
      _sessionId = response.headers['x-transmission-session-id'];
      if (_sessionId != null) {
        headers['X-Transmission-Session-Id'] = _sessionId!;
        try {
          response = await http.post(
            Uri.parse('$baseUrl/transmission/rpc'),
            headers: headers,
            body: body,
          );
        } catch (e) {
          throw TransmissionException(
            'Connection failed',
            'Could not connect to Transmission at $baseUrl',
          );
        }
      }
    }

    if (response.statusCode != 200) {
      throw TransmissionException(
        'RPC error: ${response.statusCode}',
        response.body,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['result'] != 'success') {
      throw TransmissionException('RPC failed', data['result'] as String?);
    }

    return data['arguments'] as Map<String, dynamic>? ?? {};
  }

  /// Add a torrent by magnet link or URL
  Future<TorrentInfo> addTorrent(String magnetOrUrl) async {
    final result = await _rpc('torrent-add', {
      'filename': magnetOrUrl,
    });

    final added = result['torrent-added'] ?? result['torrent-duplicate'];
    if (added == null) {
      throw TransmissionException('Failed to add torrent', null);
    }

    return TorrentInfo.fromJson(added as Map<String, dynamic>);
  }

  /// Get list of all torrents with their status
  Future<List<TorrentInfo>> getTorrents() async {
    final result = await _rpc('torrent-get', {
      'fields': [
        'id',
        'name',
        'status',
        'percentDone',
        'rateDownload',
        'rateUpload',
        'eta',
        'totalSize',
        'downloadedEver',
        'error',
        'errorString',
        'hashString',
      ],
    });

    final torrents = result['torrents'] as List<dynamic>? ?? [];
    return torrents
        .map((t) => TorrentInfo.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Get a single torrent by ID
  Future<TorrentInfo?> getTorrent(int id) async {
    final result = await _rpc('torrent-get', {
      'ids': [id],
      'fields': [
        'id',
        'name',
        'status',
        'percentDone',
        'rateDownload',
        'rateUpload',
        'eta',
        'totalSize',
        'downloadedEver',
        'error',
        'errorString',
        'hashString',
      ],
    });

    final torrents = result['torrents'] as List<dynamic>? ?? [];
    if (torrents.isEmpty) return null;
    return TorrentInfo.fromJson(torrents.first as Map<String, dynamic>);
  }

  /// Remove a torrent (optionally delete local data)
  Future<void> removeTorrent(int id, {bool deleteLocalData = false}) async {
    await _rpc('torrent-remove', {
      'ids': [id],
      'delete-local-data': deleteLocalData,
    });
  }

  /// Start/resume a torrent
  Future<void> startTorrent(int id) async {
    await _rpc('torrent-start', {
      'ids': [id],
    });
  }

  /// Pause a torrent
  Future<void> stopTorrent(int id) async {
    await _rpc('torrent-stop', {
      'ids': [id],
    });
  }

  /// Test connection to Transmission
  Future<bool> testConnection() async {
    try {
      await _rpc('session-get');
      return true;
    } catch (_) {
      return false;
    }
  }
}

class TorrentInfo {
  final int id;
  final String name;
  final int status;
  final double percentDone;
  final int rateDownload;
  final int rateUpload;
  final int eta;
  final int totalSize;
  final int downloadedEver;
  final int error;
  final String? errorString;
  final String hashString;

  TorrentInfo({
    required this.id,
    required this.name,
    required this.status,
    required this.percentDone,
    required this.rateDownload,
    required this.rateUpload,
    required this.eta,
    required this.totalSize,
    required this.downloadedEver,
    required this.error,
    this.errorString,
    required this.hashString,
  });

  factory TorrentInfo.fromJson(Map<String, dynamic> json) {
    return TorrentInfo(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      status: json['status'] as int? ?? 0,
      percentDone: (json['percentDone'] as num?)?.toDouble() ?? 0.0,
      rateDownload: json['rateDownload'] as int? ?? 0,
      rateUpload: json['rateUpload'] as int? ?? 0,
      eta: json['eta'] as int? ?? -1,
      totalSize: json['totalSize'] as int? ?? 0,
      downloadedEver: json['downloadedEver'] as int? ?? 0,
      error: json['error'] as int? ?? 0,
      errorString: json['errorString'] as String?,
      hashString: json['hashString'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'statusText': statusText,
        'percentDone': percentDone,
        'rateDownload': rateDownload,
        'rateUpload': rateUpload,
        'eta': eta,
        'etaText': etaText,
        'totalSize': totalSize,
        'totalSizeText': _formatBytes(totalSize),
        'downloadedEver': downloadedEver,
        'error': error,
        'errorString': errorString,
        'hashString': hashString,
      };

  String get statusText {
    switch (status) {
      case 0:
        return 'Stopped';
      case 1:
        return 'Queued to verify';
      case 2:
        return 'Verifying';
      case 3:
        return 'Queued to download';
      case 4:
        return 'Downloading';
      case 5:
        return 'Queued to seed';
      case 6:
        return 'Seeding';
      default:
        return 'Unknown';
    }
  }

  String get etaText {
    if (eta < 0) return '';
    if (eta < 60) return '${eta}s';
    if (eta < 3600) return '${eta ~/ 60}m';
    if (eta < 86400) return '${eta ~/ 3600}h ${(eta % 3600) ~/ 60}m';
    return '${eta ~/ 86400}d';
  }

  bool get isDownloading => status == 4;
  bool get isSeeding => status == 6;
  bool get isStopped => status == 0;
  bool get isComplete => percentDone >= 1.0;

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class TransmissionException implements Exception {
  final String message;
  final String? details;

  TransmissionException(this.message, this.details);

  @override
  String toString() => 'TransmissionException: $message${details != null ? ' ($details)' : ''}';
}
