import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1180, 800),
      minimumSize: Size(920, 680),
      center: true,
      title: 'Simorgh VPN',
      backgroundColor: Color(0xFF160709),
    );

    await windowManager.waitUntilReadyToShow(
      windowOptions,
          () async {
        await windowManager.setResizable(false);
        await windowManager.setMaximizable(false);
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(const VpnApp());
}