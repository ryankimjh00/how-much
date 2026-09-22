import 'package:flutter/material.dart';

import 'app_store.dart';
import 'app_theme.dart';
import 'screens.dart';

class HowMuchApp extends StatelessWidget {
  const HowMuchApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '얼마였지',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeScreen(store: store),
    );
  }
}
