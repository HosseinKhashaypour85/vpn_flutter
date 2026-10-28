import '../../core/network/api_client.dart';

class AuthRepository {
  AuthRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<Map<String, dynamic>> requestOtp({
    required String telegramId,
    required String loginToken,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      'auth/request-otp',
      data: {'telegramId': telegramId, 'loginToken': loginToken},
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
