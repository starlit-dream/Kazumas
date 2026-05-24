import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kazumi/pages/info/info_controller.dart';

/// 播放器内弹出的胶囊样式已看确认弹窗（左下侧），3 秒后自动消失且可拖动消除
void showCapsuleWatchedConfirmation(
  BuildContext context, {
  required int episodeNumber,
  required String episodeTitle,
  required InfoController? infoController,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (ctx) {
      // 3 秒后自动关闭
      final autoTimer = Timer(const Duration(seconds: 3), () {
        if (ctx.mounted) Navigator.of(ctx).pop();
      });
      return Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 100),
          child: Dismissible(
            key: const ValueKey('capsule_watched'),
            direction: DismissDirection.horizontal,
            onDismissed: (_) {
              autoTimer.cancel();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: CapsuleWatchedBody(
              episodeNumber: episodeNumber,
              episodeTitle: episodeTitle,
            ),
          ),
        ),
      );
    },
  );
}

/// 播放器已看确认胶囊弹窗主体
class CapsuleWatchedBody extends StatefulWidget {
  final int episodeNumber;
  final String episodeTitle;

  const CapsuleWatchedBody({
    super.key,
    required this.episodeNumber,
    required this.episodeTitle,
  });

  @visibleForTesting
  static String initialTextFor({
    required int episodeNumber,
    required String episodeTitle,
  }) {
    final episodeLabel = episodeNumber.toString().padLeft(2, '0');
    final normalizedTitle = episodeTitle.trim();
    return normalizedTitle.isEmpty
        ? episodeLabel
        : '$episodeLabel $normalizedTitle';
  }

  @override
  State<CapsuleWatchedBody> createState() => _CapsuleWatchedBodyState();
}

class _CapsuleWatchedBodyState extends State<CapsuleWatchedBody> {
  bool _completed = false;
  Timer? _flipTimer;

  @override
  void initState() {
    super.initState();
    _flipTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _completed = true;
      });
    });
  }

  @override
  void dispose() {
    _flipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initialText = CapsuleWatchedBody.initialTextFor(
      episodeNumber: widget.episodeNumber,
      episodeTitle: widget.episodeTitle,
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Flexible(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: _completed ? 1 : 0,
              ),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOutCubic,
              builder: (context, value, child) {
                final showCompleted = value >= 0.5;
                final rotation = showCompleted ? value - 1 : value;
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(rotation * math.pi),
                  alignment: Alignment.center,
                  child: Text(
                    showCompleted ? '已完成' : initialText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_completed) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.done_rounded,
              size: 18,
              color: cs.primary,
            ),
          ] else ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
