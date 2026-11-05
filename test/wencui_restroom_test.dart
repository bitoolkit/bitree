import 'package:bitree/l10n/app_localizations.dart';
import 'package:bitree/l10n/formats.dart';
import 'package:bitree/wencui/atlas.dart';
import 'package:bitree/wencui/place.dart';
import 'package:bitree/wencui/ui/floor_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Surveyed F and I restrooms retain both sides on every floor', () async {
    final atlas = await WencuiAtlas.load();
    for (final wing in [WencuiWing.f, WencuiWing.i]) {
      for (var floor = 1; floor <= 7; floor++) {
        final restrooms = atlas.onFloor(floor).where((feature) {
          return feature.wing == wing &&
              feature.kind == WencuiFeatureKind.restroom;
        }).toList()..sort((a, b) => a.anchor.dy.compareTo(b.anchor.dy));
        expect(restrooms, hasLength(2), reason: '${wing.letter}$floor');
        // The source plan faces east-up: men east, women west above floor 1.
        final [eastSide, westSide] = restrooms;
        expect(eastSide.anchor.dy, lessThan(.5));
        expect(westSide.anchor.dy, greaterThan(.5));
        expect(
          eastSide.restroomGender,
          floor == 1
              ? WencuiRestroomGender.both
              : WencuiRestroomGender.male,
        );
        expect(
          westSide.restroomGender,
          floor == 1
              ? WencuiRestroomGender.both
              : WencuiRestroomGender.female,
        );
      }
    }
    for (final feature in atlas.features) {
      if (feature.kind != WencuiFeatureKind.restroom ||
          (feature.wing != WencuiWing.f && feature.wing != WencuiWing.i)) {
        expect(feature.restroomGender, isNull);
      }
    }
  });

  test('Restroom icons and labels distinguish confirmed types', () async {
    final atlas = await WencuiAtlas.load();
    for (final (gender, icon, zh, en) in [
      (
        WencuiRestroomGender.male,
        Icons.man_rounded,
        '男卫生间',
        "Men's restroom",
      ),
      (
        WencuiRestroomGender.female,
        Icons.woman_rounded,
        '女卫生间',
        "Women's restroom",
      ),
      (
        WencuiRestroomGender.both,
        Icons.wc_rounded,
        '卫生间',
        'Restroom',
      ),
      (null, Icons.wc_rounded, '卫生间', 'Restroom'),
    ]) {
      final feature = atlas.features.firstWhere(
        (feature) =>
            feature.kind == WencuiFeatureKind.restroom &&
            feature.restroomGender == gender,
      );
      expect(
        wencuiFeatureIcon(feature.kind, restroomGender: feature.restroomGender),
        icon,
      );
      for (final (language, label) in [('zh', zh), ('en', en)]) {
        final l10n = await AppLocalizations.delegate.load(Locale(language));
        expect(localizedWencuiFeatureLabel(l10n, feature), label);
        expect(localizedWencuiFeatureTitle(l10n, feature), contains(label));
      }
    }
  });
}
