import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_relation.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/utils/bangumi_auth.dart';
import 'package:kazumi/modules/bangumi/subject_relation.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/pages/info/rating_review_dialog.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:mobx/mobx.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/modules/staff/staff_item.dart';

part 'info_controller.g.dart';

class InfoController = _InfoController with _$InfoController;

abstract class _InfoController with Store {
  _InfoController(this.collectController);

  final CollectController collectController;
  late BangumiItem bangumiItem;

  @observable
  bool isLoading = false;

  @observable
  var pluginSearchResponseList = ObservableList<PluginSearchResponse>();

  @observable
  var pluginSearchStatus = ObservableMap<String, PluginSearchStatus>();

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
  var relationList = ObservableList<BangumiRelation>();

  @observable
  bool relationsIsLoading = false;

  @observable
  bool relationsQueryTimeout = false;

  @observable
  bool relationsHasLoaded = false;

  int _relationRequestGeneration = 0;

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

  int _commentsOffset = 0;

  void clearComments() {
    commentsList.clear();
    _commentsOffset = 0;
  }

  void _removeCurrentUserFromPublicComments() {
    final interest = bangumiItem.interest;
    if (interest == null) return;
    final userId = interest.user?.id;
    if (userId == null) return;
    commentsList.removeWhere((item) => item.user.id == userId);
  }

  bool _isFillingInterestUserProfile = false;

  Future<bool> fillInterestUserProfileIfNeeded() async {
    final interest = bangumiItem.interest;
    if (interest == null || interest.hasUserProfile) {
      return false;
    }
    if (_isFillingInterestUserProfile) {
      return false;
    }
    _isFillingInterestUserProfile = true;
    try {
      final user = await BangumiApi.getCurrentUser();
      if (user == null) {
        return false;
      }
      bangumiItem.interest = interest.copyWithUser(user: user);
      await collectController.updateLocalCollect(bangumiItem);
      return true;
    } catch (e) {
      KazumiLogger()
          .e('InfoController: failed to fill interest user profile', error: e);
      return false;
    } finally {
      _isFillingInterestUserProfile = false;
    }
  }

  @observable
  var bangumiEpisodeList = ObservableList<Map<String, dynamic>>();

  @observable
  bool bangumiEpisodesLoading = false;

  Future<void> queryBangumiInfoByID(int id, {String type = "init"}) async {
    isLoading = true;
    try {
      await _updateBangumiInfoByID(id, type: type);
    } finally {
      isLoading = false;
    }
  }

  Future<void> refreshBangumiInfoByID(int id) async {
    await _updateBangumiInfoByID(id, type: "update");
  }

  Future<void> _updateBangumiInfoByID(int id, {required String type}) async {
    final value = await BangumiApi.getBangumiInfoByID(id);
    if (value == null) {
      return;
    }
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
      final incomingInterest = value.interest;
      final previousInterest = bangumiItem.interest;
      if (incomingInterest == null) {
        bangumiItem.interest = null;
      } else if (previousInterest == null || !previousInterest.hasUserProfile) {
        bangumiItem.interest = incomingInterest;
      } else {
        bangumiItem.interest =
            incomingInterest.copyWithUser(user: previousInterest.user);
      }
    }
    await collectController.updateLocalCollect(bangumiItem);
  }

  Future<void> syncBangumiCollection() async {
    syncedCollectType =
        await collectController.syncBangumiCollectionType(bangumiItem) ?? 0;
    if (BangumiAuth.isLoggedIn) {
      final collection = await BangumiHTTP.getUserSubjectCollection(bangumiItem.id);
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
          await BangumiHTTP.getUserSubjectCollection(bangumiItem.id);
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
      await BangumiHTTP.updateUserRating(bangumiItem.id, rating);
      userRating = rating;
      KazumiDialog.showToast(message: '评分已更新');
    } catch (e) {
      KazumiDialog.showToast(message: 'Bangumi 评分更新失败 ${e.toString()}');
    }
  }

  Future<void> queryBangumiCommentsByID(int id, {bool refresh = true}) async {
    await _updateBangumiCommentsByID(
      id,
      refresh: refresh,
      clearBeforeFetch: true,
    );
  }

  Future<void> _updateBangumiCommentsByID(
    int id, {
    required bool refresh,
    required bool clearBeforeFetch,
  }) async {
    if (refresh) {
      if (clearBeforeFetch) {
        clearComments();
      }
    }
    final offset = refresh ? 0 : _commentsOffset;
    await BangumiApi.getBangumiCommentsByID(id, offset: offset).then((value) {
      if (refresh && !clearBeforeFetch) {
        commentsList = ObservableList<CommentItem>.of(value.commentList);
      } else {
        commentsList.addAll(value.commentList);
      }
      _commentsOffset = refresh
          ? value.commentList.length
          : _commentsOffset + value.commentList.length;
      _removeCurrentUserFromPublicComments();
    });
    KazumiLogger().i(
        'InfoController: loaded comments list length ${commentsList.length}, offset $_commentsOffset');
  }

  Future<void> refreshBangumiCommentsSilently(int id) async {
    if (commentsList.isEmpty) {
      return;
    }
    await _updateBangumiCommentsByID(
      id,
      refresh: true,
      clearBeforeFetch: false,
    );
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
      final progress = await BangumiHTTP.getEpisodeProgress(subjectId);
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
      await BangumiHTTP.batchUpdateEpisodeProgress(
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
      final episodes = await BangumiHTTP.getBangumiEpisodes(subjectId);
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
      final relations = await BangumiHTTP.getSubjectRelations(subjectId);
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

  void clearRelations() {
    relatedSubjectList.clear();
    relatedSubjectsLoading = false;
    _relationRequestGeneration++;
    relationList = ObservableList<BangumiRelation>();
    relationsIsLoading = false;
    relationsQueryTimeout = false;
    relationsHasLoaded = false;
  }

  Future<void> queryBangumiRelationsByID(int id) async {
    if (relationsIsLoading) return;

    final requestGeneration = ++_relationRequestGeneration;
    relationsIsLoading = true;
    relationsQueryTimeout = false;
    relationsHasLoaded = false;
    try {
      final relations = await BangumiApi.getBangumiRelationsByID(id);
      if (requestGeneration != _relationRequestGeneration) {
        return;
      }
      relationList = ObservableList<BangumiRelation>.of(relations);
      relationsHasLoaded = true;
      KazumiLogger().i(
        'InfoController: loaded related anime list length ${relationList.length}',
      );
    } catch (_) {
      if (requestGeneration == _relationRequestGeneration) {
        relationsQueryTimeout = true;
        rethrow;
      }
    } finally {
      if (requestGeneration == _relationRequestGeneration) {
        relationsIsLoading = false;
      }
    }
  }

  Future<bool> rateBangumi(RatingReviewResult data,
      {required int localType}) async {
    final trimmedComment = data.comment.trim();
    if (await BangumiApi.addOrUpdateBangumiEvaluationBySubjectID(
      bangumiItem.id,
      localType,
      comment: trimmedComment.isNotEmpty ? trimmedComment : null,
      rate: data.score > 0 ? data.score : 0,
      tags: data.tags.isNotEmpty ? data.tags : null,
    )) {
      userRating = data.score;
      userComment = trimmedComment;
      await refreshUserReview();
      await refreshBangumiCommentsSilently(bangumiItem.id);
      return true;
    }
    return false;
  }
}
