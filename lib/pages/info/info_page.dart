import 'dart:io';
import 'dart:ui';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/info/rating_review_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/bean/widget/progress_editor.dart';
import 'package:kazumi/bean/widget/finish_review_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/utils/bangumi_auth.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:kazumi/pages/info/source_sheet.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/pages/info/info_tabview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/utils/device.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({
    super.key,
    required this.inputBangumiItem,
    required this.infoController,
    required this.pluginsController,
  });

  final BangumiItem inputBangumiItem;
  final InfoController infoController;
  final PluginsController pluginsController;

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> with TickerProviderStateMixin {
  static const List<String> _infoTabs = <String>[
    '概览',
    '吐槽',
    '角色',
    '关联',
    '制作人员',
  ];
  static const int _commentsTabIndex = 1;
  static const Duration _minimumBangumiInfoLoadingDuration =
      Duration(milliseconds: 600);

  /// Don't use modular singleton here. We may have multiple info pages.
  /// Use a new instance of InfoController for each info page.
  final InfoController infoController = InfoController();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PluginsController pluginsController = Modular.get<PluginsController>();
  final Box setting = GStorage.setting;
  late TabController sourceTabController;
  late TabController infoTabController;
  late bool showRating;
  late bool watchNow;

  bool commentsIsLoading = false;
  bool charactersIsLoading = false;
  bool commentsQueryTimeout = false;
  bool commentsIsEmpty = false;
  bool charactersQueryTimeout = false;
  bool charactersIsEmpty = false;
  bool staffIsLoading = false;
  bool staffQueryTimeout = false;
  bool staffIsEmpty = false;
  bool _showBangumiInfoSkeleton = false;
  int _fabTabIndex = 0;

  BangumiItem get inputBangumiIten => widget.inputBangumiItem;

  bool get _isShowingBangumiInfoSkeleton =>
      infoController.isLoading || _showBangumiInfoSkeleton;

  bool _needsBangumiInfoRefresh(BangumiItem bangumiItem) {
    final votesCount = bangumiItem.votesCount;
    final missingVoteDistribution =
        votesCount.isEmpty || bangumiItem.votes <= 0 || votesCount.length < 10;
    return bangumiItem.summary == '' || missingVoteDistribution;
  }

  Future<void> loadCharacters() async {
    if (charactersIsLoading) return;
    setState(() {
      charactersIsLoading = true;
      charactersQueryTimeout = false;
      charactersIsEmpty = false;
    });
    try {
      await infoController
          .queryBangumiCharactersByID(infoController.bangumiItem.id);
      if (mounted) {
        setState(() {
          charactersIsLoading = false;
          if (infoController.characterList.isEmpty) {
            charactersIsEmpty = true;
          }
        });
      }
    } catch (e) {
      KazumiLogger().e('InfoPage: failed to load characters', error: e);
      if (mounted) {
        setState(() {
          charactersIsLoading = false;
          charactersQueryTimeout = true;
        });
      }
    }
  }

  Future<void> loadStaff() async {
    if (staffIsLoading) return;
    setState(() {
      staffIsLoading = true;
      staffQueryTimeout = false;
      staffIsEmpty = false;
    });
    try {
      await infoController
          .queryBangumiStaffsByID(infoController.bangumiItem.id);
      if (mounted) {
        setState(() {
          staffIsLoading = false;
          if (infoController.staffList.isEmpty) {
            staffIsEmpty = true;
          }
        });
      }
    } catch (e) {
      KazumiLogger().e('InfoPage: failed to load staff', error: e);
      if (mounted) {
        setState(() {
          staffIsLoading = false;
          staffQueryTimeout = true;
        });
      }
    }
  }

  Future<void> loadRelations() async {
    try {
      await infoController
          .queryBangumiRelationsByID(infoController.bangumiItem.id);
    } catch (e) {
      KazumiLogger().e('InfoPage: failed to load relations', error: e);
    }
  }

  Future<void> loadMoreComments({bool loadMore = false}) async {
    if (commentsIsLoading) return;
    setState(() {
      commentsIsLoading = true;
      commentsQueryTimeout = false;
      commentsIsEmpty = false;
    });
    try {
      await infoController.queryBangumiCommentsByID(
          infoController.bangumiItem.id,
          refresh: !loadMore);
      if (mounted) {
        setState(() {
          commentsIsLoading = false;
          if (infoController.commentsList.isEmpty &&
              !(infoController.bangumiItem.interest?.hasReviewContent ??
                  false)) {
            commentsIsEmpty = true;
          }
        });
      }
    } catch (e) {
      KazumiLogger().e('InfoPage: failed to load comments', error: e);
      if (mounted) {
        setState(() {
          commentsIsLoading = false;
          commentsQueryTimeout = true;
        });
      }
    }
  }

  void onBangumiRatingTap() {
    final token =
        GStorage.getSetting(SettingsKeys.bangumiAccessToken).toString().trim();
    if (token.isEmpty) {
      KazumiDialog.showToast(message: '请先在同步设置中绑定你的 Bangumi 配置以发表吐槽');
      return;
    }
    final localType = infoController.collectController
        .getCollectType(infoController.bangumiItem);
    if (localType == 0) {
      KazumiDialog.showToast(message: '请先追番后再发表评价');
      return;
    }
    KazumiDialog.show(
      builder: (context) => RatingReviewDialog(
        bangumiItem: infoController.bangumiItem,
        onSubmit: (data) async {
          final updated =
              await infoController.rateBangumi(data, localType: localType);
          if (updated && mounted) {
            setState(() {});
          }
          return updated;
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    infoController.bangumiItem = inputBangumiIten;
    infoController.characterList.clear();
    infoController.clearComments();
    infoController.staffList.clear();
    infoController.clearRelations();
    infoController.pluginSearchResponseList.clear();
    // Search results can miss rating distribution or summaries, so fill those
    // fields without replacing image URLs that are already rendered.
    if (_needsBangumiInfoRefresh(infoController.bangumiItem)) {
      _showBangumiInfoSkeleton = true;
      queryBangumiInfoByID(
        infoController.bangumiItem.id,
        type: 'attach',
        enforceMinimumLoadingDuration: true,
      );
    }
    infoController.syncBangumiCollection().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
    infoController.queryRelatedSubjects(infoController.bangumiItem.id);
    if (BangumiAuth.isLoggedIn) {
      infoController.queryEpisodeProgress(infoController.bangumiItem.id);
      infoController.queryBangumiEpisodes(infoController.bangumiItem.id);
    }
    sourceTabController =
        TabController(length: pluginsController.pluginList.length, vsync: this);
    infoTabController = TabController(length: 5, vsync: this);
    showRating =
        GStorage.setting.get(SettingBoxKey.showRating, defaultValue: true);
    watchNow = setting.get(SettingBoxKey.watchNow, defaultValue: false);
    infoTabController.addListener(() {
      int index = infoTabController.index;
      if (index == 1 &&
          infoController.commentsList.isEmpty &&
          !commentsIsLoading &&
          !commentsIsEmpty &&
          !commentsQueryTimeout) {
        loadMoreComments();
      }
      if (index == 2 &&
          infoController.characterList.isEmpty &&
          !charactersIsLoading &&
          !charactersIsEmpty &&
          !charactersQueryTimeout) {
        loadCharacters();
      }
      if (index == 4 &&
          infoController.staffList.isEmpty &&
          !staffIsLoading &&
          !staffIsEmpty &&
          !staffQueryTimeout) {
        loadStaff();
      }
    });
  }

  Future<void> onCommentsTabSelected() async {
    final interest = infoController.bangumiItem.interest;
    final token =
        GStorage.getSetting(SettingsKeys.bangumiAccessToken).toString().trim();
    if (interest != null && token.isNotEmpty) {
      final updated = await infoController.fillInterestUserProfileIfNeeded();
      if (updated && mounted) {
        setState(() {});
      }
    }
    if (infoController.commentsList.isEmpty &&
        !commentsIsLoading &&
        !commentsIsEmpty &&
        !commentsQueryTimeout) {
      loadMoreComments();
    }
  }

  @override
  void dispose() {
    infoTabController.removeListener(onInfoTabChanged);
    infoTabController.removeListener(_syncFabTabIndex);
    infoTabController.animation?.removeListener(_syncFabTabIndex);
    infoController.characterList.clear();
    infoController.clearComments();
    infoController.staffList.clear();
    infoController.clearRelations();
    infoController.pluginSearchResponseList.clear();
    infoTabController.dispose();
    super.dispose();
  }

  Future<void> _openFinishReviewSheet() async {
    final submitted = await showFinishReviewSheet(
      context,
      bangumiItem: infoController.bangumiItem,
      autoTriggered: false,
    );
    if (submitted) {
      await infoController.refreshUserReview();
      if (mounted) setState(() {});
    }
  }

  void _showProgressEditor() {
    showModalBottomSheet(
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: (MediaQuery.sizeOf(context).height >=
                LayoutBreakpoint.compact['height']!)
            ? MediaQuery.of(context).size.height * 3 / 4
            : MediaQuery.of(context).size.height,
        maxWidth: (MediaQuery.sizeOf(context).width >=
                LayoutBreakpoint.medium['width']!)
            ? MediaQuery.of(context).size.width * 9 / 16
            : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      showDragHandle: true,
      context: context,
      builder: (context) {
        return ProgressEditor(
          infoController: infoController,
          episodeList: infoController.bangumiEpisodeList.toList(),
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() {});
    });
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: (MediaQuery.sizeOf(context).height >=
                LayoutBreakpoint.compact['height']!)
            ? MediaQuery.of(context).size.height * 3 / 4
            : MediaQuery.of(context).size.height,
        maxWidth: (MediaQuery.sizeOf(context).width >=
                LayoutBreakpoint.medium['width']!)
            ? MediaQuery.of(context).size.width * 9 / 16
            : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      showDragHandle: true,
      context: context,
      builder: (context) {
        return SourceSheet(
            tabController: sourceTabController, infoController: infoController);
      },
    );
  }

  Future<void> queryBangumiInfoByID(
    int id, {
    String type = "init",
    bool enforceMinimumLoadingDuration = false,
  }) async {
    final loadingStartedAt = DateTime.now();
    try {
      await infoController.queryBangumiInfoByID(id, type: type);
    } catch (e) {
      KazumiLogger()
          .e('InfoPage: failed to query bangumi info by ID', error: e);
    } finally {
      if (enforceMinimumLoadingDuration && mounted) {
        await _waitForMinimumBangumiInfoLoadingDuration(loadingStartedAt);
      }
      if (mounted) {
        setState(() {
          _showBangumiInfoSkeleton = false;
        });
      }
    }
  }

  Future<void> _waitForMinimumBangumiInfoLoadingDuration(
      DateTime loadingStartedAt) async {
    final elapsed = DateTime.now().difference(loadingStartedAt);
    final remaining = _minimumBangumiInfoLoadingDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  Future<void> _watchNow() async {
    final historyController = Modular.get<HistoryController>();
    final pluginList = pluginsController.pluginList.toList();
    final keyword = infoController.bangumiItem.nameCn.isEmpty
        ? infoController.bangumiItem.name
        : infoController.bangumiItem.nameCn;

    KazumiDialog.showLoading(
      msg: '正在搜索源...',
      barrierDismissible: true,
      onDismiss: () {},
    );

    final results = <PluginSearchResponse>[];

    await Future.wait(pluginList.map((plugin) async {
      try {
        final result = await plugin.queryBangumi(keyword, shouldRethrow: true);
        if (result.data.isNotEmpty) {
          pluginsController.validityTracker.markSearchValid(plugin.name);
          results.add(result);
        }
      } on CaptchaRequiredException {
      } on NoResultException {
      } on SearchErrorException {
      } catch (e) {}
    }));

    if (results.isEmpty || !mounted) {
      KazumiDialog.dismiss();
      if (!mounted) return;
      _showSourceSheet();
      return;
    }

    PluginSearchResponse? bestResult;
    final bangumiId = infoController.bangumiItem.id;
    for (final history in historyController.histories) {
      if (history.bangumiItem.id == bangumiId) {
        for (final result in results) {
          if (result.pluginName == history.adapterName) {
            bestResult = result;
            break;
          }
        }
        if (bestResult != null) break;
      }
    }

    bestResult ??= results.first;

    if (!mounted) return;

    KazumiDialog.dismiss();
    KazumiDialog.showLoading(
      msg: '获取线路中...',
      barrierDismissible: Utils.isDesktop(),
      onDismiss: () {
        videoPageController.cancelQueryRoads();
      },
    );

    final selected = bestResult;
    final plugin = pluginList.firstWhere((p) => p.name == selected.pluginName);
    final searchItem = selected.data.first;

    videoPageController.bangumiItem = infoController.bangumiItem;
    videoPageController.currentPlugin = plugin;
    videoPageController.title = searchItem.name;
    videoPageController.src = searchItem.src;

    try {
      await videoPageController.queryRoads(searchItem.src, plugin.name);
      KazumiDialog.dismiss();
      if (mounted) {
        await Modular.to.pushNamed('/video/');
      }
    } catch (_) {
      KazumiLogger().w('WatchNow: failed to query video playlist');
      KazumiDialog.dismiss();
      if (mounted) {
        KazumiDialog.showToast(message: '获取线路失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showWindowButton =
        GStorage.getSetting(SettingsKeys.showWindowButton);
    final bool showRatingFab = _fabTabIndex == _commentsTabIndex;
    return PopScope(
      canPop: true,
      child: DefaultTabController(
        length: _infoTabs.length,
        child: Scaffold(
          body: NestedScrollView(
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverOverlapAbsorber(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverAppBar.medium(
                    title: EmbeddedNativeControlArea(
                      child: dtb.DragToMoveArea(
                        child: Container(
                          width: double.infinity,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            infoController.bangumiItem.nameCn == ''
                                ? infoController.bangumiItem.name
                                : infoController.bangumiItem.nameCn,
                          ),
                        ),
                      ),
                    ),
                    automaticallyImplyLeading: false,
                    scrolledUnderElevation: 0.0,
                    leading: EmbeddedNativeControlArea(
                      child: IconButton(
                        onPressed: () {
                          context.maybePop();
                        },
                        icon: Icon(Icons.arrow_back),
                      ),
                    ),
                    actions: [
                      if (innerBoxIsScrolled)
                        EmbeddedNativeControlArea(
                          child: CollectButton(
                            bangumiItem: infoController.bangumiItem,
                            onCollectChanged:
                                infoController.updateCollectionType,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      EmbeddedNativeControlArea(
                        child: IconButton(
                          onPressed: () {
                            launchUrl(
                              Uri.parse(
                                  'https://bangumi.tv/subject/${infoController.bangumiItem.id}'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.open_in_browser_rounded),
                        ),
                      ),
                      if (!showWindowButton && isDesktop())
                        CloseButton(onPressed: () => windowManager.close()),
                      SizedBox(width: 8),
                    ],
                    toolbarHeight: (Platform.isMacOS && showWindowButton)
                        ? kToolbarHeight + 22
                        : kToolbarHeight,
                    stretch: true,
                    centerTitle: false,
                    expandedHeight: (Platform.isMacOS && showWindowButton)
                        ? 360 + kTextTabBarHeight + kToolbarHeight + 22
                        : 360 + kTextTabBarHeight + kToolbarHeight,
                    collapsedHeight: (Platform.isMacOS && showWindowButton)
                        ? kTextTabBarHeight +
                            kToolbarHeight +
                            MediaQuery.paddingOf(context).top +
                            22
                        : kTextTabBarHeight +
                            kToolbarHeight +
                            MediaQuery.paddingOf(context).top,
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: Observer(builder: (context) {
                        final showBangumiInfoSkeleton =
                            _isShowingBangumiInfoSkeleton;
                        return Stack(
                          children: [
                            // No background image when loading to make loading looks better
                            if (!showBangumiInfoSkeleton)
                              Positioned.fill(
                                bottom: kTextTabBarHeight,
                                child: IgnorePointer(
                                  child: _InfoHeaderBackground(
                                    imageUrl: infoController
                                            .bangumiItem.images['large'] ??
                                        '',
                                  ),
                                ),
                              ),
                            SafeArea(
                              bottom: false,
                              child: EmbeddedNativeControlArea(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, kToolbarHeight, 16, 0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Observer(builder: (context) {
                                          return BangumiInfoCardV(
                                            bangumiItem:
                                                infoController.bangumiItem,
                                            isLoading:
                                                showBangumiInfoSkeleton,
                                            showRating: showRating,
                                            userRating:
                                                infoController.userRating,
                                            isLoggedIn: BangumiAuth.isLoggedIn,
                                            onCollectChanged: infoController
                                                .updateCollectionType,
                                            onRatingChanged:
                                                infoController.updateUserRating,
                                          );
                                        }),
                                        // 进度条（仅登录态显示）
                                        if (BangumiAuth.isLoggedIn &&
                                            !showBangumiInfoSkeleton)
                                          Observer(builder: (context) {
                                            final total = infoController
                                                        .episodeProgressTotal >
                                                    0
                                                ? infoController
                                                    .episodeProgressTotal
                                                : 1;
                                            final watched = infoController
                                                .episodeProgressWatched;
                                            final progress = watched / total;
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 8),
                                              child: SizedBox(
                                                width: MediaQuery.of(context)
                                                            .size
                                                            .width >
                                                        950
                                                    ? 950
                                                    : MediaQuery.of(context)
                                                            .size
                                                            .width -
                                                        32,
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _showProgressEditor(),
                                                  child: Card(
                                                    elevation: 0,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest
                                                        .withValues(alpha: 0.6),
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 10),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .play_circle_outline,
                                                            size: 20,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .primary,
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    Text(
                                                                      '观看进度',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                        color: Theme.of(context)
                                                                            .colorScheme
                                                                            .onSurfaceVariant,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      '$watched / $total',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        color: Theme.of(context)
                                                                            .colorScheme
                                                                            .primary,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                    height: 4),
                                                                ClipRRect(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              3),
                                                                  child:
                                                                      LinearProgressIndicator(
                                                                    value:
                                                                        progress,
                                                                    minHeight:
                                                                        4,
                                                                    backgroundColor: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .surfaceContainerHighest,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Icon(
                                                            Icons.chevron_right,
                                                            size: 18,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        // 我的评价（仅登录态显示）
                                        if (BangumiAuth.isLoggedIn &&
                                            !showBangumiInfoSkeleton)
                                          Observer(builder: (context) {
                                            final hasRating =
                                                (infoController.userRating ??
                                                        0) >
                                                    0;
                                            final hasComment = infoController
                                                .userComment.isNotEmpty;
                                            final hasAny =
                                                hasRating || hasComment;
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 8),
                                              child: SizedBox(
                                                width: MediaQuery.of(context)
                                                            .size
                                                            .width >
                                                        950
                                                    ? 950
                                                    : MediaQuery.of(context)
                                                            .size
                                                            .width -
                                                        32,
                                                child: GestureDetector(
                                                  onTap: _openFinishReviewSheet,
                                                  child: Card(
                                                    elevation: 0,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest
                                                        .withValues(alpha: 0.6),
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 10),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            hasAny
                                                                ? Icons
                                                                    .rate_review_rounded
                                                                : Icons
                                                                    .edit_note_rounded,
                                                            size: 20,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .primary,
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    Text(
                                                                      hasAny
                                                                          ? '我的评价'
                                                                          : '写短评',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                        color: Theme.of(context)
                                                                            .colorScheme
                                                                            .onSurfaceVariant,
                                                                      ),
                                                                    ),
                                                                    if (hasRating)
                                                                      Text(
                                                                        '${infoController.userRating} / 10',
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color: Theme.of(context)
                                                                              .colorScheme
                                                                              .primary,
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                                if (hasComment) ...[
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  Text(
                                                                    infoController
                                                                        .userComment,
                                                                    maxLines: 2,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                  ),
                                                                ] else if (!hasRating) ...[
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  Text(
                                                                    '点击给这部番剧评分或留下短评',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Icon(
                                                            Icons.chevron_right,
                                                            size: 18,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    forceElevated: innerBoxIsScrolled,
                    bottom: TabBar(
                      controller: infoTabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      dividerHeight: 0,
                      tabs: _infoTabs.map((name) => Tab(text: name)).toList(),
                    ),
                  ),
                ),
              ];
            },
            body: Observer(builder: (context) {
              final showBangumiInfoSkeleton = _isShowingBangumiInfoSkeleton;
              return InfoTabView(
                tabController: infoTabController,
                bangumiItem: infoController.bangumiItem,
                commentsQueryTimeout: commentsQueryTimeout,
                commentsIsEmpty: commentsIsEmpty,
                charactersQueryTimeout: charactersQueryTimeout,
                charactersIsEmpty: charactersIsEmpty,
                staffQueryTimeout: staffQueryTimeout,
                staffIsEmpty: staffIsEmpty,
                loadMoreComments: loadMoreComments,
                loadCharacters: loadCharacters,
                loadStaff: loadStaff,
                commentsList: infoController.commentsList,
                commentsIsLoading: commentsIsLoading,
                onCommentsTabSelected: onCommentsTabSelected,
                characterList: infoController.characterList,
                staffList: infoController.staffList,
                relationList: infoController.relationList,
                relationsIsLoading: infoController.relationsIsLoading,
                relationsQueryTimeout: infoController.relationsQueryTimeout,
                relationsHasLoaded: infoController.relationsHasLoaded,
                loadRelations: loadRelations,
                isLoading: showBangumiInfoSkeleton,
                relatedSubjectList: infoController.relatedSubjectList,
                relatedSubjectsLoading: infoController.relatedSubjectsLoading,
              );
            }),
          ),
          floatingActionButton: GestureDetector(
            onLongPress: _showSourceSheet,
            child: FloatingActionButton.extended(
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('开始观看'),
              onPressed: () async {
                if (watchNow) {
                  await _watchNow();
                  return;
                }
                _showSourceSheet();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoHeaderBackground extends StatelessWidget {
  const _InfoHeaderBackground({
    required this.imageUrl,
  });

  static const double _downsample = 0.5;
  static const double _blurSigma = 15.0;
  static const double _opacity = 0.4;
  static const double _edgeBleed = 32.0;
  static const double _bottomFeatherHeight = 48.0;

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }

        final rasterWidth = width * _downsample;
        final rasterHeight = (height + _edgeBleed) * _downsample;

        final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.8, 1],
                  ).createShader(bounds);
                },
                child: Align(
                  alignment: Alignment.topCenter,
                  child: RepaintBoundary(
                    child: Transform.scale(
                      scale: 1 / _downsample,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.low,
                      child: SizedBox(
                        width: rasterWidth,
                        height: rasterHeight,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: _blurSigma * _downsample,
                            sigmaY: _blurSigma * _downsample,
                          ),
                          child: NetworkImgLayer(
                            src: imageUrl,
                            width: rasterWidth,
                            height: rasterHeight,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            filterQuality: FilterQuality.low,
                            color: Colors.white.withValues(alpha: _opacity),
                            colorBlendMode: BlendMode.modulate,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _bottomFeatherHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        backgroundColor.withValues(alpha: 0),
                        backgroundColor.withValues(alpha: 0.55),
                        backgroundColor,
                      ],
                      stops: const [0, 0.72, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
