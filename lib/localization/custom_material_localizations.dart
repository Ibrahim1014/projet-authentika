import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Implémentation personnalisée de `MaterialLocalizations` pour le Haoussa.
class HaussaMaterialLocalizations extends DefaultMaterialLocalizations {
  const HaussaMaterialLocalizations();

  /// Factory pour enregistrer le delegate.
  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _HaussaMaterialLocalizationsDelegate();

  // Traductions spécifiques au Haoussa
  @override
  String get okButtonLabel => 'To';

  @override
  String get cancelButtonLabel => 'Soke';

  @override
  String get closeButtonLabel => 'Rufe';

  @override
  String get backButtonTooltip => 'Baya';

  @override
  String get nextPageTooltip => 'Shafi na gaba';

  @override
  String get previousPageTooltip => 'Shafi na baya';

  @override
  String get searchFieldLabel => 'Bincika';

  @override
  String get deleteButtonTooltip => 'Share';

  @override
  String get drawerLabel => 'Menu na tafiya';

  @override
  String get modalBarrierDismissLabel => 'Ficewar';

  @override
  String get refreshIndicatorSemanticLabel => 'Sabunta';

  @override
  String get remainingTextFieldCharacterCountOther =>
      'Haruffa saura : {remainingCount}';

  // Ajout des autres méthodes obligatoires
  @override
  String get cutButtonLabel => 'Yanke';

  @override
  String get copyButtonLabel => 'Kwafi';

  @override
  String get pasteButtonLabel => 'Manna';

  @override
  String get selectAllButtonLabel => 'Zaɓi Duka';

  @override
  String get dialogLabel => 'Tattaunawa';

  @override
  ScriptCategory get scriptCategory => ScriptCategory.tall;
}

/// Delegate associé pour le Haoussa.
class _HaussaMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _HaussaMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'ha';
  }

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return SynchronousFuture<MaterialLocalizations>(
      const HaussaMaterialLocalizations(),
    );
  }

  @override
  bool shouldReload(_HaussaMaterialLocalizationsDelegate old) => false;
}
