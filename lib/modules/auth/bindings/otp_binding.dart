import 'package:get/get.dart';

import '../controllers/login_controller.dart';
import '../controllers/otp_controller.dart';

class OtpBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OtpController>(() => OtpController(Get.find<LoginController>()));
  }
}
