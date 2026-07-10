import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/dandan_credentials.dart';
import 'package:kazumi/utils/device.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({
    super.key,
    required this.controller,
  });

  final MyController controller;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final Box setting = GStorage.setting;
  MyController get myController => widget.controller;
  final List<String> exitBehaviorTitles = const [
    '退出 Kazumas',
    '最小化至托盘',
    '每次都询问'
  ];

  late bool autoUpdate;
  late int exitBehavior =
      setting.get(SettingBoxKey.exitBehavior, defaultValue: 2);
  double _cacheSizeMB = -1;

  String get _appVersionDisplay => '${Api.version}+${Api.buildNumber}';

  @override
  void initState() {
    super.initState();
    autoUpdate = setting.get(SettingBoxKey.autoUpdate, defaultValue: true);
    _getCacheSize();
  }

  void onBackPressed(BuildContext context) {
    if (KazumiDialog.observer.hasKazumiDialog) {
      KazumiDialog.dismiss();
    }
  }

  Future<Directory> _getCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    return Directory('${tempDir.path}/libCachedImageData');
  }

  Future<void> _getCacheSize() async {
    final cacheDir = await _getCacheDir();

    if (await cacheDir.exists()) {
      final totalSizeBytes = await _getTotalSizeOfFilesInDir(cacheDir);
      final totalSizeMB = totalSizeBytes / (1024 * 1024);
      if (mounted) {
        setState(() {
          _cacheSizeMB = totalSizeMB;
        });
      }
    } else if (mounted) {
      setState(() {
        _cacheSizeMB = 0.0;
      });
    }
  }

  Future<int> _getTotalSizeOfFilesInDir(Directory directory) async {
    final children = directory.listSync();
    int total = 0;

    try {
      for (final child in children) {
        if (child is File) {
          total += await child.length();
        } else if (child is Directory) {
          total += await _getTotalSizeOfFilesInDir(child);
        }
      }
    } catch (_) {}

    return total;
  }

  Future<void> _clearCache() async {
    final cacheDir = await _getCacheDir();
    await cacheDir.delete(recursive: true);
    _getCacheSize();
  }

  Future<void> _copyText(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    KazumiDialog.showToast(message: '$label 已复制');
  }

  void _showCacheDialog() {
    KazumiDialog.show(
      builder: (context) {
        return AlertDialog(
          title: const Text('缓存管理'),
          content: const Text('缓存主要是封面图片，清除后会重新下载。'),
          actions: [
            TextButton(
              onPressed: KazumiDialog.dismiss,
              child: Text(
                '取消',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _clearCache();
                } catch (_) {}
                KazumiDialog.dismiss();
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openExternal(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildCardSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, title),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Widget _buildVersionTile({
    required IconData icon,
    required String title,
    required String value,
    bool copyable = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
      trailing: copyable
          ? IconButton(
              tooltip: '复制',
              onPressed: () => _copyText(title, value),
              icon: const Icon(Icons.copy_rounded),
            )
          : null,
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.95),
              theme.colorScheme.surfaceContainerHigh,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/logo/logo_rounded.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kazumas',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '一个基于Kazumi的客户端，增加了部分新的功能。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '版本 $_appVersionDisplay',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: myController.checkUpdate,
                    icon: const Icon(Icons.system_update_alt_rounded),
                    label: const Text('检查更新'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _buildVersionTile(
              icon: Icons.new_releases_outlined,
              title: '构建标识',
              value: Api.branchVersion,
              copyable: true,
            ),
            const Divider(height: 1),
            _buildVersionTile(
              icon: Icons.cloud_sync_outlined,
              title: '上游版本号',
              value: Api.upstreamVersion,
              copyable: true,
            ),
            const Divider(height: 1),
            _buildVersionTile(
              icon: Icons.commit_rounded,
              title: '构建 Commit',
              value: Api.buildCommit,
              copyable: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSection(BuildContext context) {
    return _buildCardSection(
      context: context,
      title: '应用',
      children: [
        SwitchListTile.adaptive(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          secondary: const Icon(Icons.auto_awesome_rounded),
          title: const Text('自动更新'),
          subtitle: const Text('启动时自动检查更新'),
          value: autoUpdate,
          onChanged: (value) async {
            autoUpdate = value;
            await setting.put(SettingBoxKey.autoUpdate, value);
            if (mounted) {
              setState(() {});
            }
          },
        ),
        _buildActionTile(
          icon: Icons.article_outlined,
          title: '错误日志',
          subtitle: '查看运行日志',
          onTap: () {
            context.pushNamed('/settings/about/logs');
          },
        ),
        _buildActionTile(
          icon: Icons.cleaning_services_outlined,
          title: '清除缓存',
          subtitle: _cacheSizeMB == -1
              ? '正在统计…'
              : '当前 ${_cacheSizeMB.toStringAsFixed(2)}MB',
          trailing: const Icon(Icons.delete_outline_rounded),
          onTap: _showCacheDialog,
        ),
        _buildActionTile(
          icon: Icons.gavel_rounded,
          title: '开源许可证',
          subtitle: '查看依赖许可证',
          onTap: () {
            context.pushNamed('/settings/about/license');
          },
        ),
      ],
    );
  }

  Widget _buildLinkSection(BuildContext context) {
    return _buildCardSection(
      context: context,
      title: '链接',
      children: [
        _buildActionTile(
          icon: Icons.public_rounded,
          title: '项目主页',
          subtitle: Api.projectUrl,
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => _openExternal(Api.projectUrl),
        ),
        _buildActionTile(
          icon: Icons.code_rounded,
          title: '代码仓库',
          subtitle: Api.sourceUrl,
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => _openExternal(Api.sourceUrl),
        ),
        _buildActionTile(
          icon: Icons.palette_outlined,
          title: '图标作者',
          subtitle: 'Pixiv',
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => _openExternal(Api.iconUrl),
        ),
        _buildActionTile(
          icon: Icons.live_tv_rounded,
          title: '番剧索引',
          subtitle: 'Bangumi',
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => _openExternal(Api.bangumiIndex),
        ),
        _buildActionTile(
          icon: Icons.subtitles_rounded,
          title: '弹幕来源',
          subtitle: 'DanDanPlay · ${dandanCredentials['id']}',
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => _openExternal(Api.dandanIndex),
        ),
      ],
    );
  }

  Widget _buildDesktopSection(BuildContext context) {
    return _buildCardSection(
      context: context,
      title: '桌面',
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: const Icon(Icons.desktop_windows_outlined),
          title: const Text('关闭窗口时'),
          subtitle: const Text('设置桌面端默认行为'),
          trailing: PopupMenuButton<int>(
            initialValue: exitBehavior,
            onSelected: (value) async {
              exitBehavior = value;
              await setting.put(SettingBoxKey.exitBehavior, value);
              if (mounted) {
                setState(() {});
              }
            },
            itemBuilder: (context) => [
              for (int i = 0; i < exitBehaviorTitles.length; i++)
                PopupMenuItem<int>(
                  value: i,
                  child: Text(exitBehaviorTitles[i]),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(exitBehaviorTitles[exitBehavior]),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        onBackPressed(context);
      },
      child: Scaffold(
        appBar: const SysAppBar(title: Text('关于')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderCard(context),
                  const SizedBox(height: 20),
                  _buildAppSection(context),
                  const SizedBox(height: 20),
                  _buildLinkSection(context),
                  if (isDesktop()) ...[
                    const SizedBox(height: 20),
                    _buildDesktopSection(context),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
