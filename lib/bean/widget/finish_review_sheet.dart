import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_auth_models.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/bangumi_auth.dart';
import 'package:kazumi/utils/finish_review_trigger.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/constants.dart';

/// 弹出「评分 + 短评」底部 sheet，提交后直接 PATCH 到 Bangumi。
///
/// [autoTriggered] 表示这次是「看完最后一集自动弹出的」——会显示「下次再说」/
/// 「不再提示这部」按钮。手动从信息页打开时设为 false，仅显示「保存」/「取消」。
///
/// 返回值：用户成功提交评价时为 true，其他情况（取消/snooze/dismiss）为 false。
Future<bool> showFinishReviewSheet(
  BuildContext context, {
  required BangumiItem bangumiItem,
  bool autoTriggered = false,
}) async {
  if (!BangumiAuth.isLoggedIn) {
    KazumiDialog.showToast(message: '请先登录 Bangumi');
    return false;
  }
  final result = await showModalBottomSheet<bool>(
    context: context,
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
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FinishReviewSheet(
          bangumiItem: bangumiItem,
          autoTriggered: autoTriggered,
        ),
      );
    },
  );
  return result == true;
}

class FinishReviewSheet extends StatefulWidget {
  final BangumiItem bangumiItem;
  final bool autoTriggered;

  const FinishReviewSheet({
    super.key,
    required this.bangumiItem,
    this.autoTriggered = false,
  });

  @override
  State<FinishReviewSheet> createState() => _FinishReviewSheetState();
}

class _FinishReviewSheetState extends State<FinishReviewSheet> {
  static const int _commentMaxLength = 380;

  final TextEditingController _commentController = TextEditingController();
  int _rating = 0;
  bool _private = false;
  bool _loading = true;
  bool _submitting = false;
  bool _hasExisting = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final BangumiSubjectCollection? collection =
          await BangumiHTTP.getUserSubjectCollection(widget.bangumiItem.id);
      if (!mounted) return;
      if (collection != null) {
        final hasRate = (collection.rate ?? 0) > 0;
        final hasComment = collection.comment.isNotEmpty;
        setState(() {
          _rating = collection.rate ?? 0;
          _commentController.text = collection.comment;
          _private = collection.private;
          _hasExisting = hasRate || hasComment;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      KazumiLogger().w('FinishReviewSheet: load existing failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final comment = _commentController.text.trim();
    setState(() {
      _submitting = true;
    });
    try {
      await BangumiHTTP.updateUserReview(
        subjectId: widget.bangumiItem.id,
        rating: _rating > 0 ? _rating : null,
        comment: comment,
        private: _private,
        type: 2,
      );
      FinishReviewTrigger.I.markPrompted(widget.bangumiItem.id);
      if (!mounted) return;
      KazumiDialog.showToast(message: '已提交到 Bangumi');
      Navigator.of(context).pop(true);
    } catch (e) {
      KazumiLogger().e('FinishReviewSheet: submit failed', error: e);
      if (!mounted) return;
      KazumiDialog.showToast(message: '提交失败：$e');
      setState(() {
        _submitting = false;
      });
    }
  }

  void _snooze() {
    FinishReviewTrigger.I.snoozeForSession(widget.bangumiItem.id);
    Navigator.of(context).maybePop();
  }

  Future<void> _dismissForever() async {
    await FinishReviewTrigger.I.dismissForever(widget.bangumiItem.id);
    if (!mounted) return;
    KazumiDialog.showToast(message: '已不再提示这部番剧');
    Navigator.of(context).maybePop();
  }

  String get _ratingHint {
    switch (_rating) {
      case 0:
        return '点击下方数字评分';
      case 1:
        return '不忍直视';
      case 2:
        return '很差';
      case 3:
        return '差';
      case 4:
        return '较差';
      case 5:
        return '不过不失';
      case 6:
        return '还行';
      case 7:
        return '推荐';
      case 8:
        return '力荐';
      case 9:
        return '神作';
      case 10:
        return '超神作';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cover = widget.bangumiItem.images['common']?.isNotEmpty == true
        ? widget.bangumiItem.images['common']!
        : (widget.bangumiItem.images['large'] ?? '');
    final title = widget.bangumiItem.nameCn.isNotEmpty
        ? widget.bangumiItem.nameCn
        : widget.bangumiItem.name;

    if (_loading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: NetworkImgLayer(
                  src: cover,
                  width: 56,
                  height: 76,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasExisting ? '更新我的评价' : '看完啦，留下评价吧',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('评分', style: theme.textTheme.titleSmall),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _ratingHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              if (_rating > 0)
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () {
                          setState(() => _rating = 0);
                        },
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('清除'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(10, (i) {
              final value = i + 1;
              final selected = value == _rating;
              return ChoiceChip(
                label: Text('$value'),
                selected: selected,
                showCheckmark: false,
                onSelected: _submitting
                    ? null
                    : (_) {
                        setState(() => _rating = value);
                      },
              );
            }),
          ),
          const SizedBox(height: 20),
          Text('短评', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 5,
            minLines: 3,
            maxLength: _commentMaxLength,
            enabled: !_submitting,
            inputFormatters: [
              LengthLimitingTextInputFormatter(_commentMaxLength),
            ],
            decoration: InputDecoration(
              hintText: '写点什么吧（可留空）',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Switch(
                value: _private,
                onChanged: _submitting
                    ? null
                    : (value) {
                        setState(() => _private = value);
                      },
              ),
              const SizedBox(width: 4),
              Text('设为不公开（仅自己可见）',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.autoTriggered)
                TextButton(
                  onPressed: _submitting ? null : _dismissForever,
                  style: TextButton.styleFrom(
                    foregroundColor: cs.error,
                  ),
                  child: const Text('不再提示这部'),
                ),
              const Spacer(),
              if (widget.autoTriggered)
                TextButton(
                  onPressed: _submitting ? null : _snooze,
                  child: const Text('下次再说'),
                )
              else
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: const Text('取消'),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (_submitting ||
                        (_rating == 0 &&
                            _commentController.text.trim().isEmpty))
                    ? null
                    : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_hasExisting ? '保存' : '提交'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
