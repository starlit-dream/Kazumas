import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kazumi/pages/info/info_controller.dart';

/// 播放器内弹出的胶囊样式已看确认弹窗（左下侧），3 秒后自动消失且可拖动消除
void showCapsuleWatchedConfirmation(
    BuildContext context, {
      required int episodeNumber,
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
            child: _CapsuleWatchedBody(episodeNumber: episodeNumber),
          ),
        ),
      );
    },
  );
}

/// 播放器已看确认胶囊弹窗主体
class _CapsuleWatchedBody extends StatelessWidget {
  final int episodeNumber;

  const _CapsuleWatchedBody({required this.episodeNumber});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            child: Text(
              '已标记第 $episodeNumber 集为已看',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
