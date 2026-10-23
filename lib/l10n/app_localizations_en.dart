// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Supersimple Languages';

  @override
  String get unitsHeading => 'Units';

  @override
  String unitPhraseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count phrases',
      one: '1 phrase',
    );
    return '$_temp0';
  }

  @override
  String get unitDownloading => 'Downloading…';

  @override
  String get unitReady => 'Ready';

  @override
  String get unitNotDownloaded => 'Tap to download';

  @override
  String get loadError => 'Couldn\'t load the content.';

  @override
  String get retry => 'Try again';

  @override
  String get translateInstruction => 'Translate this sentence';

  @override
  String get checkButton => 'Check';

  @override
  String get continueButton => 'Continue';

  @override
  String get correctFeedback => 'Correct!';

  @override
  String get incorrectFeedback => 'Not quite';

  @override
  String correctAnswerWas(String answer) {
    return 'Correct answer: $answer';
  }

  @override
  String get lessonComplete => 'Lesson complete!';

  @override
  String lessonScore(int correct, int total) {
    return 'You got $correct of $total right.';
  }

  @override
  String get backToUnits => 'Back to units';

  @override
  String lessonProgress(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get lessonNeedsMorePhrases =>
      'This unit doesn\'t have enough phrases for a lesson yet.';

  @override
  String get playAudio => 'Play audio';

  @override
  String get listenInstruction => 'What do you hear?';

  @override
  String get buildInstruction => 'Build the sentence';

  @override
  String get matchInstruction => 'Match the pairs';

  @override
  String get typeInstruction => 'Type what you hear';

  @override
  String get typeHint => 'Type the phrase';

  @override
  String get introInstruction => 'New phrase';

  @override
  String get tapWordHint => 'Tap a word to learn more';

  @override
  String get gotIt => 'Got it';

  @override
  String lemmaFormOf(String form, String lemma) {
    return '\"$form\" is a form of \"$lemma\"';
  }

  @override
  String get closeButton => 'Close';

  @override
  String get posNoun => 'noun';

  @override
  String get posVerb => 'verb';

  @override
  String get posAdjective => 'adjective';

  @override
  String get posAdverb => 'adverb';

  @override
  String get posPronoun => 'pronoun';

  @override
  String get posDeterminer => 'determiner';

  @override
  String get posNumeral => 'numeral';

  @override
  String get posPreposition => 'preposition';

  @override
  String get posConjunction => 'conjunction';

  @override
  String get posParticle => 'particle';

  @override
  String get posInterjection => 'interjection';

  @override
  String get caseNom => 'nominative';

  @override
  String get caseGen => 'genitive';

  @override
  String get caseDat => 'dative';

  @override
  String get caseAcc => 'accusative';

  @override
  String get caseVoc => 'vocative';

  @override
  String get caseIns => 'instrumental';

  @override
  String get caseLoc => 'locative';

  @override
  String get numberSg => 'singular';

  @override
  String get numberPl => 'plural';

  @override
  String get genderM => 'masculine';

  @override
  String get genderF => 'feminine';

  @override
  String get genderN => 'neuter';

  @override
  String personLabel(int n) {
    return 'person $n';
  }

  @override
  String get tensePres => 'present';

  @override
  String get tensePast => 'past';

  @override
  String get tenseFut => 'future';

  @override
  String get tenseImp => 'imperative';

  @override
  String get formClitic => 'short form';

  @override
  String get formInfinitive => 'infinitive';

  @override
  String get tabLearn => 'Learn';

  @override
  String get tabSettings => 'Settings';

  @override
  String get learnHeading => 'What do you want to learn?';

  @override
  String learnFilterNote(String language) {
    return 'Your language: $language. You can change it in Settings.';
  }

  @override
  String get noCourses => 'No courses for this language yet.';

  @override
  String get sourceLanguageHeading => 'I speak';

  @override
  String get sourceLanguageHelp =>
      'Choose your language to see the courses available for it.';
}
