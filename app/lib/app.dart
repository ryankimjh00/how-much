import 'package:flutter/material.dart';

import 'app_store.dart';
import 'app_theme.dart';
import 'screens.dart';

class HowMuchApp extends StatefulWidget {
  const HowMuchApp({super.key, required this.store});

  final AppStore store;

  @override
  State<HowMuchApp> createState() => _HowMuchAppState();
}

class _HowMuchAppState extends State<HowMuchApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.store.setActive(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '얼마였지',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeScreen(store: widget.store),
    );
  }
}
