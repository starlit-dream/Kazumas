# 看完弹「评分 + 短评」直接发 Bangumi

## 概述

在用户**完整看完一部番剧**（最后一集触发"已看"上报）时，自动弹出一个评分 + 短评 sheet，提交后直接 PATCH 到 Bangumi 的「我的收藏」字段（`rate` + `comment`）。

设计目标：
- 复用现有「看过弹窗 / 自动记录 / 胶囊确认」这条信号链，不在播放器里另起一套触发逻辑
- 最后一集弹一次（不是每集都弹）；用户取消后**当次播放不再骚扰**，但下次进入仍可从信息页主动召唤
- 信息页的"我的评价"卡片（如果存在）应同步显示已提交的评分/短评，并能再次编辑
- 用户没登录 Bangumi 时不显示，未把整部标为"在看 / 看过"时不强弹

---

## API

Bangumi 已开放：

```
PATCH /v0/users/-/collections/{subject_id}
Body: { "type": 2, "rate": 1-10, "comment": "...", "private": false, "tags": ["..."] }
```

任意字段可选。本功能主要用 `rate` + `comment`，`type=2`（看过）作为兜底（防止用户尚未标"看过"）。

现有 `BangumiHTTP.updateUserRating` 只发了 `rate`，需要扩展或新增方法支持 `comment` 与可选 `tags`。

获取当前已存在的评价（用于回显）：复用 `getUserSubjectCollection(subjectId)`，已返回 `BangumiSubjectCollection`，里面包含 `rate` / `comment` / `tags` / `private`。

---

## 实现步骤

### 1. `lib/request/bangumi.dart` — 扩展评价提交

新增（与 `updateUserRating` 并列）：

```dart
static Future<void> updateUserReview({
  required int subjectId,
  int? rating,             // 1-10，传 null 表示不改
  String? comment,         // 传 null 表示不改；空字符串表示清空
  List<String>? tags,
  bool? private,
  int? type,               // 通常一并传 2（看过）
}) async {
  final body = <String, dynamic>{};
  if (rating != null) body['rate'] = rating;
  if (comment != null) body['comment'] = comment;
  if (tags != null) body['tags'] = tags;
  if (private != null) body['private'] = private;
  if (type != null) body['type'] = type;

  await Request().patch(
    Api.formatUrl(Api.bangumiAPIDomain + Api.bangumiMyCollection, [subjectId]),
    data: body,
    options: _authOptions(),
    extra: {'customError': 'Bangumi 评价提交失败'},
    shouldRethrow: true,
  );
}
```

`updateUserRating` 可保留作为薄封装（内部转调 `updateUserReview`），避免破坏调用点。

### 2. `lib/utils/storage.dart` — 新增设置键

```dart
class SettingBoxKey {
  ...
  static const String
    finishReviewPopupEnabled = 'finishReviewPopupEnabled', // bool, default true
    finishReviewSkippedSubjects = 'finishReviewSkippedSubjects'; // List<int>，本地"已忽略"
}
```

`finishReviewSkippedSubjects` 存"用户主动选了'下次再说'"的 subject id，避免重复弹。

### 3. 新建 `lib/bean/widget/finish_review_sheet.dart` — 评价底部弹窗

`showModalBottomSheet` 风格，复用项目现有 sheet 视觉。结构：

- 顶部缩略：番剧封面 + 标题
- 评分：1-10 颗星（或 1-10 横向数字按钮，与 Bangumi 评分制保持一致）
- 短评：多行文本框，max 380 字（Bangumi 限制）
- 「设为不公开」开关
- 三个按钮：「提交」「下次再说」「不再提示这部」

提交逻辑：
```dart
await BangumiHTTP.updateUserReview(
  subjectId: subjectId,
  rating: rating,
  comment: comment.trim().isEmpty ? null : comment.trim(),
  type: 2,
  private: isPrivate,
);
KazumiDialog.showToast(message: '已提交到 Bangumi');
```

回显：进入时先 `BangumiHTTP.getUserSubjectCollection(subjectId)` 拿当前 rate/comment 预填。

### 4. `lib/utils/finish_review_trigger.dart` — 触发判定单例

集中判定逻辑，避免散落到播放器与信息页：

```dart
class FinishReviewTrigger {
  static FinishReviewTrigger get I => ...;

  /// 判断当前剧集播完后是否应弹评价
  bool shouldPromptAfterEpisode({
    required int subjectId,
    required int currentEpisode,
    required int totalEpisodes,
  });

  /// 用户选择"下次再说"——本次会话内不再弹，关闭
  void snoozeForSession(int subjectId);

  /// 用户选择"不再提示这部"——写入 finishReviewSkippedSubjects
  Future<void> dismissForever(int subjectId);
}
```

判定规则：
1. `BangumiAuth.isLoggedIn == true`
2. `setting.get(SettingBoxKey.finishReviewPopupEnabled, true) == true`
3. `currentEpisode == totalEpisodes`（最后一集）
4. `finishReviewSkippedSubjects` 不含该 subjectId
5. 当前会话还未对该 subjectId 弹过（内存 set）
6. 番剧的 `total_episodes` > 1（避免单集剧场版/SP 也弹；可选）

### 5. `lib/pages/player/player_item.dart` — 接入触发

在现有 `_markEpisodeWatched()` 成功之后追加：

```dart
if (mounted &&
    FinishReviewTrigger.I.shouldPromptAfterEpisode(
      subjectId: videoPageController.bangumiItem.id,
      currentEpisode: videoPageController.actualEpisodeNumber,
      totalEpisodes: videoPageController.bangumiItem.totalEpisodes,
    )) {
  // 让胶囊先飞过去（约 3 秒后再弹评价 sheet，避免堆叠）
  Future.delayed(const Duration(seconds: 3), () {
    if (!mounted) return;
    showFinishReviewSheet(
      context,
      bangumiItem: videoPageController.bangumiItem,
    );
  });
}
```

注意：保留现有胶囊弹窗逻辑不动，本功能只在它之后追加一个**最后一集**的二级弹窗。

### 6. `lib/pages/info/info_tabview.dart` 或现有"我的评价"位置 — 入口按钮

信息页里加一个「写短评」/「编辑评价」按钮（仅登录态显示）：
- 已有评价：显示当前评分 + 一行短评摘要，点击弹同一个 `showFinishReviewSheet`
- 没有评价：显示"写短评"按钮，点击弹空白 sheet

按钮颜色与 `BangumiInfoCardV` 现有 CTA 协调。

### 7. `lib/pages/bangumi/bangumi_setting.dart` — 设置开关

在 `watchedPopupEnabled` 那个区域附近，再加一行：

> 看完弹评分短评（仅最后一集触发）

绑定 `SettingBoxKey.finishReviewPopupEnabled`，与「看过弹窗」「自动记录」三者并列。

提供「重置已忽略列表」按钮，清空 `finishReviewSkippedSubjects`，给改主意的用户一条出路。

---

## 数据流

```
最后一集播完 → _episodeWatchedReported = true → _markEpisodeWatched
  → BangumiHTTP.markEpisodeWatched 成功
  → 胶囊弹窗（既有）
  → FinishReviewTrigger.shouldPromptAfterEpisode == true
     → 延迟 3s 弹 FinishReviewSheet
        ├ 提交 → BangumiHTTP.updateUserReview → 本地 BangumiSubjectCollection 缓存刷新
        ├ 下次再说 → snoozeForSession（仅当次会话）
        └ 不再提示这部 → dismissForever（写 Hive）

信息页主动入口（不依赖播放器）
  → 读取已有 collection（rate/comment）
  → 同一个 FinishReviewSheet
  → 提交后局部刷新信息页
```

---

## 文件变更清单

| 文件 | 变更 | 说明 |
|------|------|------|
| `lib/request/bangumi.dart` | 修改 | 新增 `updateUserReview`，`updateUserRating` 改为薄封装 |
| `lib/utils/storage.dart` | 修改 | 新增 2 个 SettingBoxKey |
| `lib/utils/finish_review_trigger.dart` | 新建 | 触发判定单例 |
| `lib/bean/widget/finish_review_sheet.dart` | 新建 | 评分 + 短评 sheet 与 `showFinishReviewSheet` |
| `lib/pages/player/player_item.dart` | 修改 | `_markEpisodeWatched` 之后接入触发 |
| `lib/pages/info/info_tabview.dart` | 修改 | 新增 / 复用「我的评价」入口 |
| `lib/pages/info/info_controller.dart` | 修改（可选） | 暴露当前用户 collection 状态供卡片回显 |
| `lib/pages/bangumi/bangumi_setting.dart` | 修改 | 新增「看完弹评分短评」开关 + 重置忽略列表 |

---

## 架构决策

1. **触发集中在 `FinishReviewTrigger`**：不在播放器里写 if-else 链，与 `BangumiSyncService` 风格一致（"播放器不直发 Bangumi HTTP"）。
2. **延迟 3 秒再弹**：避免与既有胶囊"已标记看过"叠加；3 秒和胶囊的自动消失时间一致，体感是"胶囊飞走 → 评价 sheet 接力"。
3. **信息页与播放器共用同一个 sheet**：避免两套 UI；`showFinishReviewSheet` 只接 `BangumiItem`，是否回显由 sheet 内部自取 collection。
4. **Snooze 分两层**：会话内 snooze（内存）+ 永久 dismiss（Hive）。会话级避免"用户取消后退出又进来又被弹"，永久级让"反正不评分"的用户彻底解脱。
5. **不修改既有「看过弹窗 / 自动记录」**：本功能是"最后一集附加层"，与既有胶囊正交，关闭"看完弹评分"不影响其他 Bangumi 同步行为。

---

## 注意事项

- Bangumi 短评长度上限实测约 380 字（汉字按 1 计），UI 要做字符计数与 maxLength
- 提交评分时同时提交 `type: 2` 是为了兼容用户尚未把番剧本身标为"看过"的情况；不要漏
- `finishReviewSkippedSubjects` 用 `List<int>` 即可，不需要单独建 typed Hive box
- `actualEpisodeNumber == totalEpisodes` 的判定要用 `BangumiItem.totalEpisodes`；分多季的番剧本身就只有"本季总集数"，符合直觉
- 若该 subjectId 已经有 rate/comment（非首次评价），sheet 标题改为「更新我的评价」，按钮为「保存」
- 信息页入口在用户未登录时隐藏；已登录但 collection 为空时也允许写（首次）
- 与 syncplay 同步观看模式叠加时，仅"房主 / 主控"端弹（避免房间所有人都弹）；可通过 `playerController.isSyncPlayHost` 一类字段判断
- 该改动属于「Bangumi 核心模块的用户可感知行为变化」，**必须**追加 `RELEASE_NOTES.md`

---

## RELEASE_NOTES

合并到 main 时追加：

```
- 新增「看完弹评分短评」：整部番剧最后一集播完后，可一键提交评分与短评到 Bangumi；信息页也提供主动入口
```
