# 播放器：OP / ED 自动跳过

## 概述

为播放器引入"OP/ED 跳过"能力：每集进入 OP/ED 时间段时，在画面右下角浮出"跳过 OP →"按钮（5 秒倒计时），用户可主动点击或在设置里改成「自动跳过 / 仅提示 / 关闭」。数据来源优先取 [AniSkip](https://aniskip.com/)（社区共享标记），用户也可以在播放器面板里手动标记，自定义标记保存在本地 Hive 并可"应用到所有未标记的剧集"。

设计目标：
- 与现有「看过弹窗 / 自动记录」共用 `getPlayerTimer` 这条 1Hz tick，不新增播放循环
- 数据缓存与失败回退要让"无网状态 / AniSkip 没收录的番"也有路可走
- 一切改动可被开关关掉，保持播放器的"纯粹模式"可用

---

## 数据源

### AniSkip API

```
GET https://api.aniskip.com/v2/skip-times/{anilist_or_mal_id}/{episode_number}?types[]=op&types[]=ed&episodeLength={seconds}
```

响应（节选）：
```json
{
  "found": true,
  "results": [
    {
      "interval": { "startTime": 91.0, "endTime": 180.5 },
      "skipType": "op",
      "skipId": "abc-123",
      "episodeLength": 1432.0
    }
  ]
}
```

要点：
- `skipType` 取值 `op` / `ed` / `mixed-op` / `mixed-ed` / `recap`
- AniSkip 用 **MAL ID**（也接受 AniList ID），Bangumi 直接传 ID 命中率会很低
- Bangumi → MAL 映射：使用 [bangumi-data](https://github.com/bangumi-data/bangumi-data) 项目（每个 item 的 `sites` 字段含 `mal` / `bangumi`），或调用 Bangumi 自身的 `infobox`（含 "MAL_id"）。**MVP 优先走 Bangumi infobox，足够覆盖大部分主流番**
- 失败兜底：当 AniSkip 返回 `found: false`，仅用本地手动标记

### 本地手动标记

用户可在播放器面板长按"OP 起点 / OP 终点 / ED 起点 / ED 终点"4 个按钮（或菜单项），把当前播放时间记录为对应的边界。也可以"应用到本番剧所有未标记剧集"。

---

## 实现步骤

### 1. 新建 `lib/modules/skip/skip_marker.dart` — Hive 模型

```dart
@HiveType(typeId: <下一个未占用 id>)
class SkipMarker extends HiveObject {
  @HiveField(0) int subjectId;     // Bangumi subject id
  @HiveField(1) int episodeNumber; // 该番剧第几集（1-based）
  @HiveField(2) double? opStart;   // 秒
  @HiveField(3) double? opEnd;
  @HiveField(4) double? edStart;
  @HiveField(5) double? edEnd;
  @HiveField(6) String source;     // 'aniskip' | 'manual'
  @HiveField(7) DateTime updatedAt;

  String get key => '${subjectId}_$episodeNumber';
}
```

注册位置：
- `lib/modules/AGENTS.md` 提到的 typeId 表里追加一行
- `lib/utils/storage.dart` 新增 `static late Box<SkipMarker> skipMarkers`，在 `GStorage.init` 中 `openBox`
- 跑 `dart run build_runner build --delete-conflicting-outputs` 生成 `*.g.dart` 与 `hive_registrar.g.dart`

### 2. `lib/request/api.dart` — 新增端点常量

```dart
static const String aniSkipDomain = 'https://api.aniskip.com';
static const String aniSkipSkipTimes = '/v2/skip-times/{0}/{1}';
```

### 3. 新建 `lib/request/aniskip.dart` — AniSkip 客户端

```dart
class AniSkipHTTP {
  /// 拉取一集的跳过时间，未命中返回空列表
  static Future<List<SkipSegment>> getSkipTimes({
    required int malOrAniListId,
    required int episodeNumber,
    required int episodeLengthSeconds,
  }) async { ... }
}

class SkipSegment {
  final double startTime;
  final double endTime;
  final String skipType; // op / ed / recap / mixed-op / mixed-ed
}
```

### 4. `lib/request/bangumi.dart` — 增加 MAL ID 解析

```dart
/// 从 infobox 提取 MAL id；找不到返回 null
static Future<int?> getMalIdBySubject(int subjectId) async { ... }
```

实现：调用现有 `getBangumiInfoByID`，遍历 `infobox` 找 key 为 `MAL_id`、`其他链接` 等条目。

### 5. 新建 `lib/utils/skip_marker_service.dart` — 跳过标记协调器

单例，职责：
- `Future<SkipMarker?> resolve(int subjectId, int episodeNumber, int episodeLength)`：
  1. 命中本地 `manual` 直接返回
  2. 命中本地 `aniskip` 缓存返回
  3. 调 `BangumiHTTP.getMalIdBySubject` + `AniSkipHTTP.getSkipTimes`，写入缓存返回
- `Future<void> saveManual(SkipMarker marker)`
- `Future<void> applyToAllUnmarkedEpisodes(int subjectId, SkipMarker template, int totalEpisodes)`：把同番剧未标记的集自动套上同样区间（仅当 `manual` 来源）
- `Future<void> clear(int subjectId, {int? episodeNumber})`

放在 `lib/utils/` 与 `bangumi_sync_service.dart` 同级，符合 `lib/utils/AGENTS.md` 的「服务型协调器」定位。

### 6. `lib/utils/storage.dart` — 新增设置键

```dart
class SettingBoxKey {
  ...
  static const String
    skipOpEnabled = 'skipOpEnabled',          // bool
    skipEdEnabled = 'skipEdEnabled',          // bool
    skipMode = 'skipMode',                    // 'auto' | 'prompt' | 'off'
    skipPromptDuration = 'skipPromptDuration',// int 秒，默认 5
    skipOffsetStart = 'skipOffsetStart',      // double，提前/延后跳过开始（秒），默认 0
    skipOffsetEnd = 'skipOffsetEnd';          // double
}
```

### 7. `lib/pages/player/player_controller.dart` — 状态字段

```dart
@observable SkipMarker? currentSkipMarker;
@observable String? activeSkipType;        // 'op' | 'ed' | null（用于 UI 显示）
@observable int skipCountdownSeconds = 0;  // 倒计时显示
```

加载时机：在 `_syncBangumiProgressStateForCurrentEpisode` 同样的位置，新增 `_loadSkipMarkerForCurrentEpisode()`，调 `SkipMarkerService().resolve(...)`。换集时清空。

### 8. `lib/pages/player/player_item.dart` — 接入 1Hz tick

在 `getPlayerTimer` 的 `Timer.periodic` 内追加：

```dart
// 跳过 OP/ED 检测
final marker = playerController.currentSkipMarker;
if (marker != null && _skipMode != 'off') {
  final pos = playerController.currentPosition.inMilliseconds / 1000.0;
  final hit = _detectSkipHit(marker, pos); // 返回 'op' / 'ed' / null
  if (hit != null) {
    if (_skipMode == 'auto') {
      _seekToSegmentEnd(marker, hit); // 直接跳
    } else {
      // prompt 模式：露出按钮 + 倒计时
      playerController.activeSkipType = hit;
      _ensureSkipCountdown(); // 内部处理 5 秒后自动隐藏
    }
  } else {
    if (playerController.activeSkipType != null) {
      playerController.activeSkipType = null;
      _cancelSkipCountdown();
    }
  }
}
```

### 9. 新建 `lib/pages/player/skip_button.dart` — 浮动跳过按钮

`Observer` 包一个 `AnimatedSwitcher`，在 `playerController.activeSkipType != null` 时淡入到右下角（与现有控制按钮区域避让），点击后调 `_seekToSegmentEnd`，长按打开"标记区间编辑"sheet。

挂在 `player_item_panel.dart` / `smallest_player_item_panel.dart` 的浮层位置。

### 10. 新建 `lib/pages/player/skip_marker_sheet.dart` — 标记编辑面板

底部 sheet，内容：
- 当前 OP/ED 区间显示（文本框，可手动改时间）
- 4 个"使用当前时间作为起点/终点"按钮
- "应用到本番剧所有未标记剧集"复选 + 提交
- "清除本集 / 清除整部"按钮

通过播放器面板的「⋯ 更多」菜单或长按跳过按钮进入。

### 11. `lib/pages/settings/player_settings.dart` — 新增设置区块

新增"OP/ED 跳过"分组：
- 自动跳过模式：自动 / 仅提示 / 关闭
- 跳过 OP / 跳过 ED 双开关
- 提示窗显示秒数
- 起止偏移微调（高级折叠）
- "清除全部本地标记"按钮

设置项写入 `GStorage.setting`，沿用项目惯例。

---

## 数据流

```
切换到下一集
  → PlayerController._loadSkipMarkerForCurrentEpisode()
    → SkipMarkerService.resolve(subjectId, ep, length)
      → 本地 manual? 命中
      → 本地 aniskip 缓存? 命中
      → 调 Bangumi 获取 MAL id → AniSkip API → 落本地缓存
    → 写入 currentSkipMarker

播放 1Hz tick
  → 落入 OP/ED 区间且 mode != off
    → mode == auto: seek 到区间结束
    → mode == prompt: 露出浮动按钮 + 倒计时

用户点跳过 / 长按 → seek 到结束 / 打开标记编辑面板
用户手动标记 → SkipMarkerService.saveManual / applyToAllUnmarkedEpisodes
```

---

## 文件变更清单

| 文件 | 变更 | 说明 |
|------|------|------|
| `lib/modules/skip/skip_marker.dart` | 新建 | Hive 模型 |
| `lib/modules/skip/skip_marker.g.dart` | 自动生成 | build_runner 产物 |
| `lib/utils/storage.dart` | 修改 | 新增 box + 5 个 SettingBoxKey |
| `lib/request/api.dart` | 修改 | 新增 aniskip 域名/端点常量 |
| `lib/request/aniskip.dart` | 新建 | AniSkip 客户端 |
| `lib/request/bangumi.dart` | 修改 | `getMalIdBySubject` |
| `lib/utils/skip_marker_service.dart` | 新建 | 跳过协调单例 |
| `lib/pages/player/player_controller.dart` | 修改 | 3 个 observable + 加载入口 |
| `lib/pages/player/player_item.dart` | 修改 | tick 内集成跳过检测 + 设置读取 |
| `lib/pages/player/skip_button.dart` | 新建 | 浮动跳过按钮 |
| `lib/pages/player/skip_marker_sheet.dart` | 新建 | 标记编辑面板 |
| `lib/pages/player/player_item_panel.dart` | 修改 | 挂载 SkipButton + 「⋯」菜单加入入口 |
| `lib/pages/player/smallest_player_item_panel.dart` | 修改 | 挂载 SkipButton |
| `lib/pages/settings/player_settings.dart` | 修改 | 新增设置分组 |

---

## 架构决策

1. **数据源优先级**：本地 manual > 本地 aniskip 缓存 > 远程 AniSkip。Manual 永不被远程覆盖。
2. **MAL 映射策略**：MVP 用 Bangumi infobox 自带的 MAL id；命中失败的番直接退化为"仅手动标记"。后续可考虑预置 bangumi-data 静态映射表。
3. **UI 嵌入位置**：浮动按钮挂在播放器浮层，避免改控制面板树（符合 `lib/pages/player/AGENTS.md` 的「面板与渲染表面解耦」约定）。
4. **跨集复用**：手动标记加一个"应用到所有未标记剧集"动作，既保留集级精度，又能让用户一次性搞定整部番。
5. **不与 Bangumi 同步**：跳过标记是个人偏好，不上传 Bangumi（项目里 Bangumi 同步走 `BangumiSyncService`，避免在播放器里直发 HTTP）。

---

## 注意事项

- `skipPromptDuration` 期间倒计时要用 `Timer`，不要塞进 1Hz tick，避免 setState 抖动
- AniSkip 返回的 `episodeLength` 与本地 `playerDuration` 偏差超过 30 秒应**忽略远程标记**（说明不是同一版本）
- 番剧的剧场版/特别篇通常 AniSkip 没收录，UI 要把"未找到自动标记"以提示形式露出，引导用户手动标记
- typeId 务必查 `lib/modules/AGENTS.md` 现有占用，避免冲突
- 触发自动跳过那一刻，与现有「看过弹窗自动记录」可能在同一秒发生，注意先后顺序：**先跳过、后弹胶囊**（避免胶囊被立刻覆盖）
- syncplay 房间下要禁用自动跳过（其他人不一定想跳），保留手动按钮

---

## RELEASE_NOTES

合并到 main 时追加一行：

```
- 新增 OP/ED 自动跳过：支持 AniSkip 数据源与本地手动标记，可在「设置 → 播放器」切换自动跳过/仅提示/关闭
```
