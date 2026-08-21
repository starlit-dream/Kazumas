import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/image_preview.dart';
import 'package:kazumi/pages/collect/collect_module.dart';
import 'package:kazumi/pages/index_page.dart';
import 'package:kazumi/pages/info/info_module.dart';
import 'package:kazumi/pages/init_page.dart';
import 'package:kazumi/pages/my/my_module.dart';
import 'package:kazumi/pages/onboarding/onboarding_page.dart';
import 'package:kazumi/pages/popular/popular_controller.dart';
import 'package:kazumi/pages/popular/popular_module.dart';
import 'package:kazumi/pages/route_error_page.dart';
import 'package:kazumi/pages/search/search_module.dart';
import 'package:kazumi/pages/settings/settings_module.dart';
import 'package:kazumi/pages/timeline/timeline_controller.dart';
import 'package:kazumi/pages/timeline/timeline_module.dart';
import 'package:kazumi/pages/video/video_module.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/services/shaders/shader_asset_service.dart';

final _tabTransition = CustomTransition(
  duration: const Duration(milliseconds: 70),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(opacity: animation, child: child);
  },
);

final _imagePreviewTransition = CustomTransition(
  duration: const Duration(milliseconds: 220),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(opacity: animation, child: child);
  },
);

final tabModule = createModule(
  path: '/tab',
  register: (c) {
    c
      // Tab state survives tab switches, but is released with the whole shell.
      ..addSingleton<PopularController>(PopularController.new)
      ..addSingleton<TimelineController>(TimelineController.new)
      ..route(
        '/',
        child: (context, state) => const IndexPage(),
        transition: _tabTransition,
        children: (sub) {
          sub
            ..route(
              '/',
              guards: [
                (state) => GStorage.getSetting(SettingsKeys.defaultStartupPage),
              ],
              child: (context, state) => const SizedBox.shrink(),
            )
            ..module(popularModule)
            ..module(timelineModule)
            ..module(collectModule)
            ..module(myModule);
        },
      );
  },
);

  @override
  void routes(r) {
    r.child("/",
        child: (_) => const InitPage(),
        children: [
          ChildRoute(
            "/error",
            child: (_) => Scaffold(
          appBar: AppBar(title: const Text("Kazumas")),
              body: const Center(child: Text("初始化失败")),
            ),
          ),
        ],
        transition: TransitionType.noTransition);
    r.child(
      "/tab",
      child: (_) {
        return const IndexPage();
      },
      children: menu.routes,
      transition: TransitionType.fadeIn,
      duration: Duration(milliseconds: 70),
    );
    r.module("/video", module: VideoModule());
    r.child(
      ImageViewer.routePath,
      child: (_) {
        final args = Modular.args.data as ImageViewerRouteArgs;
        return ImageViewer(
          imageUrl: args.imageUrl,
          heroTag: args.heroTag,
        );
      },
      transition: TransitionType.fadeIn,
      duration: Duration(milliseconds: 220),
    );

    /// The route need [ BangumiItem ] as argument.
    r.module("/info", module: InfoModule());
    r.module("/settings", module: SettingsModule());
    r.module("/search", module: SearchModule());
  }
}
