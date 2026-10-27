import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:languages/ui/mascot.dart';

void main() {
  test('every pose has its image', () {
    for (final pose in Pose.values) {
      for (final folder in [
        'assets/mascot',
        'assets/mascot/christmas',
        'assets/mascot/valentine',
        'assets/mascot/easter',
        'assets/mascot/lunar-new-year',
      ]) {
        final path = pose.assetIn(folder);
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });

  test('the Christmas outfit runs from 1 December to 2 January', () {
    String folder(int y, int m, int d) => mascotFolder(DateTime(y, m, d));
    expect(folder(2026, 11, 30), 'assets/mascot');
    expect(folder(2026, 12, 1), 'assets/mascot/christmas');
    expect(folder(2026, 12, 31), 'assets/mascot/christmas');
    expect(folder(2027, 1, 2), 'assets/mascot/christmas');
    expect(folder(2027, 1, 3), 'assets/mascot');
    expect(folder(2027, 7, 4), 'assets/mascot');
  });

  test('the Valentine outfit runs from 1 to 14 February', () {
    // 2045 has no Lunar New Year entry, so nothing overlaps.
    String folder(int d, [int m = 2]) => mascotFolder(DateTime(2045, m, d));
    expect(folder(31, 1), 'assets/mascot');
    expect(folder(1), 'assets/mascot/valentine');
    expect(folder(14), 'assets/mascot/valentine');
    expect(folder(15), 'assets/mascot');
  });

  test('the mascot reacts to the answer', () {
    Pose pose({
      bool checked = true,
      bool correct = false,
      bool close = false,
      bool revealed = false,
    }) => feedbackPose(
      idle: Pose.thinking,
      checked: checked,
      correct: correct,
      close: close,
      revealed: revealed,
    );
    expect(pose(checked: false), Pose.thinking);
    expect(pose(correct: true), Pose.cheer);
    expect(pose(), Pose.grumpy);
    expect(pose(close: true), Pose.confused);
    expect(pose(revealed: true), Pose.shrug);
  });

  test('Easter is computed', () {
    expect(easterSunday(2026), DateTime(2026, 4, 5));
    expect(easterSunday(2027), DateTime(2027, 3, 28));
    expect(easterSunday(2038), DateTime(2038, 4, 25));
  });

  test('the Easter outfit runs from the week before to Easter Monday', () {
    String folder(int m, int d) => mascotFolder(DateTime(2027, m, d));
    expect(folder(3, 20), 'assets/mascot');
    expect(folder(3, 21), 'assets/mascot/easter');
    expect(folder(3, 28), 'assets/mascot/easter');
    expect(folder(3, 29), 'assets/mascot/easter');
    expect(folder(3, 30), 'assets/mascot');
  });

  test(
    'the Lunar New Year outfit wins over the days before Valentine Day but not the day itself, and ends after the Lantern Festival',
    () {
      String folder(int m, int d) => mascotFolder(DateTime(2027, m, d));
      expect(folder(2, 4), 'assets/mascot/valentine');
      expect(folder(2, 5), 'assets/mascot/lunar-new-year');
      expect(folder(2, 21), 'assets/mascot/lunar-new-year');
      expect(folder(2, 22), 'assets/mascot');
      // A year outside the table falls back to the plain pangolin.
      expect(mascotFolder(DateTime(2045, 2, 20)), 'assets/mascot');
    },
  );
}
