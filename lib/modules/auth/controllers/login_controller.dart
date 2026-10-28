import 'package:dio/dio.dart';
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
    errorMessage.value = '';
    isLoading.value = true;
    try {
      final result = await _repository.startTelegramLogin();
      final requestId = result['loginRequestId']?.toString();
      final botUrl = result['botUrl']?.toString();
      if (result['success'] != true || requestId == null || botUrl == null) {
        errorMessage.value = result['message']?.toString() ?? 'شروع ورود تلگرامی انجام نشد.';
        return;
      }

      final opened = await launchUrl(
        Uri.parse(botUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        errorMessage.value = 'تلگرام باز نشد. مطمئن شو تلگرام نصب است و دوباره تلاش کن.';
        return;
      }

      // The user must tap Start in Telegram; the backend webhook then
      // associates this one-time request with the Telegram account.
      for (var attempt = 0; attempt < 75; attempt++) {
        await Future.delayed(const Duration(seconds: 2));
        final status = await _repository.getTelegramLoginStatus(requestId);
        if (status['status'] == 'ready') {
          telegramId.value = status['telegramId']?.toString() ?? '';
          challengeId.value = status['challengeId']?.toString() ?? '';
          if (telegramId.value.isNotEmpty && challengeId.value.isNotEmpty) {
            Get.toNamed('/otp');
            return;
          }
        }
        if (status['status'] == 'expired') {
          errorMessage.value = 'مهلت ورود تمام شد؛ دوباره تلاش کن.';
          return;
        }
      }
      errorMessage.value = 'هنوز شروع ربات دریافت نشده. دوباره تلاش کن و در تلگرام Start را بزن.';
    } on DioException catch (e) {
      final data = e.response?.data;
      errorMessage.value = data is Map && data['message'] != null
          ? data['message'].toString()
          : 'ارتباط با سرور برقرار نشد.';
    } catch (_) {
      errorMessage.value = 'خطای غیرمنتظره رخ داد.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> verifyOtp(String otp) async {
    errorMessage.value = '';
    if (challengeId.value.isEmpty) {
      errorMessage.value = 'ابتدا درخواست کد ورود بده.';
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(otp.trim())) {
      errorMessage.value = 'کد باید ۶ رقم باشد.';
      return;
    }

    isLoading.value = true;
    try {
      // Replace with a securely persisted, per-installation device ID before release.
      final deviceId = 'vpn_flutter_device_${telegramId.value.trim()}_v1';
      final result = await _repository.verifyOtp(
        telegramId: telegramId.value.trim(),
        challengeId: challengeId.value,
        otp: otp.trim(),
        deviceId: deviceId,
      );
      final token = result['accessToken']?.toString();
      if (result['success'] != true || token == null || token.isEmpty) {
        errorMessage.value = result['message']?.toString() ?? 'کد تأیید نامعتبر است.';
        return;
      }
      await _tokenStorage.saveToken(token);
      Get.offAllNamed('/home');
    } on DioException catch (e) {
      final data = e.response?.data;
      errorMessage.value = data is Map && data['message'] != null
          ? data['message'].toString()
          : 'ارتباط با سرور برقرار نشد.';
    } catch (_) {
      errorMessage.value = 'خطای غیرمنتظره رخ داد.';
    } finally {
      isLoading.value = false;
    }
  }
}
