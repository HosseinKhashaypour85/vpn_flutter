
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../data/repositories/auth_repository.dart';

class LoginController extends GetxController {
  LoginController({
    AuthRepository? repository,
    TokenStorage? tokenStorage,
  })  : _repository = repository ?? AuthRepository(Get.find<ApiClient>()),
        _tokenStorage = tokenStorage ?? Get.find<TokenStorage>();

  final AuthRepository _repository;
  final TokenStorage _tokenStorage;

  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final telegramId = ''.obs;
  final challengeId = ''.obs;

  Future<void> startTelegramLogin() async {
    if (isLoading.value) return;

    errorMessage.value = '';
    isLoading.value = true;

    try {
      final result = await _repository.startTelegramLogin();

      final requestId = result['loginRequestId']?.toString();
      final botUrl = result['botUrl']?.toString();

      if (result['success'] != true ||
          requestId == null ||
          requestId.isEmpty ||
          botUrl == null ||
          botUrl.isEmpty) {
        errorMessage.value =
            result['message']?.toString() ??
                'سرور درخواست ورود معتبر برنگرداند.';
        return;
      }

      final uri = Uri.tryParse(botUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 't.me') {
        errorMessage.value = 'لینک ربات دریافتی از سرور معتبر نیست.';
        return;
      }

      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        errorMessage.value = 'باز کردن ربات تلگرام ناموفق بود.';
        return;
      }

      // در تلگرام حتماً روی Start بزن.
      for (var attempt = 0; attempt < 75; attempt++) {
        await Future.delayed(const Duration(seconds: 2));

        final status =
        await _repository.getTelegramLoginStatus(requestId);

        final currentStatus = status['status']?.toString();

        if (currentStatus == 'ready') {
          telegramId.value =
              status['telegramId']?.toString() ?? '';
          challengeId.value =
              status['challengeId']?.toString() ?? '';

          if (telegramId.value.isNotEmpty &&
              challengeId.value.isNotEmpty) {
            Get.toNamed('/otp');
            return;
          }

          errorMessage.value =
          'پاسخ وضعیت ورود ناقص است. ساختار پاسخ API را بررسی کن.';
          return;
        }

        if (currentStatus == 'expired') {
          errorMessage.value =
          'مهلت ورود تمام شد؛ دوباره تلاش کن.';
          return;
        }
      }

      errorMessage.value =
      'درخواست ورود تأیید نشد. ربات را Start کن و webhook سرور را بررسی کن.';
    } on DioException catch (e, stackTrace) {
      debugPrint('Telegram login Dio error: ${e.type}');
      debugPrint('Request URL: ${e.requestOptions.uri}');
      debugPrint('HTTP status: ${e.response?.statusCode}');
      debugPrint('Response: ${e.response?.data}');
      debugPrint('Message: ${e.message}');
      debugPrint('UNDERLYING ERROR: ${e.error}');
      debugPrintStack(stackTrace: stackTrace);

      final data = e.response?.data;
      final serverMessage =
      data is Map ? data['message']?.toString() : null;

      if (serverMessage != null && serverMessage.isNotEmpty) {
        errorMessage.value = serverMessage;
      } else if (e.response?.statusCode != null) {
        errorMessage.value =
        'خطای سرور: HTTP ${e.response!.statusCode}';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        errorMessage.value =
        'اتصال به سرور برقرار نشد؛ اینترنت، آدرس API و SSL را بررسی کن.';
      } else {
        errorMessage.value =
        'خطای شبکه: ${e.type.name}';
      }
    } catch (e, stackTrace) {
      debugPrint('Telegram login error: $e');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage.value = 'خطای غیرمنتظره رخ داد.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> verifyOtp(String otp) async {
    errorMessage.value = '';

    if (challengeId.value.isEmpty || telegramId.value.isEmpty) {
      errorMessage.value = 'ابتدا درخواست ورود تلگرامی بده.';
      return;
    }

    final code = otp.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      errorMessage.value = 'کد باید ۶ رقم باشد.';
      return;
    }

    if (isLoading.value) return;
    isLoading.value = true;

    try {
      // شناسه ثابت فعلی صرفاً برای تست است؛ قبل از انتشار باید
      // با شناسه اختصاصی و پایدار هر نصب جایگزین شود.
      final deviceId =
          'vpn_flutter_device_${telegramId.value.trim()}_v1';

      final result = await _repository.verifyOtp(
        telegramId: telegramId.value.trim(),
        challengeId: challengeId.value,
        otp: code,
        deviceId: deviceId,
      );

      final token = result['accessToken']?.toString();

      if (result['success'] != true ||
          token == null ||
          token.isEmpty) {
        errorMessage.value =
            result['message']?.toString() ??
                'کد تأیید نامعتبر است.';
        return;
      }

      await _tokenStorage.saveToken(token);
      Get.offAllNamed('/home');
    } on DioException catch (e, stackTrace) {
      debugPrint('OTP verification error: ${e.type}');
      debugPrint('Request URL: ${e.requestOptions.uri}');
      debugPrint('HTTP status: ${e.response?.statusCode}');
      debugPrint('Response: ${e.response?.data}');
      debugPrintStack(stackTrace: stackTrace);

      final data = e.response?.data;
      final serverMessage =
      data is Map ? data['message']?.toString() : null;

      if (serverMessage != null && serverMessage.isNotEmpty) {
        errorMessage.value = serverMessage;
      } else if (e.response?.statusCode != null) {
        errorMessage.value =
        'خطای سرور: HTTP ${e.response!.statusCode}';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        errorMessage.value = 'اتصال به سرور برقرار نشد.';
      } else {
        errorMessage.value =
        'خطای شبکه: ${e.type.name}';
      }
    } catch (e, stackTrace) {
      debugPrint('OTP error: $e');
      debugPrintStack(stackTrace: stackTrace);

      errorMessage.value = 'خطای غیرمنتظره رخ داد.';
    } finally {
      isLoading.value = false;
    }
  }
}
