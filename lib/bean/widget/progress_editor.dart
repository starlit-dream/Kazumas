import 'package:flutter/material.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/bangumi_auth.dart';

class ProgressEditor extends StatefulWidget {
  final InfoController infoController;
  final List<Map<String, dynamic>> episodeList;

  const ProgressEditor({
    super.key,
    required this.infoController,
    required this.episodeList,
  });

  @override
  State<ProgressEditor> createState() => _ProgressEditorState();
}

class _ProgressEditorState extends State<ProgressEditor> {
  bool get isLoggedIn => BangumiAuth.isLoggedIn;
  bool _selectAllMode = false;

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                '请先登录 Bangumi 以同步观看进度',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    if (widget.episodeList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('暂无剧集数据')),
      );
    }

    final watchedCount = widget.infoController.episodeProgressWatched;
    final totalCount = widget.infoController.episodeProgressTotal > 0
        ? widget.infoController.episodeProgressTotal
        : widget.episodeList.length;
    final progress = totalCount > 0 ? watchedCount / totalCount : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '观看进度',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '$watchedCount / $totalCount 集',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _selectAllMode
                        ? _markAllAsUnwatched
                        : _markAllAsWatched,
                    icon: Icon(
                      _selectAllMode
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 18,
                    ),
                    label: Text(_selectAllMode ? '全部标记未看' : '全部标记已看'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Episode list
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.episodeList.length,
            itemBuilder: (context, index) {
              final episode = widget.episodeList[index];
              final episodeId = episode['id'] as int? ?? 0;
              final sort = episode['sort'] ?? (index + 1);
              final episodeName = (episode['name_cn'] ?? episode['name'] ?? '')
                  .toString();
              final epType = episode['type'] as int? ?? 0;
              final isWatched =
                  widget.infoController.episodeProgressMap[episodeId] == 2;

              // Skip non-EP types (SP, OP, ED) or show them as different
              if (epType != 0 && epType != 1) return const SizedBox.shrink();

              return ListTile(
                dense: true,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isWatched
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      epType == 1 ? 'SP' : '$sort',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isWatched
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  episodeName.isNotEmpty ? episodeName : '第 $sort 集',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    decoration: isWatched ? TextDecoration.lineThrough : null,
                    color: isWatched
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
                trailing: IconButton(
                  onPressed: () {
                    widget.infoController.toggleEpisodeWatch(
                      subjectId: widget.infoController.bangumiItem.id,
                      episodeId: episodeId,
                      watched: !isWatched,
                    );
                    setState(() {});
                  },
                  icon: Icon(
                    isWatched
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isWatched
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _markAllAsWatched() {
    final ids = <int>[];
    for (final ep in widget.episodeList) {
      final id = ep['id'] as int? ?? 0;
      if (id > 0) {
        ids.add(id);
      }
    }
    if (ids.isEmpty) return;
    _batchUpdate(ids, true);
    setState(() => _selectAllMode = true);
  }

  void _markAllAsUnwatched() {
    final ids = <int>[];
    for (final ep in widget.episodeList) {
      final id = ep['id'] as int? ?? 0;
      if (id > 0) {
        ids.add(id);
      }
    }
    if (ids.isEmpty) return;
    _batchUpdate(ids, false);
    setState(() => _selectAllMode = false);
  }

  void _batchUpdate(List<int> ids, bool watched) async {
    final type = watched ? 2 : 0;
    try {
      // Local update
      for (final id in ids) {
        widget.infoController.episodeProgressMap[id] = type;
      }
      widget.infoController.episodeProgressWatched =
          watched ? ids.length : 0;

      // Sync to Bangumi
      await BangumiHTTP.batchUpdateEpisodeProgress(
        subjectId: widget.infoController.bangumiItem.id,
        episodeIds: ids,
        type: type,
      );
    } catch (e) {
      // Revert
      for (final id in ids) {
        widget.infoController.episodeProgressMap[id] = watched ? 0 : 2;
      }
      widget.infoController.episodeProgressWatched =
          watched ? 0 : ids.length;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量更新失败: $e')),
        );
      }
    }
  }
}
