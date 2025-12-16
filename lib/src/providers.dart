import 'models.dart';

/// TMDB Watch Provider IDs for US region
class Providers {
  static const netflix = StreamingProvider(
    id: 8,
    name: 'Netflix',
    key: 'netflix',
  );

  static const disney = StreamingProvider(
    id: 337,
    name: 'Disney+',
    key: 'disney',
  );

  static const apple = StreamingProvider(
    id: 350,
    name: 'Apple TV+',
    key: 'apple',
  );

  static const paramount = StreamingProvider(
    id: 531,
    name: 'Paramount+',
    key: 'paramount',
  );

  static const prime = StreamingProvider(
    id: 9,
    name: 'Amazon Prime Video',
    key: 'prime',
  );

  static const hbo = StreamingProvider(
    id: 384,
    name: 'HBO Max',
    key: 'hbo',
  );

  static const hulu = StreamingProvider(
    id: 15,
    name: 'Hulu',
    key: 'hulu',
  );

  static const peacock = StreamingProvider(
    id: 386,
    name: 'Peacock',
    key: 'peacock',
  );

  static const all = [
    netflix,
    disney,
    apple,
    paramount,
    prime,
    hbo,
    hulu,
    peacock,
  ];

  static const defaultProviders = [
    netflix,
    disney,
    apple,
    paramount,
  ];

  static List<int> get defaultProviderIds =>
      defaultProviders.map((p) => p.id).toList();

  static StreamingProvider? byKey(String key) {
    final lower = key.toLowerCase();
    for (final p in all) {
      if (p.key == lower) return p;
    }
    return null;
  }

  static StreamingProvider? byId(int id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static List<int> parseProviderKeys(List<String> keys) {
    final ids = <int>[];
    for (final key in keys) {
      final provider = byKey(key);
      if (provider != null) {
        ids.add(provider.id);
      }
    }
    return ids.isEmpty ? defaultProviderIds : ids;
  }

  static String? nameById(int id) => byId(id)?.name;
}
