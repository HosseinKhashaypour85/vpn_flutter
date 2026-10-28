import '../../core/network/api_client.dart';

class AuthRepository {
  AuthRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<Map<String, dynamic>> startTelegramLogin() async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      'auth/telegram/start',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getTelegramLoginStatus(String requestId) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      'auth/telegram/status/$requestId',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String telegramId,
    required String challengeId,
    required String otp,
    required String deviceId,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      'auth/verify-otp',
      data: {
        'telegramId': telegramId,
        'challengeId': challengeId,
        'otp': otp,
        'deviceId': deviceId,
      },
    );
    return response.data ?? <String, dynamic>{};
  }
}
