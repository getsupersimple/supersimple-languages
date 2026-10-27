import 'dart:math';

import 'package:flutter/material.dart';

/// Lunar New Year (the first new moon of the lunar calendar) has no formula
/// worth writing, so its dates are listed. Outside the list the plain pangolin
/// shows; extend it before 2041.
final _lunarNewYear = <int, DateTime>{
  2026: DateTime(2026, 2, 17),
  2027: DateTime(2027, 2, 6),
  2028: DateTime(2028, 1, 26),
  2029: DateTime(2029, 2, 13),
  2030: DateTime(2030, 2, 3),
  2031: DateTime(2031, 1, 23),
  2032: DateTime(2032, 2, 11),
  2033: DateTime(2033, 1, 31),
  2034: DateTime(2034, 2, 19),
  2035: DateTime(2035, 2, 8),
  2036: DateTime(2036, 1, 28),
  2037: DateTime(2037, 2, 15),
  2038: DateTime(2038, 2, 4),
  2039: DateTime(2039, 1, 24),
  2040: DateTime(2040, 2, 12),
};

/// Western Easter Sunday (the anonymous Gregorian algorithm).
DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = (h + l - 7 * m + 114) % 31 + 1;
  return DateTime(year, month, day);
}

/// Whether [date] is within [before] days before and [after] days after [event].
bool _near(DateTime date, DateTime event, {int before = 0, int after = 0}) {
  final days = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(event.year, event.month, event.day)).inDays;
  return days >= -before && days <= after;
}

/// The folder of mascot images for [date]. Valentine's Day itself (14 February)
/// always wins. Otherwise, where seasons overlap the first wins: Lunar New Year
/// (the day before to the Lantern Festival), Christmas (1 December to 2
/// January), Easter (the week before to Easter Monday), Valentine's week
/// (1 to 13 February). Otherwise the plain pangolin.
String mascotFolder(DateTime date) {
  if (date.month == 2 && date.day == 14) return 'assets/mascot/valentine';
  final lunar = _lunarNewYear[date.year];
  if (lunar != null && _near(date, lunar, before: 1, after: 15)) {
    return 'assets/mascot/lunar-new-year';
  }
  if (date.month == 12 || (date.month == 1 && date.day <= 2)) {
    return 'assets/mascot/christmas';
  }
  if (_near(date, easterSunday(date.year), before: 7, after: 1)) {
    return 'assets/mascot/easter';
  }
  if (date.month == 2 && date.day <= 14) return 'assets/mascot/valentine';
  return 'assets/mascot';
}

/// The pangolin mascot's poses, one file each per outfit in `assets/mascot/`.
/// Declared in the order of the sprite sheet; the notes give each one's mood.
enum Pose {
  /// Jubilant.
  excited,

  /// Upset.
  crying,

  /// Curious, concentrating.
  focused,

  /// Wonder, surprise.
  alert,

  /// Determined, frustrated.
  grumpy,

  /// Delighted.
  laughing,

  /// Cheerful greeting.
  wave,

  /// Sleepy, resting.
  sleeping,

  /// Thoughtful, daydreaming.
  thinking,

  /// Proud, confident.
  cheer,

  /// Puzzled.
  confused,

  /// Shy, tender (not really sad).
  sad,

  /// Energetic, eager.
  running,

  /// Content, cozy.
  listening,

  /// Ecstatic, celebrating.
  dancing,

  /// Happy, open-armed welcome.
  shrug;

  String get asset => assetIn(mascotFolder(DateTime.now()));

  String assetIn(String folder) => '$folder/$name.webp';
}

/// The mascot in [pose]. Changing the pose pops the new one in. The images all
/// face one way, so each mascot shown is flipped at random for variety.
class MascotView extends StatefulWidget {
  const MascotView({super.key, required this.pose, this.height = 88});

  final Pose pose;
  final double height;

  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView> {
  final bool _flipped = Random().nextBool();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        child: AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.0).animate(animation),
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
          child: Transform.flip(
            key: ValueKey(widget.pose),
            flipX: _flipped,
            child: Image.asset(
              widget.pose.asset,
              height: widget.height,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
    );
  }
}

/// The instruction at the top of an exercise, spoken by the mascot.
class MascotPrompt extends StatelessWidget {
  const MascotPrompt({super.key, required this.pose, required this.text});

  final Pose pose;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MascotView(pose: pose),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      ],
    );
  }
}

/// Poses for the introduction cards, in the order the cards come: a greeting,
/// then a mix of curious, delighted and welcoming moods.
const introPoses = [
  Pose.wave,
  Pose.alert,
  Pose.listening,
  Pose.excited,
  Pose.focused,
  Pose.shrug,
  Pose.laughing,
  Pose.thinking,
  Pose.running,
  Pose.sad,
];

/// A number a screen draws once, so its mascot reacts the same way every time
/// it is shown but differently from one exercise to the next.
int newVariant() => Random().nextInt(1 << 16);

/// How the mascot reacts to the learner's answer. [idle] is shown until the
/// answer is checked; [revealed] means the learner gave up and was shown it.
/// [variant] picks among the moods that fit the outcome.
Pose feedbackPose({
  required Pose idle,
  required bool checked,
  required bool correct,
  bool close = false,
  bool revealed = false,
  int variant = 0,
}) {
  if (revealed) return Pose.shrug;
  if (!checked) return idle;
  if (correct) {
    const happy = [Pose.cheer, Pose.laughing, Pose.excited, Pose.dancing];
    return happy[variant % happy.length];
  }
  if (close) return variant.isEven ? Pose.confused : Pose.thinking;
  return variant.isEven ? Pose.grumpy : Pose.sad;
}
