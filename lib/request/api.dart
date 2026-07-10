import 'config/api_endpoints.dart';

export 'config/api_endpoints.dart';

class Api {
  static const String version = ApiEndpoints.version;
  static const String buildNumber = ApiEndpoints.buildNumber;
  static int get apiLevel => ApiEndpoints.apiLevel;
  static String get branchVersion => ApiEndpoints.branchVersion;
  static String get upstreamVersion => ApiEndpoints.upstreamVersion;
  static String get buildCommit => ApiEndpoints.buildCommit;
  static String get buildCommitShort => ApiEndpoints.buildCommitShort;
  static const String projectUrl = ApiEndpoints.projectUrl;
  static const String sourceUrl = ApiEndpoints.sourceUrl;
  static const String iconUrl = ApiEndpoints.iconUrl;
  static const String pluginShop = ApiEndpoints.pluginShop;
  static const String latestApp = ApiEndpoints.latestApp;
  static const String dandanIndex = ApiEndpoints.dandanIndex;
  static const String bangumiIndex = ApiEndpoints.bangumiIndex;
  static const String bangumiAPIDomain = ApiEndpoints.bangumiAPIDomain;
  static const String bangumiMyself = ApiEndpoints.bangumiMyself;
  static const String bangumiMyCollection = ApiEndpoints.bangumiMyCollection;
  static const String bangumiMyCollectionEpisodes =
      ApiEndpoints.bangumiMyCollectionEpisodes;
  static const String bangumiMyEpisodeCollection =
      ApiEndpoints.bangumiMyEpisodeCollection;
  static const String bangumiUserCollections =
      ApiEndpoints.bangumiUserCollections;
  static const String bangumiInfoByID = ApiEndpoints.bangumiInfoByID;
  static const String bangumiRankSearch = ApiEndpoints.bangumiRankSearch;
  static const String bangumiCharacterByID = ApiEndpoints.bangumiCharacterByID;
  static const String bangumiEpisodeByID = ApiEndpoints.bangumiEpisodeByID;
  static const String bangumiSubjectRelation =
      ApiEndpoints.bangumiSubjectRelation;
  static const String bangumiUsernameByToken =
      ApiEndpoints.bangumiUsernameByToken;
  static const String bangumiSetCollection = ApiEndpoints.bangumiSetCollection;
  static const String bangumiGetCollection = ApiEndpoints.bangumiGetCollection;

  static String formatUrl(String url, List<dynamic> params) {
    return ApiEndpoints.formatUrl(url, params);
  }
}
