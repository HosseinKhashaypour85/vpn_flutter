import 'package:flutter/material.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Text('خانه VPN\nصفحه اصلی در مرحله بعد پیاده‌سازی می‌شود.'),
        ),
      ),
    );
  }
}
