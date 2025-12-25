import 'dart:convert';
import 'dart:io';
import 'package:googleapis/firestore/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

void main() async {
  final envContent = File('.env').readAsStringSync();

  // Get service account
  final saMatch = RegExp(r"FIREBASE_SERVICE_ACCOUNT='(.+)'").firstMatch(envContent);
  if (saMatch == null) {
    print('Could not find service account');
    return;
  }

  // Get TMDB API key
  final tmdbMatch = RegExp(r"TMDB_API_KEY=(\S+)").firstMatch(envContent);
  if (tmdbMatch == null) {
    print('Could not find TMDB API key');
    return;
  }
  final tmdbKey = tmdbMatch.group(1)!;

  final serviceAccountJson = json.decode(saMatch.group(1)!);
  final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
  final client = await clientViaServiceAccount(credentials, [FirestoreApi.datastoreScope]);
  final firestore = FirestoreApi(client);

  final projectId = 'downstream-181e2';
  final parent = 'projects/$projectId/databases/(default)/documents';

  final requests = await firestore.projects.databases.documents.listDocuments(parent, 'requests');

  for (final doc in requests.documents ?? []) {
    final docId = doc.name!.split('/').last;
    final fields = doc.fields ?? {};
    final title = fields['title']?.stringValue;
    final posterPath = fields['posterPath']?.stringValue;
    final tmdbId = fields['tmdbId']?.integerValue;
    final mediaType = fields['mediaType']?.stringValue ?? 'movie';

    if (title == null || tmdbId == null) continue;

    if (posterPath != null) {
      print('$title - already has poster');
      continue;
    }

    // Fetch from TMDB
    print('$title - fetching poster from TMDB...');
    final url = 'https://api.themoviedb.org/3/$mediaType/$tmdbId?api_key=$tmdbKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      print('  Failed to fetch: ${response.statusCode}');
      continue;
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final newPosterPath = data['poster_path'] as String?;

    if (newPosterPath == null) {
      print('  No poster available');
      continue;
    }

    // Update Firestore
    await firestore.projects.databases.documents.patch(
      Document(
        fields: {
          'posterPath': Value(stringValue: newPosterPath),
        },
      ),
      doc.name!,
      updateMask_fieldPaths: ['posterPath'],
    );
    print('  Updated: $newPosterPath');
  }

  client.close();
  print('\nDone!');
}
