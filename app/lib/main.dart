import 'package:flutter/material.dart';



import 'app.dart';
import 'app_store.dart';
import 'cloud_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cloud = CloudService(ServerConfig.apiUrl.isNotEmpty);
  var sessionLoadFailed = false;
  try {
    await cloud.initialize();
  } catch (_) {
    // 안전한 계정 저장소를 읽지 못해도 별도의 기기 기록은 열 수 있다.
    sessionLoadFailed = true;
  }
  final store = AppStore(cloud);
  await store.initialize();
  if (sessionLoadFailed) {
    store.syncMessage = '계정 정보를 읽지 못했어요. 앱을 다시 열어주세요. 기기 기록은 유지됩니다.';
  }
  runApp(HowMuchApp(store: store));
}
