import 'package:get/get.dart';

import '../../modules/auth/bindings/login_binding.dart';
import '../../modules/auth/bindings/otp_binding.dart';
import '../../modules/auth/views/login_view.dart';
import '../../modules/auth/views/otp_view.dart';
import '../../modules/home/views/home_view.dart';
import '../../modules/splash/views/splash_view.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final pages = <GetPage<dynamic>>[
    GetPage<void>(name: AppRoutes.splash, page: () => const SplashView()),
    GetPage<void>(name: AppRoutes.login, page: () => const LoginView(), binding: LoginBinding()),
    GetPage<void>(name: AppRoutes.otp, page: () => const OtpView(), binding: OtpBinding()),
    GetPage<void>(name: AppRoutes.home, page: () => const HomeView()),
  ];
}
