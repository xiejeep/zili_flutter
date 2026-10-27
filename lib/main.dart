import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/home_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: ZiliApp()));
}

class ZiliApp extends StatelessWidget {
  const ZiliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '字里 · 一笔一画，认识汉字',
      debugShowCheckedModeBanner: false,
      theme: ZiliTheme.build(),
      home: const HomePage(),
    );
  }
}
