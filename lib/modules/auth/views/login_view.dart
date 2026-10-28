import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_theme.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
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
                const Icon(Icons.shield_moon_rounded, size: 72, color: AppTheme.brand),
                const SizedBox(height: 20),
                const Text(
                  'ورود امن با تلگرام',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'برای ورود، ربات رسمی را باز کن و روی Start بزن. کد تأیید در تلگرام برایت ارسال می‌شود.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Obx(() {
                  final error = controller.errorMessage.value;
                  if (error.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      error,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  );
                }),
                Obx(() => FilledButton.icon(
                  onPressed: controller.isLoading.value ? null : controller.startTelegramLogin,
                  icon: controller.isLoading.value
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    controller.isLoading.value
                        ? 'در انتظار تأیید در تلگرام...'
                        : 'ورود با تلگرام',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                )),
                const SizedBox(height: 12),
                const Text(
                  'پس از زدن Start، به اپ برگرد تا صفحه واردکردن کد نمایش داده شود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
