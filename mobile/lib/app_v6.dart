import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'app_v5.dart' as base;

class OzirafApp extends base.OzirafApp {
  const OzirafApp({super.key});

  @override
  Widget build(BuildContext context) {
    final inherited = super.build(context);
    if (inherited is! MaterialApp) return inherited;

    return MaterialApp(
      debugShowCheckedModeBanner: inherited.debugShowCheckedModeBanner,
      title: inherited.title,
      theme: inherited.theme,
      darkTheme: inherited.darkTheme,
      themeMode: inherited.themeMode,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      ),
      home: inherited.home,
    );
  }
}
