import 'package:PiliPlus/pages/video/view.dart';
import 'package:PiliPlus/tv/pages/tv_detail_page.dart';
import 'package:PiliPlus/tv/pages/tv_home_page.dart';
import 'package:PiliPlus/tv/pages/tv_login_page.dart';
import 'package:PiliPlus/tv/pages/tv_search_page.dart';
import 'package:get/get.dart';

abstract final class TvRoutes {
  static final pages = <GetPage<dynamic>>[
    GetPage(name: '/', page: () => const TvHomePage()),
    GetPage(name: '/tv/search', page: () => const TvSearchPage()),
    GetPage(name: '/tv/detail', page: () => const TvDetailPage()),
    GetPage(name: '/tv/login', page: () => const TvLoginPage()),
    GetPage(name: '/videoV', page: () => const VideoDetailPageV()),
  ];
}
