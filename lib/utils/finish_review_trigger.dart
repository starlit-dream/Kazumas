import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/bangumi_auth.dart';
import 'package:kazumi/utils/storage.dart';

/// 看完整部番剧后弹「评分+短评」sheet 的触发判定。
///
/// 与 `BangumiSyncService` 风格一致——把「是否要弹」「为什么不弹」「忽略策略」
/// 集中到一个单例，避免在播放器与信息页里散落 if-else 链路。
class FinishReviewTrigger {
  FinishReviewTrigger._();
  static final FinishReviewTrigger instance = FinishReviewTrigger._();
  static FinishReviewTrigger get I => instance;

  /// 当前会话内被「下次再说」过的 subjectId，进程退出即清空。
  final Set<int> _sessionSnoozed = <int>{};

  Box get _setting => GStorage.setting;

  bool get _enabled =>
      _setting.get(SettingBoxKey.finishReviewPopupEnabled, defaultValue: true);

  Set<int> _readDismissed() {
    final raw = _setting.get(
      SettingBoxKey.finishReviewSkippedSubjects,
      defaultValue: const <int>[],
    );
    if (raw is List) {
      return raw.whereType<int>().toSet();
    }
    return <int>{};
  }

  Future<void> _writeDismissed(Set<int> ids) async {
    await _setting.put(
      SettingBoxKey.finishReviewSkippedSubjects,
      ids.toList(growable: false),
    );
  }

  /// 当前剧集播完后是否应弹评价 sheet。
  ///
  /// [currentEpisode] 与 [totalEpisodes] 都是 1-based / 计数语义；当且仅当
  /// 二者相等才视为"看完整部"。
  bool shouldPromptAfterEpisode({
    required int subjectId,
    required int currentEpisode,
    required int totalEpisodes,
  }) {
    if (!BangumiAuth.isLoggedIn) return false;
    if (!_enabled) return false;
    if (totalEpisodes <= 0 || currentEpisode != totalEpisodes) return false;
    if (_sessionSnoozed.contains(subjectId)) return false;
    if (_readDismissed().contains(subjectId)) return false;
    return true;
  }

  /// 用户「下次再说」：本次会话内不再弹（重启或换番剧后失效）。
  void snoozeForSession(int subjectId) {
    _sessionSnoozed.add(subjectId);
  }

  /// 用户「不再提示这部」：写入 Hive，跨会话生效。
  Future<void> dismissForever(int subjectId) async {
    final dismissed = _readDismissed();
    if (dismissed.add(subjectId)) {
      await _writeDismissed(dismissed);
    }
    _sessionSnoozed.add(subjectId);
  }

  /// 重置永久忽略列表（设置页给用户「改主意」的出口）。
  Future<void> resetDismissed() async {
    await _setting.delete(SettingBoxKey.finishReviewSkippedSubjects);
    _sessionSnoozed.clear();
  }

  /// 提交评价后清掉 session snooze，避免用户编辑过又被立刻再弹。
  void markPrompted(int subjectId) {
    _sessionSnoozed.add(subjectId);
  }
}
