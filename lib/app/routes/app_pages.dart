import 'package:get/get.dart';

import '../../modules/auth/views/login_view.dart';
import '../../modules/splash/views/splash_view.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final pages = <GetPage<dynamic>>[
    GetPage<void>(
      name: AppRoutes.splash,
      page: () => const SplashView(),
    ),
    GetPage<void>(
      name: AppRoutes.login,
      page: () => const LoginView(),
    ),
  ];
}
