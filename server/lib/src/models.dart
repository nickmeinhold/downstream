class MediaItem {
  final int id;
  final String title;
  final String mediaType; // 'movie' or 'tv'
  final String? overview;
  final String? releaseDate;
  final double? voteAverage;
  final String? posterPath;
  final List<String> providers;
  final List<int> genreIds;

  // TMDB genre ID -> name mapping (combined movie + TV genres)
  static const genreNames = <int, String>{
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Sci-Fi',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
    // TV-specific genres
    10759: 'Action & Adventure',
    10762: 'Kids',
    10763: 'News',
    10764: 'Reality',
    10765: 'Sci-Fi & Fantasy',
    10766: 'Soap',
    10767: 'Talk',
    10768: 'War & Politics',
  };

  MediaItem({
    required this.id,
    required this.title,
    required this.mediaType,
    this.overview,
    this.releaseDate,
    this.voteAverage,
    this.posterPath,
    this.providers = const [],
    this.genreIds = const [],
  });

  factory MediaItem.fromJson(Map<String, dynamic> json, String type) {
    final genreIdsList = json['genre_ids'] as List<dynamic>?;
    return MediaItem(
      id: json['id'] as int,
      title: (json['title'] ?? json['name'] ?? 'Unknown') as String,
      mediaType: type,
      overview: json['overview'] as String?,
      releaseDate: (json['release_date'] ?? json['first_air_date']) as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      posterPath: json['poster_path'] as String?,
      genreIds: genreIdsList?.cast<int>() ?? const [],
    );
  }

  MediaItem copyWith({List<String>? providers, List<int>? genreIds}) {
    return MediaItem(
      id: id,
      title: title,
      mediaType: mediaType,
      overview: overview,
      releaseDate: releaseDate,
      voteAverage: voteAverage,
      posterPath: posterPath,
      providers: providers ?? this.providers,
      genreIds: genreIds ?? this.genreIds,
    );
  }

  /// Convert genre IDs to human-readable names
  List<String> get genres =>
      genreIds.map((id) => genreNames[id]).whereType<String>().toList();

  String get year {
    if (releaseDate == null || releaseDate!.isEmpty) return '';
    return releaseDate!.split('-').first;
  }

  String get rating {
    if (voteAverage == null) return '';
    return voteAverage!.toStringAsFixed(1);
  }

  String get uniqueKey => '${mediaType}_$id';

  String? get posterUrl {
    if (posterPath == null) return null;
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'mediaType': mediaType,
        'overview': overview,
        'releaseDate': releaseDate,
        'year': year,
        'voteAverage': voteAverage,
        'rating': rating,
        'posterPath': posterPath,
        'posterUrl': posterUrl,
        'providers': providers,
        'genres': genres,
        'uniqueKey': uniqueKey,
      };

  @override
  String toString() {
    final parts = <String>[title];
    if (year.isNotEmpty) parts.add('($year)');
    if (rating.isNotEmpty) parts.add('- $rating/10');
    if (providers.isNotEmpty) parts.add('[${providers.join(", ")}]');
    return parts.join(' ');
  }
}

class StreamingProvider {
  final int id;
  final String name;
  final String key;
  final String? logoPath;

  const StreamingProvider({
    required this.id,
    required this.name,
    required this.key,
    this.logoPath,
  });
}
