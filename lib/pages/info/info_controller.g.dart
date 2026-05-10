// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'info_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$InfoController on _InfoController, Store {
  late final _$isLoadingAtom =
      Atom(name: '_InfoController.isLoading', context: context);

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$pluginSearchResponseListAtom =
      Atom(name: '_InfoController.pluginSearchResponseList', context: context);

  @override
  ObservableList<PluginSearchResponse> get pluginSearchResponseList {
    _$pluginSearchResponseListAtom.reportRead();
    return super.pluginSearchResponseList;
  }

  @override
  set pluginSearchResponseList(ObservableList<PluginSearchResponse> value) {
    _$pluginSearchResponseListAtom
        .reportWrite(value, super.pluginSearchResponseList, () {
      super.pluginSearchResponseList = value;
    });
  }

  late final _$pluginSearchStatusAtom =
      Atom(name: '_InfoController.pluginSearchStatus', context: context);

  @override
  ObservableMap<String, String> get pluginSearchStatus {
    _$pluginSearchStatusAtom.reportRead();
    return super.pluginSearchStatus;
  }

  @override
  set pluginSearchStatus(ObservableMap<String, String> value) {
    _$pluginSearchStatusAtom.reportWrite(value, super.pluginSearchStatus, () {
      super.pluginSearchStatus = value;
    });
  }

  late final _$commentsListAtom =
      Atom(name: '_InfoController.commentsList', context: context);

  @override
  ObservableList<CommentItem> get commentsList {
    _$commentsListAtom.reportRead();
    return super.commentsList;
  }

  @override
  set commentsList(ObservableList<CommentItem> value) {
    _$commentsListAtom.reportWrite(value, super.commentsList, () {
      super.commentsList = value;
    });
  }

  late final _$characterListAtom =
      Atom(name: '_InfoController.characterList', context: context);

  @override
  ObservableList<CharacterItem> get characterList {
    _$characterListAtom.reportRead();
    return super.characterList;
  }

  @override
  set characterList(ObservableList<CharacterItem> value) {
    _$characterListAtom.reportWrite(value, super.characterList, () {
      super.characterList = value;
    });
  }

  late final _$staffListAtom =
      Atom(name: '_InfoController.staffList', context: context);

  @override
  ObservableList<StaffFullItem> get staffList {
    _$staffListAtom.reportRead();
    return super.staffList;
  }

  @override
  set staffList(ObservableList<StaffFullItem> value) {
    _$staffListAtom.reportWrite(value, super.staffList, () {
      super.staffList = value;
    });
  }

  late final _$relatedSubjectListAtom =
      Atom(name: '_InfoController.relatedSubjectList', context: context);

  @override
  ObservableList<BangumiSubjectRelation> get relatedSubjectList {
    _$relatedSubjectListAtom.reportRead();
    return super.relatedSubjectList;
  }

  @override
  set relatedSubjectList(ObservableList<BangumiSubjectRelation> value) {
    _$relatedSubjectListAtom.reportWrite(value, super.relatedSubjectList, () {
      super.relatedSubjectList = value;
    });
  }

  late final _$relatedSubjectsLoadingAtom =
      Atom(name: '_InfoController.relatedSubjectsLoading', context: context);

  @override
  bool get relatedSubjectsLoading {
    _$relatedSubjectsLoadingAtom.reportRead();
    return super.relatedSubjectsLoading;
  }

  @override
  set relatedSubjectsLoading(bool value) {
    _$relatedSubjectsLoadingAtom
        .reportWrite(value, super.relatedSubjectsLoading, () {
      super.relatedSubjectsLoading = value;
    });
  }

  late final _$syncedCollectTypeAtom =
      Atom(name: '_InfoController.syncedCollectType', context: context);

  @override
  int get syncedCollectType {
    _$syncedCollectTypeAtom.reportRead();
    return super.syncedCollectType;
  }

  @override
  set syncedCollectType(int value) {
    _$syncedCollectTypeAtom.reportWrite(value, super.syncedCollectType, () {
      super.syncedCollectType = value;
    });
  }

  late final _$userRatingAtom =
      Atom(name: '_InfoController.userRating', context: context);

  @override
  int? get userRating {
    _$userRatingAtom.reportRead();
    return super.userRating;
  }

  @override
  set userRating(int? value) {
    _$userRatingAtom.reportWrite(value, super.userRating, () {
      super.userRating = value;
    });
  }

  late final _$userCommentAtom =
      Atom(name: '_InfoController.userComment', context: context);

  @override
  String get userComment {
    _$userCommentAtom.reportRead();
    return super.userComment;
  }

  @override
  set userComment(String value) {
    _$userCommentAtom.reportWrite(value, super.userComment, () {
      super.userComment = value;
    });
  }

  late final _$userCommentPrivateAtom =
      Atom(name: '_InfoController.userCommentPrivate', context: context);

  @override
  bool get userCommentPrivate {
    _$userCommentPrivateAtom.reportRead();
    return super.userCommentPrivate;
  }

  @override
  set userCommentPrivate(bool value) {
    _$userCommentPrivateAtom.reportWrite(value, super.userCommentPrivate, () {
      super.userCommentPrivate = value;
    });
  }

  late final _$episodeProgressLoadingAtom =
      Atom(name: '_InfoController.episodeProgressLoading', context: context);

  @override
  bool get episodeProgressLoading {
    _$episodeProgressLoadingAtom.reportRead();
    return super.episodeProgressLoading;
  }

  @override
  set episodeProgressLoading(bool value) {
    _$episodeProgressLoadingAtom
        .reportWrite(value, super.episodeProgressLoading, () {
      super.episodeProgressLoading = value;
    });
  }

  late final _$episodeProgressTotalAtom =
      Atom(name: '_InfoController.episodeProgressTotal', context: context);

  @override
  int get episodeProgressTotal {
    _$episodeProgressTotalAtom.reportRead();
    return super.episodeProgressTotal;
  }

  @override
  set episodeProgressTotal(int value) {
    _$episodeProgressTotalAtom.reportWrite(value, super.episodeProgressTotal,
        () {
      super.episodeProgressTotal = value;
    });
  }

  late final _$episodeProgressWatchedAtom =
      Atom(name: '_InfoController.episodeProgressWatched', context: context);

  @override
  int get episodeProgressWatched {
    _$episodeProgressWatchedAtom.reportRead();
    return super.episodeProgressWatched;
  }

  @override
  set episodeProgressWatched(int value) {
    _$episodeProgressWatchedAtom
        .reportWrite(value, super.episodeProgressWatched, () {
      super.episodeProgressWatched = value;
    });
  }

  late final _$bangumiEpisodeListAtom =
      Atom(name: '_InfoController.bangumiEpisodeList', context: context);

  @override
  ObservableList<Map<String, dynamic>> get bangumiEpisodeList {
    _$bangumiEpisodeListAtom.reportRead();
    return super.bangumiEpisodeList;
  }

  @override
  set bangumiEpisodeList(ObservableList<Map<String, dynamic>> value) {
    _$bangumiEpisodeListAtom.reportWrite(value, super.bangumiEpisodeList, () {
      super.bangumiEpisodeList = value;
    });
  }

  late final _$bangumiEpisodesLoadingAtom =
      Atom(name: '_InfoController.bangumiEpisodesLoading', context: context);

  @override
  bool get bangumiEpisodesLoading {
    _$bangumiEpisodesLoadingAtom.reportRead();
    return super.bangumiEpisodesLoading;
  }

  @override
  set bangumiEpisodesLoading(bool value) {
    _$bangumiEpisodesLoadingAtom
        .reportWrite(value, super.bangumiEpisodesLoading, () {
      super.bangumiEpisodesLoading = value;
    });
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
pluginSearchResponseList: ${pluginSearchResponseList},
pluginSearchStatus: ${pluginSearchStatus},
commentsList: ${commentsList},
characterList: ${characterList},
staffList: ${staffList},
relatedSubjectList: ${relatedSubjectList},
relatedSubjectsLoading: ${relatedSubjectsLoading},
syncedCollectType: ${syncedCollectType},
userRating: ${userRating},
userComment: ${userComment},
userCommentPrivate: ${userCommentPrivate},
episodeProgressLoading: ${episodeProgressLoading},
episodeProgressTotal: ${episodeProgressTotal},
episodeProgressWatched: ${episodeProgressWatched},
bangumiEpisodeList: ${bangumiEpisodeList},
bangumiEpisodesLoading: ${bangumiEpisodesLoading}
    ''';
  }
}
