import 'package:get/get.dart';

import 'login_controller.dart';

class OtpController extends GetxController {
  OtpController(this._loginController);
  final LoginController _loginController;

  RxBool get isLoading => _loginController.isLoading;
  RxString get errorMessage => _loginController.errorMessage;

  Future<void> verify(String otp) => _loginController.verifyOtp(otp);
}
