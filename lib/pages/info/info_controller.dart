import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/utils/bangumi_auth.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/modules/bangumi/subject_relation.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/modules/staff/staff_item.dart';

part 'info_controller.g.dart';

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  final CollectController collectController = Modular.get<CollectController>();
  late BangumiItem bangumiItem;

  @observable
  bool isLoading = false;

  @observable
  var pluginSearchResponseList = ObservableList<PluginSearchResponse>();

  @observable
  var pluginSearchStatus = ObservableMap<String, String>();

  @observable
  var commentsList = ObservableList<CommentItem>();

  @observable
  var characterList = ObservableList<CharacterItem>();

  @observable
  var staffList = ObservableList<StaffFullItem>();

  @observable
  var relatedSubjectList = ObservableList<BangumiSubjectRelation>();

  @observable
  bool relatedSubjectsLoading = false;

  @observable
  int syncedCollectType = 0;

  @observable
  int? userRating;

  @observable
  String userComment = '';

  @observable
  bool userCommentPrivate = false;

  @observable
  bool episodeProgressLoading = false;

  @observable
  int episodeProgressTotal = 0;

  @observable
  int episodeProgressWatched = 0;

  /// episodeId -> type (0=未看, 2=已看)
  final ObservableMap<int, int> episodeProgressMap = ObservableMap<int, int>();

  @observable
  var bangumiEpisodeList = ObservableList<Map<String, dynamic>>();

  @observable
  bool bangumiEpisodesLoading = false;

  Future<void> queryBangumiInfoByID(int id, {String type = "init"}) async {
    isLoading = true;
    try {
      final value = await BangumiApi.getBangumiInfoByID(id);
      if (value != null) {
        if (type == "init") {
          bangumiItem = value;
        } else {
          bangumiItem.summary = value.summary;
          bangumiItem.tags = value.tags;
          bangumiItem.rank = value.rank;
          bangumiItem.airDate = value.airDate;
          bangumiItem.airWeekday = value.airWeekday;
          bangumiItem.alias = value.alias;
          bangumiItem.ratingScore = value.ratingScore;
          bangumiItem.votes = value.votes;
          bangumiItem.votesCount = value.votesCount;
        }
        collectController.updateLocalCollect(bangumiItem);
      }
    } finally {
      isLoading = false;
    }
  }

  Future<void> syncBangumiCollection() async {
    syncedCollectType =
        await collectController.syncBangumiCollectionType(bangumiItem) ?? 0;
    if (BangumiAuth.isLoggedIn) {
      final collection = await BangumiApi.getUserSubjectCollection(bangumiItem.id);
      userRating = collection?.rate;
      userComment = collection?.comment ?? '';
      userCommentPrivate = collection?.private ?? false;
    }
  }

  /// 重新拉取用户对当前条目的评分/短评/隐私设置（提交评价后调用以刷新 UI）。
  Future<void> refreshUserReview() async {
    if (!BangumiAuth.isLoggedIn) return;
    try {
      final collection =
          await BangumiApi.getUserSubjectCollection(bangumiItem.id);
      userRating = collection?.rate;
      userComment = collection?.comment ?? '';
      userCommentPrivate = collection?.private ?? false;
    } catch (e) {
      KazumiLogger().w('InfoController: failed to refresh user review',
          error: e);
    }
  }

  Future<void> updateCollectionType(int type) async {
    try {
      await collectController.addCollectAndSync(bangumiItem, type: type);
      syncedCollectType = collectController.getCollectType(bangumiItem);
    } catch (e) {
      KazumiDialog.showToast(message: 'Bangumi 收藏同步失败 ${e.toString()}');
    }
  }

  Future<void> updateUserRating(int rating) async {
    try {
      await BangumiApi.updateUserRating(bangumiItem.id, rating);
      userRating = rating;
      KazumiDialog.showToast(message: '评分已更新');
    } catch (e) {
      KazumiDialog.showToast(message: 'Bangumi 评分更新失败 ${e.toString()}');
    }
  }

  Future<void> queryBangumiCommentsByID(int id, {int offset = 0}) async {
    if (offset == 0) {
      commentsList.clear();
    }
    await BangumiApi.getBangumiCommentsByID(id, offset: offset).then((value) {
      commentsList.addAll(value.commentList);
    });
    KazumiLogger().i(
        'InfoController: loaded comments list length ${commentsList.length}');
  }

  Future<void> queryBangumiCharactersByID(int id) async {
    characterList.clear();
    await BangumiApi.getCharatersByBangumiID(id).then((value) {
      characterList.addAll(value.charactersList);
    });
    Map<String, int> relationValue = {
      '主角': 1,
      '配角': 2,
      '客串': 3,
    };

    try {
      characterList.sort((a, b) {
        int valueA = relationValue[a.relation] ?? 4;
        int valueB = relationValue[b.relation] ?? 4;
        return valueA.compareTo(valueB);
      });
    } catch (e) {
      KazumiDialog.showToast(message: '$e');
    }
    KazumiLogger().i(
        'InfoController: loaded character list length ${characterList.length}');
  }

  Future<void> queryBangumiStaffsByID(int id) async {
    staffList.clear();
    await BangumiApi.getBangumiStaffByID(id).then((value) {
      staffList.addAll(value.data);
    });
    KazumiLogger()
        .i('InfoController: loaded staff list length ${staffList.length}');
  }

  Future<void> queryEpisodeProgress(int subjectId) async {
    if (episodeProgressLoading) return;
    episodeProgressLoading = true;
    try {
      final progress = await BangumiApi.getEpisodeProgress(subjectId);
      if (progress != null) {
        episodeProgressMap.clear();
        for (final ep in progress.data) {
          episodeProgressMap[ep.episodeId] = ep.type;
        }
        episodeProgressTotal = progress.total;
        episodeProgressWatched = progress.watchedCount;
      }
    } catch (e) {
      KazumiLogger().e('InfoController: failed to load episode progress',
          error: e);
    } finally {
      episodeProgressLoading = false;
    }
  }

  Future<void> toggleEpisodeWatch({
    required int subjectId,
    required int episodeId,
    required bool watched,
  }) async {
    final type = watched ? 2 : 0;
    try {
      // Update locally first for responsiveness
      episodeProgressMap[episodeId] = type;
      if (watched) {
        episodeProgressWatched++;
      } else {
        episodeProgressWatched--;
      }
      if (episodeProgressWatched < 0) episodeProgressWatched = 0;

      // Sync to Bangumi
      await BangumiApi.batchUpdateEpisodeProgress(
        subjectId: subjectId,
        episodeIds: [episodeId],
        type: type,
      );

      // Also sync collection if needed
      if (BangumiAuth.isLoggedIn) {
        await collectController.markEpisodeWatchedIfNeeded(
          bangumiItem: bangumiItem,
          subjectId: subjectId,
          episodeId: episodeId,
        );
      }
    } catch (e) {
      // Revert on failure
      episodeProgressMap[episodeId] = watched ? 0 : 2;
      if (watched) {
        episodeProgressWatched--;
      } else {
        episodeProgressWatched++;
      }
      KazumiDialog.showToast(message: '剧集进度同步失败 ${e.toString()}');
    }
  }

  Future<void> queryBangumiEpisodes(int subjectId) async {
    if (bangumiEpisodesLoading) return;
    bangumiEpisodesLoading = true;
    try {
      final episodes = await BangumiApi.getBangumiEpisodes(subjectId);
      bangumiEpisodeList.clear();
      bangumiEpisodeList.addAll(
        episodes.map((ep) => {
              'id': ep.id,
              'sort': ep.episode,
              'name': ep.name,
              'name_cn': ep.nameCn,
              'type': ep.type,
            }),
      );
      if (episodeProgressTotal == 0) {
        episodeProgressTotal = episodes.length;
      }
      KazumiLogger().i(
          'InfoController: loaded ${episodes.length} bangumi episodes');
    } catch (e) {
      KazumiLogger().e('InfoController: failed to load episodes', error: e);
    } finally {
      bangumiEpisodesLoading = false;
    }
  }

  int _getRelationPriority(String relation) {
    switch (relation) {
      case '前传':
        return 1;
      case '续集':
        return 2;
      case '总集篇':
        return 3;
      case '衍生':
        return 4;
      case '动画':
      case '游戏':
        return 5;
      case '书籍':
      case '画集':
        return 6;
      case '原声集':
      case '片头曲':
      case '片尾曲':
      case '插入歌':
      case '角色歌':
        return 7;
      case '三次元':
      case '联动':
      case '角色出演':
        return 8;
      default:
        return 9;
    }
  }

  Future<void> queryRelatedSubjects(int subjectId) async {
    if (relatedSubjectsLoading) return;
    relatedSubjectsLoading = true;
    try {
      final relations = await BangumiApi.getSubjectRelations(subjectId);
      relations.sort((a, b) {
        final priorityA = _getRelationPriority(a.relation);
        final priorityB = _getRelationPriority(b.relation);
        return priorityA.compareTo(priorityB);
      });
      relatedSubjectList.clear();
      relatedSubjectList.addAll(relations);
      KazumiLogger().i(
          'InfoController: loaded ${relations.length} related subjects');
    } catch (e) {
      KazumiLogger().e('InfoController: failed to load related subjects', error: e);
    } finally {
      relatedSubjectsLoading = false;
    }
  }
}
