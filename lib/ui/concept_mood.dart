import 'mascot.dart';

const _moods = <String, Pose>{
  // Greetings and farewells.
  'good-day': Pose.wave,
  'good-evening': Pose.wave,
  'goodbye': Pose.wave,
  'how-are-you': Pose.wave,
  'have-a-nice-day': Pose.wave,
  'youre-welcome': Pose.shrug,
  'what-is-your-name': Pose.wave,
  // Tired, resting, tender.
  'i-am-tired': Pose.sleeping,
  'good-night': Pose.sleeping,
  'thank-you': Pose.sad,
  'thank-you-very-much': Pose.sad,
  'please': Pose.sad,
  'sorry': Pose.sad,
  'excuse-me': Pose.sad,
  'no-thank-you': Pose.sad,
  'fine-thanks': Pose.listening,
  // Yes, no, understanding.
  'yes': Pose.cheer,
  'no': Pose.grumpy,
  'i-understand': Pose.cheer,
  'i-dont-understand': Pose.confused,
  'i-dont-know': Pose.confused,
  'i-dont-know-where-i-am': Pose.confused,
  'what-does-this-mean': Pose.confused,
  'can-you-repeat': Pose.thinking,
  'speak-slowly-please': Pose.thinking,
  'do-you-speak-english': Pose.alert,
  // Food and drink.
  'one-coffee-please': Pose.listening,
  'a-beer-please': Pose.listening,
  'water-please': Pose.listening,
  'delicious': Pose.laughing,
  'cheers': Pose.dancing,
  'what-do-you-recommend': Pose.thinking,
  'i-dont-eat-meat': Pose.thinking,
  'without-nuts-please': Pose.thinking,
  'table-for-two': Pose.shrug,
  'the-menu-please': Pose.shrug,
  'the-bill-please': Pose.shrug,
  'i-have-a-reservation': Pose.cheer,
  // Getting around.
  'go-straight': Pose.running,
  'turn-left': Pose.focused,
  'turn-right': Pose.focused,
  'stop-here-please': Pose.focused,
  'how-do-i-get-to-the-centre': Pose.focused,
  'is-it-far': Pose.focused,
  'is-it-near': Pose.focused,
  'how-long-does-it-take': Pose.focused,
  'call-a-taxi': Pose.shrug,
  'a-ticket-please': Pose.shrug,
  // Shopping.
  'how-much-is-this': Pose.alert,
  'too-expensive': Pose.grumpy,
  'do-you-take-cards': Pose.alert,
  'ill-take-it': Pose.cheer,
  'can-i-have-a-receipt': Pose.shrug,
  'the-key-please': Pose.shrug,
  'do-you-have-a-free-room': Pose.alert,
  'what-time-do-you-open': Pose.alert,
  // Trouble.
  'help': Pose.alert,
  'call-the-police': Pose.alert,
  'call-an-ambulance': Pose.alert,
  'stop-thief': Pose.alert,
  'please-help-me': Pose.crying,
  'i-need-a-doctor': Pose.crying,
  'i-feel-sick': Pose.crying,
  'it-hurts-here': Pose.crying,
};

/// The mascot's mood for a phrase of [concept], or null when none is set; a
/// "Where is…?" question is curious. Callers fall back to a varied pose.
Pose? moodOfConcept(String concept) =>
    _moods[concept] ?? (concept.startsWith('where-') ? Pose.focused : null);
