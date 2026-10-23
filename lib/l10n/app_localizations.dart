import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Supersimple Languages'**
  String get appTitle;

  /// No description provided for @unitsHeading.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get unitsHeading;

  /// No description provided for @unitPhraseCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 phrase} other{{count} phrases}}'**
  String unitPhraseCount(int count);

  /// No description provided for @unitDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get unitDownloading;

  /// No description provided for @unitReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get unitReady;

  /// No description provided for @unitNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Tap to download'**
  String get unitNotDownloaded;

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the content.'**
  String get loadError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @translateInstruction.
  ///
  /// In en, this message translates to:
  /// **'Translate this sentence'**
  String get translateInstruction;

  /// No description provided for @checkButton.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get checkButton;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @correctFeedback.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get correctFeedback;

  /// No description provided for @incorrectFeedback.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get incorrectFeedback;

  /// No description provided for @correctAnswerWas.
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {answer}'**
  String correctAnswerWas(String answer);

  /// No description provided for @lessonComplete.
  ///
  /// In en, this message translates to:
  /// **'Lesson complete!'**
  String get lessonComplete;

  /// No description provided for @lessonScore.
  ///
  /// In en, this message translates to:
  /// **'You got {correct} of {total} right.'**
  String lessonScore(int correct, int total);

  /// No description provided for @backToUnits.
  ///
  /// In en, this message translates to:
  /// **'Back to units'**
  String get backToUnits;

  /// No description provided for @lessonProgress.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String lessonProgress(int current, int total);

  /// No description provided for @lessonNeedsMorePhrases.
  ///
  /// In en, this message translates to:
  /// **'This unit doesn\'t have enough phrases for a lesson yet.'**
  String get lessonNeedsMorePhrases;

  /// No description provided for @playAudio.
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get playAudio;

  /// No description provided for @listenInstruction.
  ///
  /// In en, this message translates to:
  /// **'What do you hear?'**
  String get listenInstruction;

  /// No description provided for @buildInstruction.
  ///
  /// In en, this message translates to:
  /// **'Build the sentence'**
  String get buildInstruction;

  /// No description provided for @matchInstruction.
  ///
  /// In en, this message translates to:
  /// **'Match the pairs'**
  String get matchInstruction;

  /// No description provided for @typeInstruction.
  ///
  /// In en, this message translates to:
  /// **'Type what you hear'**
  String get typeInstruction;

  /// No description provided for @typeHint.
  ///
  /// In en, this message translates to:
  /// **'Type the phrase'**
  String get typeHint;

  /// No description provided for @introInstruction.
  ///
  /// In en, this message translates to:
  /// **'New phrase'**
  String get introInstruction;

  /// No description provided for @tapWordHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a word to learn more'**
  String get tapWordHint;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @lemmaFormOf.
  ///
  /// In en, this message translates to:
  /// **'\"{form}\" is a form of \"{lemma}\"'**
  String lemmaFormOf(String form, String lemma);

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @posNoun.
  ///
  /// In en, this message translates to:
  /// **'noun'**
  String get posNoun;

  /// No description provided for @posVerb.
  ///
  /// In en, this message translates to:
  /// **'verb'**
  String get posVerb;

  /// No description provided for @posAdjective.
  ///
  /// In en, this message translates to:
  /// **'adjective'**
  String get posAdjective;

  /// No description provided for @posAdverb.
  ///
  /// In en, this message translates to:
  /// **'adverb'**
  String get posAdverb;

  /// No description provided for @posPronoun.
  ///
  /// In en, this message translates to:
  /// **'pronoun'**
  String get posPronoun;

  /// No description provided for @posNumeral.
  ///
  /// In en, this message translates to:
  /// **'numeral'**
  String get posNumeral;

  /// No description provided for @posPreposition.
  ///
  /// In en, this message translates to:
  /// **'preposition'**
  String get posPreposition;

  /// No description provided for @posConjunction.
  ///
  /// In en, this message translates to:
  /// **'conjunction'**
  String get posConjunction;

  /// No description provided for @posParticle.
  ///
  /// In en, this message translates to:
  /// **'particle'**
  String get posParticle;

  /// No description provided for @posInterjection.
  ///
  /// In en, this message translates to:
  /// **'interjection'**
  String get posInterjection;

  /// No description provided for @caseNom.
  ///
  /// In en, this message translates to:
  /// **'nominative'**
  String get caseNom;

  /// No description provided for @caseGen.
  ///
  /// In en, this message translates to:
  /// **'genitive'**
  String get caseGen;

  /// No description provided for @caseDat.
  ///
  /// In en, this message translates to:
  /// **'dative'**
  String get caseDat;

  /// No description provided for @caseAcc.
  ///
  /// In en, this message translates to:
  /// **'accusative'**
  String get caseAcc;

  /// No description provided for @caseVoc.
  ///
  /// In en, this message translates to:
  /// **'vocative'**
  String get caseVoc;

  /// No description provided for @caseIns.
  ///
  /// In en, this message translates to:
  /// **'instrumental'**
  String get caseIns;

  /// No description provided for @caseLoc.
  ///
  /// In en, this message translates to:
  /// **'locative'**
  String get caseLoc;

  /// No description provided for @numberSg.
  ///
  /// In en, this message translates to:
  /// **'singular'**
  String get numberSg;

  /// No description provided for @numberPl.
  ///
  /// In en, this message translates to:
  /// **'plural'**
  String get numberPl;

  /// No description provided for @genderM.
  ///
  /// In en, this message translates to:
  /// **'masculine'**
  String get genderM;

  /// No description provided for @genderF.
  ///
  /// In en, this message translates to:
  /// **'feminine'**
  String get genderF;

  /// No description provided for @genderN.
  ///
  /// In en, this message translates to:
  /// **'neuter'**
  String get genderN;

  /// No description provided for @personLabel.
  ///
  /// In en, this message translates to:
  /// **'person {n}'**
  String personLabel(int n);

  /// No description provided for @tensePres.
  ///
  /// In en, this message translates to:
  /// **'present'**
  String get tensePres;

  /// No description provided for @tensePast.
  ///
  /// In en, this message translates to:
  /// **'past'**
  String get tensePast;

  /// No description provided for @tenseFut.
  ///
  /// In en, this message translates to:
  /// **'future'**
  String get tenseFut;

  /// No description provided for @tenseImp.
  ///
  /// In en, this message translates to:
  /// **'imperative'**
  String get tenseImp;

  /// No description provided for @formClitic.
  ///
  /// In en, this message translates to:
  /// **'short form'**
  String get formClitic;

  /// No description provided for @formInfinitive.
  ///
  /// In en, this message translates to:
  /// **'infinitive'**
  String get formInfinitive;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
