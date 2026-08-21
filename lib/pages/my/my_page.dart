import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/my/watch_stats.dart';
import 'package:kazumi/pages/menu/route_visibility.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/pages/my/recent_watch_card.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/date_time.dart';

/// Shared by every block on this page, entry group included, so they read as
/// one set of cards.
const double _cardRadius = 16;

class MyPage extends StatefulWidget {
  const MyPage({super.key, required this.controller});

  final MyController controller;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  MyController get myController => widget.controller;

  bool _attached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This page stays mounted under the player, which rewrites history every
    // second. Drop the subscription while covered, re-derive on the way back.
    _setAttached(!RouteVisibility.isCoveredOf(context));
  }

  @override
  void dispose() {
    _setAttached(false);
    super.dispose();
  }

  void _setAttached(bool value) {
    if (_attached == value) {
      return;
    }
    _attached = value;
    if (value) {
      myController.attach();
    } else {
      myController.detach();
    }
  }

  int _recentCrossCount() {
    final width = MediaQuery.sizeOf(context).width;
    if (width > LayoutBreakpoint.medium['width']!) {
      return 3;
    }
    if (width > LayoutBreakpoint.compact['width']!) {
      return 2;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final bool wide =
        MediaQuery.sizeOf(context).width > LayoutBreakpoint.compact['width']!;
    return Scaffold(
      appBar: const SysAppBar(title: Text('我的'), needTopOffset: false),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Observer(
          builder: (context) {
            final stats = myController.watchStats;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1400 : 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide) _wideHeader(stats) else ..._narrowHeader(stats),
                      ..._recentSection(),
                    ],
                  ),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/download/');
                  },
                  leading: const Icon(Icons.download_rounded),
                  title: Text('下载管理', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('查看和管理离线下载',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/download-settings');
                  },
                  leading: const Icon(Icons.settings_rounded),
                  title: Text('下载设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('配置下载并发数等参数',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/plugin/');
                  },
                  leading: const Icon(Icons.extension),
                  title: Text('规则管理', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('管理番剧资源规则',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              title: Text('播放器设置', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/player');
                  },
                  leading: const Icon(Icons.display_settings_rounded),
                  title: Text('播放设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('设置播放器相关参数',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/danmaku/');
                  },
                  leading: const Icon(Icons.subtitles_rounded),
                  title: Text('弹幕设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('设置弹幕相关参数',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/keyboard');
                  },
                  leading: const Icon(Icons.keyboard_rounded),
                  title: Text('操作设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('设置播放器按键映射',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/proxy');
                  },
                  leading: const Icon(Icons.vpn_key_rounded),
                  title: Text('代理设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('配置HTTP代理',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              title: Text('应用与外观', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/theme');
                  },
                  leading: const Icon(Icons.palette_rounded),
                  title: Text('外观设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('设置应用主题和刷新率',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/interface');
                  },
                  leading: const Icon(Icons.pages_rounded),
                  title: Text('界面设置', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('设置应用界面样式',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/bangumi');
                  },
                  leading: const Icon(Icons.sync_rounded),
                  title: Text('Bangumi 同步', style: TextStyle(fontFamily: fontFamily)),
                  description: Text('登录 Bangumi 并同步在看和已看状态',
                      style: TextStyle(fontFamily: fontFamily)),
                ),
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/webdav/');
                  },
                  leading: const Icon(Icons.cloud),
                  title: Text('同步设置', style: TextStyle(fontFamily: fontFamily)),
                  description:
                      Text('设置同步参数', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
            SettingsSection(
              title: Text('其他', style: TextStyle(fontFamily: fontFamily)),
              tiles: [
                SettingsTile.navigation(
                  onPressed: (_) {
                    Modular.to.pushNamed('/settings/about/');
                  },
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text('关于', style: TextStyle(fontFamily: fontFamily)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The same split list the settings page uses, at this page's card radius so
  /// the group sits level with the hero beside it.
  Widget _entryGroup(WatchStats stats) {
    return SettingsSplitGroup(
      outerRadius: _cardRadius,
      children: [
        SettingsCategoryTile(
          icon: Icons.history_rounded,
          title: '历史记录',
          description: stats.lastWatchName != null
              ? '最近看到 ${stats.lastWatchName}'
              : '还没有观看记录',
          onTap: () => context.pushNamed('/settings/history/'),
        ),
        SettingsCategoryTile(
          icon: Icons.download_rounded,
          title: '离线下载',
          description: '缓存任务与本地文件',
          onTap: () => context.pushNamed('/settings/download/'),
        ),
        SettingsCategoryTile(
          icon: Icons.settings_rounded,
          title: '设置',
          description: '播放、弹幕、外观与规则',
          onTap: () => context.pushNamed('/settings/'),
        ),
      ],
    );
  }
}

class _CollectHero extends StatelessWidget {
  const _CollectHero({required this.stats});

  final WatchStats stats;

  static const List<CollectType> _order = [
    CollectType.watching,
    CollectType.planToWatch,
    CollectType.onHold,
    CollectType.watched,
    CollectType.abandoned,
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final lastWatchTime = stats.lastWatchTime;
    final String caption = lastWatchTime == null
        ? '收藏番剧后会在这里汇总'
        : '最近观看 ${formatTimestampToRelativeTime(lastWatchTime.millisecondsSinceEpoch ~/ 1000)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '我的追番',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${stats.collectedCount}',
                  style: textTheme.displaySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: ' 部',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (stats.collectedCount > 0)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in _order)
                  if ((stats.collectCounts[type] ?? 0) > 0)
                    _CollectChip(
                      label: type.label,
                      count: stats.collectCounts[type]!,
                    ),
              ],
            ),
          if (stats.collectedCount > 0) const SizedBox(height: 12),
          Text(
            caption,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectChip extends StatelessWidget {
  const _CollectChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $count',
        style: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

