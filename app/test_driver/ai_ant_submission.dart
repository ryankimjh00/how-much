import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory(
    Platform.environment['AI_ANT_EVIDENCE_DIR'] ?? 'build/ai-ant-evidence',
  );
  await output.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('${output.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (data) async {
      final report = Map<String, dynamic>.from(data ?? {})
        ..remove('screenshots');
      final fixture = report.remove('fixturePngBase64') as String?;
      if (fixture != null) {
        await File(
          '${output.path}/memo-printed-fixture.png',
        ).writeAsBytes(base64Decode(fixture));
      }
      await File(
        '${output.path}/${report['phase'] ?? 'result'}-report.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    },
  );
}
