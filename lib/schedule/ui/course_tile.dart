import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/design.dart';
import '../../ui/theme.dart';
import '../model.dart';
import 'course_detail.dart';

class CourseTile extends StatelessWidget {
  const CourseTile({
    super.key,
    required this.course,
    required this.controller,
    required this.isToday,
    this.date,
    this.progress,
  });

  final Course course;
  final AppController controller;
  final bool isToday;
  final DateTime? date;

  /// Grid-relative frontier normalized to this inset card; clamp the fill to 0..1.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = courseColors(context, course);

    return Semantics(
      button: true,
      label: l10n.courseDetailsSemantics(
        course.name,
        localizedCourseTime(l10n, course),
        course.room,
        progress != null
            ? l10n.courseIsOngoing
            : isToday
            ? l10n.courseIsToday
            : '',
      ),
      child: ExcludeSemantics(
        child: Tooltip(
          triggerMode: TooltipTriggerMode.manual,
          message: '${course.name}\n${course.room}\n${course.teacher}',
          child: Material(
            color: colors.fill,
            shape: RoundedRectangleBorder(
              borderRadius: AppCorners.compact,
              side: isToday
                  ? BorderSide(color: colors.accent, width: 1.5)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showCourse(context, controller, course, date: date),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (progress case final value?)
                    Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        widthFactor: 1,
                        heightFactor: value.clamp(0.0, 1.0).toDouble(),
                        child: ColoredBox(color: colors.elapsedFill),
                      ),
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 100;
                      final fontSize = narrow ? 12.0 : 14.0;
                      final media = MediaQuery.of(context);
                      final horizontalPadding = narrow ? 3.0 : 10.0;
                      final verticalPadding = narrow ? 4.0 : 6.0;
                      final spacing = narrow ? 3.0 : 4.0;
                      final width =
                          constraints.maxWidth - horizontalPadding * 2;
                      final available =
                          constraints.maxHeight - verticalPadding * 2;
                      final defaults = DefaultTextStyle.of(context);
                      final titleStyle = TextStyle(
                        fontSize: fontSize,
                        height: narrow ? 1.25 : 1.4,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      );
                      final roomStyle = TextStyle(
                        fontSize: fontSize - 1,
                        height: narrow ? 1.2 : 1.35,
                        color: progress != null
                            ? colors.text
                            : colors.secondaryText,
                      );

                      TextPainter measure(String text, TextStyle style) =>
                          TextPainter(
                            text: TextSpan(
                              text: text,
                              style: defaults.style
                                  .merge(style)
                                  .copyWith(
                                    fontWeight: media.boldText
                                        ? FontWeight.bold
                                        : null,
                                    height: media.lineHeightScaleFactorOverride,
                                    letterSpacing: media.letterSpacingOverride,
                                    wordSpacing: media.wordSpacingOverride,
                                  ),
                            ),
                            textDirection: Directionality.of(context),
                            textScaler: media.textScaler,
                            locale: Localizations.maybeLocaleOf(context),
                            textHeightBehavior:
                                defaults.textHeightBehavior ??
                                DefaultTextHeightBehavior.maybeOf(context),
                            textWidthBasis: defaults.textWidthBasis,
                          )..layout(maxWidth: width);

                      final title = measure(course.name, titleStyle);
                      final room = measure(course.room, roomStyle);
                      var titleLines = title.computeLineMetrics().length;
                      var roomLines = course.room.isEmpty
                          ? 0
                          : room.computeLineMetrics().length;
                      if (title.height +
                              (roomLines > 0 ? room.height + spacing : 0) >
                          available) {
                        title.maxLines = 1;
                        title.layout(maxWidth: width);
                        room.maxLines = 1;
                        room.layout(maxWidth: width);
                        final reserveRoom =
                            roomLines > 0 &&
                            title.height + room.height + spacing <= available;
                        titleLines = _fittingLines(
                          title,
                          width,
                          available - (reserveRoom ? room.height + spacing : 0),
                        );
                        roomLines = reserveRoom
                            ? _fittingLines(
                                room,
                                width,
                                available - title.height - spacing,
                              )
                            : 0;
                      }
                      title.dispose();
                      room.dispose();
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                course.name,
                                textAlign: TextAlign.start,
                                softWrap: true,
                                maxLines: titleLines > 0 ? titleLines : 1,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                            ),
                            if (roomLines > 0) ...[
                              SizedBox(height: spacing),
                              Text(
                                course.room,
                                textAlign: TextAlign.start,
                                softWrap: true,
                                maxLines: roomLines,
                                overflow: TextOverflow.ellipsis,
                                style: roomStyle,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

int _fittingLines(TextPainter painter, double width, double height) {
  // Measure every wrapped line before applying a limit and an ellipsis.
  painter.maxLines = null;
  painter.ellipsis = null;
  painter.layout(maxWidth: width);
  var upper = painter.computeLineMetrics().length;
  if (painter.height <= height) return upper;

  var lower = 0;
  painter.ellipsis = '…';
  while (lower < upper) {
    final middle = (lower + upper + 1) ~/ 2;
    painter.maxLines = middle;
    painter.layout(maxWidth: width);
    if (painter.height <= height) {
      lower = middle;
    } else {
      upper = middle - 1;
    }
  }
  painter.maxLines = lower > 0 ? lower : 1;
  painter.layout(maxWidth: width);
  return lower;
}
