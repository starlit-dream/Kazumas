import 'package:flutter/material.dart';
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

  testWidgets('watched capsule flips from episode title to completed',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CapsuleWatchedBody(
            episodeNumber: 1,
            episodeTitle: '本集名称',
          ),
        ),
      ),
    );

    expect(find.text('01 本集名称'), findsOneWidget);
    expect(find.text('已完成'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 225));

    expect(find.text('已完成'), findsOneWidget);
  });
}
