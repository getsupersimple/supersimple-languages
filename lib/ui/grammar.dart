import '../l10n/app_localizations.dart';

/// Turns language-neutral grammar tags into a short localized description,
/// for example "noun · accusative · singular · feminine".
String describeGrammar(AppLocalizations l10n, Map<String, dynamic> grammar) {
  final parts = <String>[
    switch (grammar['pos']) {
      'noun' => l10n.posNoun,
      'verb' => l10n.posVerb,
      'adjective' => l10n.posAdjective,
      'adverb' => l10n.posAdverb,
      'pronoun' => l10n.posPronoun,
      'numeral' => l10n.posNumeral,
      'preposition' => l10n.posPreposition,
      'conjunction' => l10n.posConjunction,
      'particle' => l10n.posParticle,
      'interjection' => l10n.posInterjection,
      _ => '',
    },
    switch (grammar['case']) {
      'nom' => l10n.caseNom,
      'gen' => l10n.caseGen,
      'dat' => l10n.caseDat,
      'acc' => l10n.caseAcc,
      'voc' => l10n.caseVoc,
      'ins' => l10n.caseIns,
      'loc' => l10n.caseLoc,
      _ => '',
    },
    if (grammar['person'] is int) l10n.personLabel(grammar['person'] as int),
    switch (grammar['number']) {
      'sg' => l10n.numberSg,
      'pl' => l10n.numberPl,
      _ => '',
    },
    switch (grammar['gender']) {
      'm' => l10n.genderM,
      'f' => l10n.genderF,
      'n' => l10n.genderN,
      _ => '',
    },
    switch (grammar['tense']) {
      'pres' => l10n.tensePres,
      'past' => l10n.tensePast,
      'fut' => l10n.tenseFut,
      'imp' => l10n.tenseImp,
      _ => '',
    },
    switch (grammar['form']) {
      'clitic' => l10n.formClitic,
      'infinitive' => l10n.formInfinitive,
      _ => '',
    },
  ];
  return parts.where((p) => p.isNotEmpty).join(' · ');
}
