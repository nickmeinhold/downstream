import 'package:args/command_runner.dart';
import '../providers.dart';

class ProvidersCommand extends Command<void> {
  @override
  final name = 'providers';
  @override
  final description = 'List available streaming providers';

  @override
  Future<void> run() async {
    print('Available Streaming Providers:\n');
    print('| Key        | Service              |');
    print('|------------|----------------------|');

    for (final provider in Providers.all) {
      final key = provider.key.padRight(10);
      final name = provider.name.padRight(20);
      print('| $key | $name |');
    }

    print('');
    print('Default providers: ${Providers.defaultProviders.map((p) => p.name).join(", ")}');
    print('');
    print('Use -p flag to filter by provider:');
    print('  upstream new -p netflix -p disney');
  }
}
