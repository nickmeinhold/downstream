import 'dart:convert';
import 'dart:io';
import 'package:googleapis/firestore/v1.dart';
import 'package:googleapis_auth/auth_io.dart';

void main(List<String> args) async {
  final envContent = File('.env').readAsStringSync();
  final match = RegExp(r"FIREBASE_SERVICE_ACCOUNT='(.+)'").firstMatch(envContent);
  if (match == null) {
    print('Could not find service account');
    return;
  }

  final serviceAccountJson = json.decode(match.group(1)!);
  final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
  final client = await clientViaServiceAccount(credentials, [FirestoreApi.datastoreScope]);
  final firestore = FirestoreApi(client);

  final projectId = 'downstream-181e2';
  final parent = 'projects/$projectId/databases/(default)/documents';

  final requests = await firestore.projects.databases.documents.listDocuments(parent, 'requests');

  print('=== All Requests ===\n');
  for (final doc in requests.documents ?? []) {
    final docId = doc.name!.split('/').last;
    final fields = doc.fields ?? {};
    final title = fields['title']?.stringValue;
    final posterPath = fields['posterPath']?.stringValue;

    print('ID: $docId');
    print('  Title: ${title ?? 'N/A'}');
    print('  PosterPath: ${posterPath ?? 'MISSING'}');

    // Delete if title is null/missing (corrupted document)
    if (title == null && args.contains('--delete-broken')) {
      print('  -> DELETING (no title)');
      await firestore.projects.databases.documents.delete(doc.name!);
    }
    print('');
  }

  if (!args.contains('--delete-broken')) {
    print('Run with --delete-broken to delete corrupted documents');
  }

  client.close();
}
