import 'package:kazumi/pages/bangumi/unified_bangumi_page.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/bangumi/bangumi_setting.dart';

class BangumiModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    r.child("/", child: (_) => const UnifiedBangumiPage());
  }
}