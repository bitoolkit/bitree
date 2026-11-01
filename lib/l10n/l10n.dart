import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'app_localizations_zh.dart';

export 'app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  /// Feature tests render individual widgets without the application delegate.
  /// Chinese remains the source-language fallback in that case.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsZh();
}
