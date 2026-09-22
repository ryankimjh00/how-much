import 'package:flutter/material.dart';

import 'app.dart';
import 'app_store.dart';
import 'cloud_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    firebaseReady = await FirebaseConfig.initialize();
  } catch (_) {
    firebaseReady = false;
  }
  final store = AppStore(CloudService(firebaseReady));
  await store.initialize();
  runApp(HowMuchApp(store: store));
}
