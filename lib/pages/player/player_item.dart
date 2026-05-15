import 'dart:async';
import 'dart:io';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:kazumi/pages/player/player_item_panel.dart';
import 'package:kazumi/pages/player/smallest_player_item_panel.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/pip_utils.dart';
import 'package:kazumi/utils/webdav.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:window_manager/window_manager.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/capsule_progress_popup.dart';
import 'package:kazumi/bean/widget/finish_review_sheet.dart';
import 'package:kazumi/utils/finish_review_trigger.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/pages/player/player_item_surface.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:kazumi/utils/audio_controller.dart';
import 'package:kazumi/utils/bangumi_auth.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';

class PlayerItem extends StatefulWidget {
  const PlayerItem({
    super.key,
    required this.openMenu,
    required this.locateEpisode,
    required this.changeEpisode,
    required this.onBackPressed,
    required this.keyboardFocus,
    required this.sendDanmaku,
    required this.showDanmakuDestinationPickerAndSend,
    required this.pauseForTimedShutdown,
    this.disableAnimations = false,
  });

  final VoidCallback openMenu;
  final VoidCallback locateEpisode;
  final Future<void> Function(int episode, {int currentRoad, int offset})
      changeEpisode;
  final void Function(BuildContext) onBackPressed;
  final void Function(String) sendDanmaku;
  final FocusNode keyboardFocus;
  final bool disableAnimations;
  final void Function(String) showDanmakuDestinationPickerAndSend;
  final VoidCallback pauseForTimedShutdown;

  @override
  State<PlayerItem> createState() => _PlayerItemState();
}

class _PlayerItemState extends State<PlayerItem>
    with
        WindowListener,
        WidgetsBindingObserver,
        SingleTickerProviderStateMixin {
  Box setting = GStorage.setting;
  final PlayerController playerController = Modular.get<PlayerController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  final CollectController collectController = Modular.get<CollectController>();
  final MyController myController = Modular.get<MyController>();
  final AudioController _audioController = AudioController();
  late Map<String, List<String>> keyboardShortcuts;
  late List<String> keyboardActionsNeedLongPress;
  late Map<String, void Function()> keyboardActions;

  // 1. 在看
  // 2. 想看
  // 3. 搁置
  // 4. 看过
  // 5. 抛弃
  late int collectType;
  late bool webDavEnable;
  late bool webDavEnableHistory;

  // 弹幕
  final _danmuKey = GlobalKey();
  late bool _border;
  late double _opacity;
  late double _fontSize;
  late double _danmakuArea;
  late bool _hideTop;
  late bool _hideBottom;
  late bool _hideScroll;
  late bool _massiveMode;
  late bool _danmakuColor;
  late bool _danmakuBiliBiliSource;
  late bool _danmakuGamerSource;
  late bool _danmakuDanDanSource;
  late double _danmakuDuration;
  late double _danmakuLineHeight;
  late int _danmakuFontWeight;
  late bool _danmakuUseSystemFont;
  late double _danmakuBorderSize;

  // 硬件解码
  late bool haEnable;
  late bool autoPlayNext;
  late bool backgroundPlayback;
  late bool brightnessVolumeGesture;
  bool _episodeWatchedReported = false;
  bool _episodeStateSyncing = false;
  bool _watchedPopupEnabled = true;
  bool _watchedAutoRecord = false;
  double _watchedAutoRecordThreshold = 0.9;
  // 胶囊弹窗由 _markEpisodeWatched() 在标记成功后自动弹出

  Timer? hideTimer;
  Timer? playerTimer;
  Timer? mouseScrollerTimer;
  Timer? hideVolumeUITimer;

  double lastVolume = 0;

  // 过渡动画控制器
  AnimationController? animationController;

  double lastPlayerSpeed = 1.0;
  int episodeNum = 0;
  bool? _lastPipPlaying;
  bool? _lastPipDanmakuEnabled;
  late mobx.ReactionDisposer _playerSizeListener;

  late mobx.ReactionDisposer _fullscreenListener;

  /// 处理 Android/iOS 应用后台或熄屏
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused &&
        !backgroundPlayback &&
        playerController.mediaPlayer != null &&
        playerController.playerPlaying) {
      try {
        await playerController.pause(enableSync: false);
      } catch (_) {}
      return;
    }
    try {
      if (playerController.playerPlaying) {
        playerController.danmakuController.resume();
      }
    } catch (_) {}
  }

  Future<void> _syncAndroidAutoEnterPIPSetting() async {
    if (!Platform.isAndroid) {
      return;
    }
    final bool autoEnterPIPEnabled = setting.get(
      SettingBoxKey.androidAutoEnterPIP,
      defaultValue: false,
    );
    try {
      await PipUtils.setAndroidAutoEnterPIPEnabled(autoEnterPIPEnabled);
    } catch (e) {
      KazumiLogger().w(
        'PlayerItem: failed to sync android auto enter pip setting',
        error: e,
      );
    }
  }

  Future<void> _syncAndroidPIPPlayerPageState(bool inPlayerPage) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await PipUtils.setAndroidPIPInPlayerPage(inPlayerPage);
    } catch (e) {
      KazumiLogger().w(
        'PlayerItem: failed to sync android pip player page state',
        error: e,
      );
    }
  }

  Future<void> _updateAndroidPIPActions({bool force = false}) async {
    if (!Platform.isAndroid) {
      return;
    }
    final bool playing = playerController.playing;
    final bool danmakuEnabled = playerController.danmakuOn;
    if (!force &&
        _lastPipPlaying == playing &&
        _lastPipDanmakuEnabled == danmakuEnabled) {
      return;
    }

    _lastPipPlaying = playing;
    _lastPipDanmakuEnabled = danmakuEnabled;
    await PipUtils.updateAndroidPIPActions(
      playing: playing,
      danmakuEnabled: danmakuEnabled,
      width: playerController.playerWidth,
      height: playerController.playerHeight,
    );
  }

  Future<void> _syncPIPAspectWhenVideoSizeReady() async {
    if (playerController.playerWidth <= 0 ||
        playerController.playerHeight <= 0) {
      return;
    }
    if (Platform.isAndroid) {
      await _updateAndroidPIPActions(force: true);
      return;
    }
    if (Utils.isDesktop() && videoPageController.isPip) {
      await PipUtils.enterDesktopPIPWindow(
        width: playerController.playerWidth,
        height: playerController.playerHeight,
      );
    }
  }

  void _loadShortcuts() {
    keyboardShortcuts = {};
    defaultShortcuts.forEach((key, defaultValue) {
      keyboardShortcuts[key] = setting
          .get('shortcut_$key', defaultValue: defaultValue)
          .cast<String>();
    });
  }

  void _initKeyboardActions() {
    //需要实现长按的功能列表。
    keyboardActionsNeedLongPress = ["forward"];
    //快捷键功能对应表
    keyboardActions = {
      'playorpause': () => playerController.playOrPause(),
      'forward': () async => handleShortcutForwardDown(),
      'rewind': () async => handleShortcutRewind(),
      'next': () async => handlePreNextEpisode('next'),
      'prev': () async => handlePreNextEpisode('prev'),
      'volumeup': () async => handleShortcutVolumeChange('up'),
      'volumedown': () async => handleShortcutVolumeChange('down'),
      'togglemute': () async => handleShortcutVolumeChange('mute'),
      'fullscreen': () => handleShortcutFullscreen(),
      'screenshot': () async => handleScreenshot(),
      'skip': () async => skipOP(),
      'exitfullscreen': () => handleShortcutExitFullscreen(),
      'toggledanmaku': () => handleDanmaku(),
      'speed1': () async => setPlaybackSpeed(1.0),
      'speed2': () async => setPlaybackSpeed(2.0),
      'speed3': () async => setPlaybackSpeed(3.0),
      'speedup': () async => handleSpeedChange('up'),
      'speeddown': () async => handleSpeedChange('down'),
      // 开始对应长按功能
      // 如需对应长按功能，例如对功能'func'对应长按，请分别添加'funcRepeat'和'funcUp'。
      'forwardRepeat': () async => handleShortcutForwardRepeat(),
      'forwardUp': () async => handleShortcutForwardUp(),
    };
  }

  //初始化播放器菜单
  void _initPlayerMenu() {
    Utils.initPlayerMenu(keyboardActions);
  }

  //销毁播放器菜单
  void _disposePlayerMenu() {
    Utils.disposePlayerMenu();
  }

  Future<void> _syncBangumiProgressStateForCurrentEpisode() async {
    if (_episodeStateSyncing ||
        !BangumiAuth.isLoggedIn ||
        videoPageController.isOfflineMode) {
      return;
    }
    _episodeStateSyncing = true;
    try {
      await collectController
          .syncBangumiCollectionType(videoPageController.bangumiItem);
      final episodeInfo = await BangumiApi.getBangumiEpisodeByID(
        videoPageController.bangumiItem.id,
        videoPageController.actualEpisodeNumber,
      );
      if (episodeInfo.id == 0) {
        return;
      }
      final remoteEpisodeType =
          await BangumiApi.getEpisodeCollectionType(episodeInfo.id);
      if (remoteEpisodeType == 2) {
        _episodeWatchedReported = true;
      }
    } catch (e) {
      KazumiLogger()
          .w('Bangumi: failed to sync episode progress state', error: e);
    } finally {
      _episodeStateSyncing = false;
    }
  }

  Future<void> _markEpisodeWatched() async {
    try {
      final episodeInfo = await BangumiApi.getBangumiEpisodeByID(
        videoPageController.bangumiItem.id,
        videoPageController.actualEpisodeNumber,
      );
      if (episodeInfo.id == 0) {
        return;
      }
      await collectController.markEpisodeWatchedIfNeeded(
        bangumiItem: videoPageController.bangumiItem,
        subjectId: videoPageController.bangumiItem.id,
        episodeId: episodeInfo.id,
      );
      // 标记成功后弹出胶囊确认窗口
      if (mounted && _watchedPopupEnabled) {
        showCapsuleWatchedConfirmation(
          context,
          episodeNumber: videoPageController.actualEpisodeNumber,
          infoController: null,
        );
      }
      _maybePromptFinishReview();
    } catch (e) {
      _episodeWatchedReported = false;
      KazumiLogger().w('Bangumi: failed to sync watched episode', error: e);
    }
  }

  /// 整部最后一集播完后，延迟弹出「评分 + 短评」sheet。
  /// 与胶囊弹窗串联：先让胶囊飞过去（约 3 秒），再弹评价 sheet。
  void _maybePromptFinishReview() {
    if (!mounted) return;
    final isSyncPlayConnected =
        playerController.syncplayController?.isConnected ?? false;
    if (isSyncPlayConnected) return;
    final currentRoadIndex = videoPageController.currentRoad;
    if (currentRoadIndex < 0 ||
        currentRoadIndex >= videoPageController.roadList.length) {
      return;
    }
    final episodes = videoPageController.roadList[currentRoadIndex].data.length;
    final shouldPrompt = FinishReviewTrigger.I.shouldPromptAfterEpisode(
      subjectId: videoPageController.bangumiItem.id,
      currentEpisode: videoPageController.currentEpisode,
      totalEpisodes: episodes,
    );
    if (!shouldPrompt) return;
    final subjectId = videoPageController.bangumiItem.id;
    FinishReviewTrigger.I.markPrompted(subjectId);
    final bangumiItem = videoPageController.bangumiItem;
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      showFinishReviewSheet(
        context,
        bangumiItem: bangumiItem,
        autoTriggered: true,
      );
    });
  }

  //快捷键按下
  bool handleShortcutDown(String keyLabel) {
    for (final entry in keyboardShortcuts.entries) {
      final func = entry.key;
      final keys = entry.value;
      if (keys.contains(keyLabel)) {
        final action = keyboardActions[func];
        if (action != null) {
          action();
          return true;
        }
      }
    }
    return false;
  }

  // 快捷键长按
  bool handleShortcutLongPress(String keyLabel, String mode) {
    for (final func in keyboardActionsNeedLongPress) {
      final keys = keyboardShortcuts[func];
      if (keys?.contains(keyLabel) == true) {
        final action = keyboardActions[func + mode];
        if (action != null) {
          action();
          return true;
        }
      }
    }
    return false;
  }

  //上一集下一集动作
  Future<void> handlePreNextEpisode(String direction) async {
    if (videoPageController.loading) return;
    final currentRoad = videoPageController.currentRoad;
    final episodes = videoPageController.roadList[currentRoad].data;
    int targetEpisode;
    if (direction == 'next') {
      targetEpisode = videoPageController.currentEpisode + 1;
    } else if (direction == 'prev') {
      targetEpisode = videoPageController.currentEpisode - 1;
    } else {
      return;
    }

    if (targetEpisode > episodes.length) {
      KazumiDialog.showToast(message: '已经是最新一集');
      return;
    }
    if (targetEpisode <= 0) {
      KazumiDialog.showToast(message: '已经是第一集');
      return;
    }

    final identifier =
        videoPageController.roadList[currentRoad].identifier[targetEpisode - 1];
    KazumiDialog.showToast(message: '正在加载$identifier');
    widget.changeEpisode(targetEpisode, currentRoad: currentRoad);
  }

  //快退快捷键动作
  Future<void> handleShortcutRewind() async {
    int skipTime = playerController.arrowKeySkipTime;
    int current = playerController.currentPosition.inSeconds;
    int targetPosition;

    targetPosition = current - skipTime;
    if (targetPosition < 0) targetPosition = 0;

    try {
      playerTimer?.cancel();
      await playerController.seek(Duration(seconds: targetPosition));
      playerTimer = getPlayerTimer();
    } catch (e) {
      KazumiLogger().e('PlayerController: seek failed', error: e);
    }
  }

  // 快进快捷键动作
  Future<void> handleShortcutForwardDown() async {
    lastPlayerSpeed = playerController.playerSpeed;
  }

  Future<void> handleShortcutForwardRepeat() async {
    final double defaultShortcutForwardPlaySpeed = setting
        .get(SettingBoxKey.defaultShortcutForwardPlaySpeed, defaultValue: 2.0);
    if (playerController.playerSpeed < defaultShortcutForwardPlaySpeed) {
      playerController.showPlaySpeed = true;
      setPlaybackSpeed(defaultShortcutForwardPlaySpeed);
    }
  }

  Future<void> handleShortcutForwardUp() async {
    int skipTime = playerController.arrowKeySkipTime;
    int current = playerController.currentPosition.inSeconds;
    int total = playerController.duration.inSeconds;
    int targetPosition;

    targetPosition = current + skipTime;
    if (targetPosition > total) targetPosition = total;
    if (playerController.showPlaySpeed) {
      playerController.showPlaySpeed = false;
      setPlaybackSpeed(lastPlayerSpeed);
    } else {
      try {
        playerTimer?.cancel();
        playerController.seek(Duration(seconds: targetPosition));
        playerTimer = getPlayerTimer();
      } catch (e) {
        KazumiLogger().e('PlayerController: seek failed', error: e);
      }
    }
  }

  //全屏快捷键动作
  void handleShortcutFullscreen() {
    if (!videoPageController.isPip) handleFullscreen();
  }

  //退出全屏快捷键动作
  void handleShortcutExitFullscreen() {
    if (videoPageController.isFullscreen && !Utils.isTablet()) {
      try {
        playerController.danmakuController.clear();
