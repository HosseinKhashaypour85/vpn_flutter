import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_theme.dart';
import '../bindings/login_binding.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  static final _binding = LoginBinding();

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<LoginController>()) _binding.dependencies();
    return Scaffold(
      appBar: AppBar(title: const Text('ورود به VPN')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const Icon(Icons.shield_moon_rounded, size: 64, color: AppTheme.brand),
                const SizedBox(height: 16),
                const Text('ورود امن به حساب', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('کد تأیید از طریق تلگرام برای شما ارسال می‌شود.', textAlign: TextAlign.center),
                const SizedBox(height: 28),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'آیدی عددی تلگرام', border: OutlineInputBorder()),
                  onChanged: (value) => controller.telegramId.value = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'توکن ورود', border: OutlineInputBorder()),
                  onChanged: (value) => controller.loginToken.value = value,
                ),
                const SizedBox(height: 18),
                Obx(() {
                  final error = controller.errorMessage.value;
                  if (error.isEmpty) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center));
                }),
                Obx(() => FilledButton(
                  onPressed: controller.isLoading.value ? null : controller.requestOtp,
                  child: controller.isLoading.value
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('دریافت کد تأیید'),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
