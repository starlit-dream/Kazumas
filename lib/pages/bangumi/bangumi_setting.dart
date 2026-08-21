import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/sync_priority.dart';
import 'package:kazumi/services/sync/bangumi_sync_service.dart';
import 'package:kazumi/utils/finish_review_trigger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:url_launcher/url_launcher.dart';

class BangumiEditorPage extends StatefulWidget {
  const BangumiEditorPage({super.key});

  @override
  State<BangumiEditorPage> createState() => _BangumiEditorPageState();
}

class _BangumiEditorPageState extends State<BangumiEditorPage> {
  final TextEditingController bangumiTokenController = TextEditingController();
  bool passwordVisible = false;
  bool isVerifying = false;
  late bool bangumiImmediateSyncToastEnable;
  late int syncPriority;
  late bool watchedPopupEnabled;
  late bool watchedAutoRecord;
  late double watchedAutoRecordThreshold;
  late bool finishReviewPopupEnabled;
  bool syncCollectiblesing = false;
  final MenuController syncPriorityMenuController = MenuController();

  @override
  void initState() {
    super.initState();
    bangumiTokenController.text =
        GStorage.getSetting(SettingsKeys.bangumiAccessToken);
    bangumiImmediateSyncToastEnable =
        GStorage.getSetting(SettingsKeys.bangumiImmediateSyncToastEnable);
    syncPriority = GStorage.getSetting(SettingsKeys.bangumiSyncPriority);
    watchedPopupEnabled =
        GStorage.getSetting(SettingsKeys.watchedPopupEnabled);
    watchedAutoRecord =
        GStorage.getSetting(SettingsKeys.watchedAutoRecord);
    watchedAutoRecordThreshold =
        GStorage.getSetting(SettingsKeys.watchedAutoRecordThreshold);
    finishReviewPopupEnabled =
        GStorage.getSetting(SettingsKeys.finishReviewPopupEnabled);
  }

  @override
  void dispose() {
    bangumiTokenController.dispose();
    super.dispose();
  }

  Future<void> updateSyncPriority(int value) async {
    await GStorage.putSetting(SettingsKeys.bangumiSyncPriority, value);
    if (!mounted) return;
    setState(() {
      syncPriority = value;
    });
  }

  Future<void> syncWithProgress() async {
    final syncEnable = GStorage.getSetting(SettingsKeys.bangumiSyncEnable);
    if (!syncEnable) {
      KazumiDialog.showToast(message: '请先开启 Bangumi 同步');
      return;
    }

    final progressDialogKey = GlobalKey<_BangumiSyncProgressDialogState>();

    try {
      setState(() {
        syncCollectiblesing = true;
      });

      KazumiDialog.show(
        clickMaskDismiss: false,
        builder: (context) =>
            _BangumiSyncProgressDialog(key: progressDialogKey),
      );

      final bangumi = BangumiSyncService();
      await bangumi.ping();
      await bangumi.syncCollectibles(
        onProgress: (message, current, total) {
          progressDialogKey.currentState?.update(
            total > 0 ? '$message ($current/$total)' : message,
            total > 0 ? (current / total).clamp(0.0, 1.0).toDouble() : null,
          );
        },
      );
    } catch (e) {
      KazumiDialog.showToast(message: 'Bangumi同步失败 $e');
    } finally {
      if (KazumiDialog.observer.hasKazumiDialog) {
        KazumiDialog.dismiss();
      }
      if (mounted) {
        setState(() {
          syncCollectiblesing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return PopScope(
      canPop: !syncCollectiblesing,
      child: Scaffold(
        appBar: const SysAppBar(title: Text('Bangumi 配置')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: SizedBox(
              width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
              child: Column(
                children: [
                  TextField(
                    controller: bangumiTokenController,
                    obscureText: !passwordVisible,
                    decoration: InputDecoration(
                      labelText: 'Bangumi Access Token',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            passwordVisible = !passwordVisible;
                          });
                        },
                        icon: Icon(passwordVisible
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSection(
                    title: Text('同步选项'),
                    margin: EdgeInsetsDirectional.zero,
                    tiles: [
                      SettingsTile.switchTile(
                        leading: Icons.notifications_active_rounded,
                        onToggle: (value) async {
                          bangumiImmediateSyncToastEnable =
                              value ?? !bangumiImmediateSyncToastEnable;
                          await GStorage.putSetting(
                            SettingsKeys.bangumiImmediateSyncToastEnable,
                            bangumiImmediateSyncToastEnable,
                          );
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        title: Text('即时同步提示'),
                        description: Text('点击追番按钮触发即时同步时显示提示框'),
                        initialValue: bangumiImmediateSyncToastEnable,
                      ),
                      SettingsTile(
                        leading: Icons.rule_rounded,
                        onPressed: (_) async {
                          if (syncPriorityMenuController.isOpen) {
                            syncPriorityMenuController.close();
                          } else {
                            syncPriorityMenuController.open();
                          }
                        },
                        title: Text('同步优先级'),
                        description: Text('当本地与 Bangumi 状态不一致时优先使用哪个状态'),
                        value: MenuAnchor(
                            consumeOutsideTap: true,
                            controller: syncPriorityMenuController,
                            builder: (context, controller, child) => Text(
                                BangumiSyncPriority.fromValue(syncPriority)
                                    .label),
                            menuChildren: [
                              for (final entry in BangumiSyncPriority.values)
                                MenuItemButton(
                                    requestFocusOnHover: false,
                                    onPressed: () =>
                                        updateSyncPriority(entry.value),
                                    child: Container(
                                        height: 48,
                                        constraints:
                                            BoxConstraints(minWidth: 112),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            entry.label,
                                            style: TextStyle(
                                              color: entry.value == syncPriority
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : null,
                                            ),
                                          ),
                                        )))
                            ]),
                      ),
                      SettingsTile.switchTile(
                        onToggle: (value) async {
                          watchedPopupEnabled =
                              value ?? !watchedPopupEnabled;
                          await GStorage.putSetting(
                            SettingsKeys.watchedPopupEnabled,
                            watchedPopupEnabled,
                          );
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        title: Text('观看进度弹窗',
                            style: TextStyle(fontFamily: fontFamily)),
                        description: Text('播放进度达到阈值时在播放器侧边弹出确认窗口', style: TextStyle(fontFamily: fontFamily)),
                        initialValue: watchedPopupEnabled,
                      ),
                      SettingsTile.switchTile(
                        onToggle: (value) async {
                          watchedAutoRecord =
                              value ?? !watchedAutoRecord;
                          await GStorage.putSetting(
                            SettingsKeys.watchedAutoRecord,
                            watchedAutoRecord,
                          );
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        title: Text('自动记录已看过',
                            style: TextStyle(fontFamily: fontFamily)),
                        description: Text('播放进度达到阈值后自动标记为已看过', style: TextStyle(fontFamily: fontFamily)),
                        initialValue: watchedAutoRecord,
                      ),
                      SettingsTile(
                        onPressed: (_) async {
                          final result = await showDialog<double>(
                            context: context,
                            builder: (context) {
                              double sliderValue = watchedAutoRecordThreshold * 100;
                              return StatefulBuilder(
                                builder: (context, setDialogState) {
                                  return AlertDialog(
                                    title: const Text('自动记录进度阈值'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('播放到 ${sliderValue.round()}% 时触发'),
                                        const SizedBox(height: 16),
                                        Slider(
                                          value: sliderValue,
                                          min: 50,
                                          max: 100,
                                          divisions: 10,
                                          label: '${sliderValue.round()}%',
                                          onChanged: (value) {
                                            setDialogState(() {
                                              sliderValue = value;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(null),
                                        child: const Text('取消'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(sliderValue / 100),
                                        child: const Text('确认'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                          if (result != null) {
                            watchedAutoRecordThreshold = result;
                            await GStorage.putSetting(
                              SettingsKeys.watchedAutoRecordThreshold,
                              watchedAutoRecordThreshold,
                            );
                            if (mounted) setState(() {});
                          }
                        },
                        title: Text('自动记录进度阈值',
                            style: TextStyle(fontFamily: fontFamily)),
                        description: Text('播放进度达到 ${(watchedAutoRecordThreshold * 100).round()}% 时自动标记为已看过', style: TextStyle(fontFamily: fontFamily)),
                      ),
                      SettingsTile.switchTile(
                        onToggle: (value) async {
                          finishReviewPopupEnabled =
                              value ?? !finishReviewPopupEnabled;
                          await GStorage.putSetting(
                            SettingsKeys.finishReviewPopupEnabled,
                            finishReviewPopupEnabled,
                          );
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        title: Text('看完弹评分短评',
                            style: TextStyle(fontFamily: fontFamily)),
                        description: Text('整部番剧最后一集播完后，弹出评分与短评窗口直接同步到 Bangumi',
                            style: TextStyle(fontFamily: fontFamily)),
                        initialValue: finishReviewPopupEnabled,
                      ),
                      SettingsTile(
                        leading: Icons.refresh_rounded,
                        onPressed: (_) async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('重置忽略列表'),
                              content: const Text(
                                  '将清空「不再提示这部」的番剧记录，下次看完最后一集时会重新弹出评分窗口。确定吗？'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(false),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(true),
                                  child: const Text('确认'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await FinishReviewTrigger.I.resetDismissed();
                            if (mounted) {
                              KazumiDialog.showToast(message: '已清空忽略列表');
                            }
                          }
                        },
                        title: Text('重置评价提示忽略列表',
                            style: TextStyle(fontFamily: fontFamily)),
                        description: Text('清空被「不再提示这部」标记过的番剧',
                            style: TextStyle(fontFamily: fontFamily)),
                      ),
                      SettingsTile(
                        leading: Icons.cloud_sync_rounded,
                        trailing: syncCollectiblesing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded),
                        onPressed: (_) async {
                          await syncWithProgress();
                        },
                        title: Text("立即同步状态"),
                        description: Text('同步状态不一致或仅存在于本地/远端的条目'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final url =
                          Uri.parse('https://next.bgm.tv/demo/access-token');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      } else {
                        KazumiDialog.showToast(message: '无法打开链接');
                      }
                    },
                    child: Text(
                      '你可以点击此处前往 Bangumi 生成 Access Token',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: isVerifying
              ? null
              : () async {
                  final token = bangumiTokenController.text.trim();
                  final bool bangumiSyncEnable =
                      GStorage.getSetting(SettingsKeys.bangumiSyncEnable);

                  if (token.isEmpty && bangumiSyncEnable) {
                    KazumiDialog.showToast(message: 'Access Token 不能为空');
                    return;
                  }
                  setState(() {
                    isVerifying = true;
                  });
                  await GStorage.putSetting(
                      SettingsKeys.bangumiAccessToken, token);
                  final bangumi = BangumiSyncService();

                  if (token.isEmpty) {
                    bangumi.reset();
                    KazumiDialog.showToast(message: 'Bangumi Token 为空，请检查');
                    if (!mounted) return;
                    setState(() {
                      isVerifying = false;
                    });
                    return;
                  }

                  KazumiDialog.showToast(message: '正在测试 Bangumi Token...');
                  try {
                    await bangumi.init();
                  } catch (e) {
                    KazumiDialog.showToast(message: '验证失败：${e.toString()}');
                    await GStorage.putSetting(
                        SettingsKeys.bangumiSyncEnable, false);
                    if (!mounted) return;
                    setState(() {
                      isVerifying = false;
                    });
                    return;
                  }

                  KazumiDialog.showToast(
                      message: '测试成功，用户名：${bangumi.username}');
                  if (!mounted) return;
                  setState(() {
                    isVerifying = false;
                  });
                },
          child: const Icon(Icons.save),
        ),
      ),
    );
  }
}

class _BangumiSyncProgressDialog extends StatefulWidget {
  const _BangumiSyncProgressDialog({super.key});

  @override
  State<_BangumiSyncProgressDialog> createState() =>
      _BangumiSyncProgressDialogState();
}

class _BangumiSyncProgressDialogState
    extends State<_BangumiSyncProgressDialog> {
  String _progressText = '准备同步 Bangumi 状态...';
  double? _progressValue;

  void update(String text, double? value) {
    if (!mounted) return;
    setState(() {
      _progressText = text;
      _progressValue = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bangumi 同步进行中',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(_progressText),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _progressValue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
