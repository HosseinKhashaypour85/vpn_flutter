import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';

import '../bindings/otp_binding.dart';
import '../controllers/otp_controller.dart';

class OtpView extends GetView<OtpController> {
  const OtpView({super.key});

  static final _binding = OtpBinding();

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<OtpController>()) _binding.dependencies();
    final pinController = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('تأیید کد')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('کد ۶ رقمی ارسال‌شده در تلگرام را وارد کن.'),
                  const SizedBox(height: 24),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Pinput(
                      length: 6,
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      onCompleted: controller.verify,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Obx(() {
                    final error = controller.errorMessage.value;
                    if (error.isEmpty) return const SizedBox.shrink();
                    return Text(error, style: const TextStyle(color: Colors.red));
                  }),
                  const SizedBox(height: 12),
                  Obx(() => FilledButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () => controller.verify(pinController.text),
                    child: controller.isLoading.value
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('تأیید و ورود'),
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
