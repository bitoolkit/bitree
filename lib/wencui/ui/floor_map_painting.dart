part of 'floor_map.dart';

class _MapFeatures extends CustomPainter {
  _MapFeatures({
    required this.features,
    required this.selected,
    required this.hover,
    required this.scale,
    required this.accent,
    required this.surface,
    required this.foreground,
    required this.facilities,
    required this.onSelected,
    required this.l10n,
  });
  final List<WencuiFeature> features;
  final WencuiFeature? selected;
  final WencuiFeature? hover;
  final double scale;
  final Color accent;
  final Color surface;
  final Color foreground;
  final Set<WencuiFeatureKind> facilities;
  final ValueChanged<WencuiFeature> onSelected;
  final AppLocalizations l10n;

  @override
  void paint(Canvas canvas, Size size) {
    for (final feature in features) {
      final path = feature.path.transform(
        Matrix4.diagonal3Values(size.width, size.height, 1).storage,
      );
      if (feature == selected || feature == hover) {
        canvas.drawPath(
          path,
          Paint()
            ..color = accent.withValues(alpha: feature == selected ? .25 : .12),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 / scale,
        );
      }
      if (facilities.contains(feature.kind)) {
        final point = Offset(
          feature.anchor.dx * size.width,
          feature.anchor.dy * size.height,
        );
        final radius = 13 / scale;
        canvas.drawCircle(point, radius, Paint()..color = surface);
        canvas.drawCircle(
          point,
          radius,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 / scale,
        );
        final icon = wencuiFeatureIcon(
          feature.kind,
          restroomGender: feature.restroomGender,
        );
        final text = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontFamily: icon.fontFamily,
              fontSize: 16 / scale,
              color: foreground,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, point - Offset(text.width / 2, text.height / 2));
        text.dispose();
      }
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final feature in features)
          if (feature.kind == WencuiFeatureKind.room ||
              facilities.contains(feature.kind))
            CustomPainterSemantics(
              rect: (feature.kind == WencuiFeatureKind.room
                  ? Rect.fromLTRB(
                      feature.bounds.left * size.width,
                      feature.bounds.top * size.height,
                      feature.bounds.right * size.width,
                      feature.bounds.bottom * size.height,
                    )
                  : Rect.fromCenter(
                      center: Offset(
                        feature.anchor.dx * size.width,
                        feature.anchor.dy * size.height,
                      ),
                      width: 44 / scale,
                      height: 44 / scale,
                    )),
              properties: SemanticsProperties(
                label: l10n.featureSemantics(
                  localizedWencuiFeatureLabel(l10n, feature),
                  feature.floor,
                ),
                button: true,
                selected: feature == selected,
                textDirection: TextDirection.ltr,
                onTap: () => onSelected(feature),
              ),
            ),
      ];
  @override
  bool shouldRepaint(_MapFeatures old) =>
      old.features != features ||
      old.selected != selected ||
      old.hover != hover ||
      old.scale != scale ||
      old.accent != accent ||
      old.surface != surface ||
      old.foreground != foreground ||
      old.l10n != l10n ||
      !setEquals(old.facilities, facilities);
  @override
  bool shouldRebuildSemantics(_MapFeatures old) =>
      old.features != features ||
      old.selected != selected ||
      old.scale != scale ||
      old.l10n != l10n ||
      !setEquals(old.facilities, facilities);
}
