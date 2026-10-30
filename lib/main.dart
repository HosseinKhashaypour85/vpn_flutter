import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(390, 500),
      minimumSize: Size(390, 500),
      maximumSize: Size(390, 500),
      center: true,
      title: 'VPN',
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