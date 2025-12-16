import 'dart:io';
import 'package:upstream/src/server/server.dart';

void main(List<String> arguments) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;

  // Check for static files path (built Flutter web app)
  String? staticPath;
  if (arguments.isNotEmpty) {
    staticPath = arguments.first;
  } else if (await Directory('frontend/build/web').exists()) {
    staticPath = 'frontend/build/web';
  }

  final server = UpstreamServer(
    port: port,
    staticPath: staticPath,
  );

  try {
    await server.start();
  } catch (e) {
    stderr.writeln('Failed to start server: $e');
    exit(1);
  }
}
