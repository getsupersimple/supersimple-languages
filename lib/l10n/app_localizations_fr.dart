// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Supersimple Languages';

  @override
  String get unitsHeading => 'Unités';

  @override
  String unitPhraseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count phrases',
      one: '1 phrase',
      zero: '0 phrase',
    );
    return '$_temp0';
  }

  @override
  String get unitDownloading => 'Téléchargement…';

  @override
  String get unitReady => 'Prêt';

  @override
  String get unitNotDownloaded => 'Touchez pour télécharger';

  @override
  String get loadError => 'Impossible de charger le contenu.';

  @override
  String get retry => 'Réessayer';

  @override
  String get translateInstruction => 'Traduisez cette phrase';

  @override
  String get checkButton => 'Vérifier';

  @override
  String get continueButton => 'Continuer';

  @override
  String get correctFeedback => 'Correct !';

  @override
  String get incorrectFeedback => 'Pas tout à fait';

  @override
  String get closeFeedback => 'Presque !';

  @override
  String get showAnswerButton => 'Voir la réponse';

  @override
  String get answerFeedback => 'Réponse';

  @override
  String correctAnswerWas(String answer) {
    return 'Bonne réponse : $answer';
  }

  @override
  String get lessonComplete => 'Leçon terminée !';

  @override
  String lessonScore(int correct, int total) {
    return 'Vous avez eu $correct bonne(s) réponse(s) sur $total.';
  }

  @override
  String get backToUnits => 'Retour aux unités';

  @override
  String lessonProgress(int current, int total) {
    return 'Question $current sur $total';
  }

  @override
  String get lessonNeedsMorePhrases =>
      'Cette unité n\'a pas encore assez de phrases pour une leçon.';

  @override
  String get playAudio => 'Écouter';

  @override
  String get listenInstruction => 'Qu\'entendez-vous ?';

  @override
  String get buildInstruction => 'Construisez la phrase';

  @override
  String get matchInstruction => 'Associez les paires';

  @override
  String get typeInstruction => 'Écrivez ce que vous entendez';

  @override
  String get typeHint => 'Écrivez la phrase';

  @override
  String get introInstruction => 'Nouvelle phrase';

  @override
  String get tapWordHint => 'Touchez un mot pour en savoir plus';

  @override
  String get gotIt => 'Compris';

  @override
  String lemmaFormOf(String form, String lemma) {
    return '« $form » est une forme de « $lemma »';
  }

  @override
  String get closeButton => 'Fermer';

  @override
  String get posNoun => 'nom';

  @override
  String get posVerb => 'verbe';

  @override
  String get posAdjective => 'adjectif';

  @override
  String get posAdverb => 'adverbe';

  @override
  String get posPronoun => 'pronom';

  @override
  String get posDeterminer => 'déterminant';

  @override
  String get posNumeral => 'numéral';

  @override
  String get posPreposition => 'préposition';

  @override
  String get posConjunction => 'conjonction';

  @override
  String get posParticle => 'particule';

  @override
  String get posInterjection => 'interjection';

  @override
  String get caseNom => 'nominatif';

  @override
  String get caseGen => 'génitif';

  @override
  String get caseDat => 'datif';

  @override
  String get caseAcc => 'accusatif';

  @override
  String get caseVoc => 'vocatif';

  @override
  String get caseIns => 'instrumental';

  @override
  String get caseLoc => 'locatif';

  @override
  String get numberSg => 'singulier';

  @override
  String get numberPl => 'pluriel';

  @override
  String get genderM => 'masculin';

  @override
  String get genderF => 'féminin';

  @override
  String get genderN => 'neutre';

  @override
  String personLabel(int n) {
    return 'personne $n';
  }

  @override
  String get tensePres => 'présent';

  @override
  String get tensePast => 'passé';

  @override
  String get tenseFut => 'futur';

  @override
  String get tenseImp => 'impératif';

  @override
  String get formClitic => 'forme courte';

  @override
  String get formInfinitive => 'infinitif';

  @override
  String get tabLearn => 'Apprendre';

  @override
  String get tabSettings => 'Réglages';

  @override
  String get learnHeading => 'Que voulez-vous apprendre ?';

  @override
  String learnFilterNote(String language) {
    return 'Votre langue : $language. Vous pouvez la changer dans les Réglages.';
  }

  @override
  String get noCourses => 'Aucun cours pour cette langue pour le moment.';

  @override
  String get sourceLanguageHeading => 'Je parle';

  @override
  String get sourceLanguageHelp =>
      'Choisissez votre langue pour voir les cours disponibles.';
}
