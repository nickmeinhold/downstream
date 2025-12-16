class MediaItem {
  final int id;
  final String title;
  final String mediaType; // 'movie' or 'tv'
  final String? overview;
  final String? releaseDate;
  final double? voteAverage;
  final String? posterPath;
  final List<String> providers;

  MediaItem({
    required this.id,
    required this.title,
    required this.mediaType,
    this.overview,
    this.releaseDate,
    this.voteAverage,
    this.posterPath,
    this.providers = const [],
  });

  factory MediaItem.fromJson(Map<String, dynamic> json, String type) {
    return MediaItem(
      id: json['id'] as int,
      title: (json['title'] ?? json['name'] ?? 'Unknown') as String,
      mediaType: type,
      overview: json['overview'] as String?,
      releaseDate: (json['release_date'] ?? json['first_air_date']) as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      posterPath: json['poster_path'] as String?,
    );
  }

  MediaItem copyWith({List<String>? providers}) {
    return MediaItem(
      id: id,
      title: title,
      mediaType: mediaType,
      overview: overview,
      releaseDate: releaseDate,
      voteAverage: voteAverage,
      posterPath: posterPath,
      providers: providers ?? this.providers,
    );
  }

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
