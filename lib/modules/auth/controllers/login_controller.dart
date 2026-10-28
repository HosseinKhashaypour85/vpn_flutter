import 'package:dio/dio.dart';
import 'package:get/get.dart';

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
  final loginToken = ''.obs;
  final challengeId = ''.obs;

  Future<void> requestOtp() async {
    errorMessage.value = '';
    if (!RegExp(r'^\d{5,20}$').hasMatch(telegramId.value.trim())) {
      errorMessage.value = 'آیدی عددی تلگرام معتبر نیست.';
      return;
    }
    if (loginToken.value.trim().length < 20) {
      errorMessage.value = 'توکن ورود باید حداقل ۲۰ کاراکتر باشد.';
      return;
    }

    isLoading.value = true;
    try {
      final result = await _repository.requestOtp(
        telegramId: telegramId.value.trim(),
        loginToken: loginToken.value.trim(),
      );
      final id = result['challengeId']?.toString();
      if (result['success'] != true || id == null || id.isEmpty) {
        errorMessage.value = result['message']?.toString() ?? 'ارسال کد انجام نشد.';
        return;
      }
      challengeId.value = id;
      Get.toNamed('/otp');
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
