import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Nodes Feature 不反向依赖 App，Application 不依赖 Presentation', () {
    final failures = <String>[];
    final imports = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
    for (final file in Directory(
      'lib/features/nodes',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final match in imports.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        if (uri.contains('/app/')) failures.add('${file.path}: $uri');
        if (file.path.contains('/application/') &&
            uri.contains('presentation/')) {
          failures.add('${file.path}: $uri');
        }
      }
    }
    expect(failures, isEmpty);
  });
}
