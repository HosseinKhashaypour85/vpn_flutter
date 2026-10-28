import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/storage/token_storage.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _decideInitialRoute();
  }

  Future<void> _decideInitialRoute() async {
    final token = await Get.find<TokenStorage>().getToken();
    if (!mounted) return;
    Get.offAllNamed(
      token == null || token.isEmpty ? AppRoutes.login : AppRoutes.home,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
