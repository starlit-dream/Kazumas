import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/capsule_progress_popup.dart';

void main() {
  test('watched capsule initial text uses two-digit episode and title', () {
    expect(
      CapsuleWatchedBody.initialTextFor(
        episodeNumber: 1,
        episodeTitle: '本集名称',
      ),
      '01 本集名称',
    );

    expect(
      CapsuleWatchedBody.initialTextFor(
        episodeNumber: 12,
        episodeTitle: '  标题  ',
      ),
      '12 标题',
    );
  });
}
