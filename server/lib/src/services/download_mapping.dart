import 'dart:convert';
import 'dart:io';

/// Stores mapping between torrent hashes and TMDB media items.
/// This allows us to track which downloads correspond to which media.
class DownloadMapping {
  final String _filePath;
  Map<String, TmdbRef> _mappings = {};

  DownloadMapping({String? filePath})
      : _filePath = filePath ?? _defaultPath();

  static String _defaultPath() {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.downstream/download_mappings.json';
  }

  Future<void> load() async {
    final file = File(_filePath);
    if (await file.exists()) {
      try {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _mappings = json.map((k, v) => MapEntry(k, TmdbRef.fromJson(v as Map<String, dynamic>)));
      } catch (_) {
        _mappings = {};
      }
    }
  }

  Future<void> _save() async {
    final file = File(_filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(
      _mappings.map((k, v) => MapEntry(k, v.toJson())),
    ));
  }

  /// Store a mapping from torrent hash to TMDB item
  Future<void> addMapping(String torrentHash, int tmdbId, String mediaType) async {
    _mappings[torrentHash] = TmdbRef(tmdbId: tmdbId, mediaType: mediaType);
    await _save();
  }

  /// Get TMDB info for a torrent hash
  TmdbRef? getMapping(String torrentHash) => _mappings[torrentHash];

  /// Get torrent hash for a TMDB item (reverse lookup)
  String? getTorrentHash(int tmdbId, String mediaType) {
    for (final entry in _mappings.entries) {
      if (entry.value.tmdbId == tmdbId && entry.value.mediaType == mediaType) {
        return entry.key;
      }
    }
    return null;
  }

  /// Remove a mapping
  Future<void> removeMapping(String torrentHash) async {
    _mappings.remove(torrentHash);
    await _save();
  }
}

class TmdbRef {
  final int tmdbId;
  final String mediaType;

  TmdbRef({required this.tmdbId, required this.mediaType});

  factory TmdbRef.fromJson(Map<String, dynamic> json) => TmdbRef(
        tmdbId: json['tmdbId'] as int,
        mediaType: json['mediaType'] as String,
      );

  Map<String, dynamic> toJson() => {
        'tmdbId': tmdbId,
        'mediaType': mediaType,
      };
}
