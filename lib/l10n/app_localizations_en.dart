// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'BITree';

  @override
  String get appChineseName => '理枝';

  @override
  String get appTagline =>
      'A handy toolkit for Beijing Institute of Technology.';

  @override
  String get navHome => 'Home';

  @override
  String get navAgenda => 'Agenda';

  @override
  String get navTools => 'Tools';

  @override
  String get navSettings => 'Settings';

  @override
  String get followSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get saving => 'Saving…';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get restore => 'Restore';

  @override
  String get refresh => 'Refresh';

  @override
  String get reload => 'Reload';

  @override
  String get retry => 'Retry';

  @override
  String get confirm => 'Confirm';

  @override
  String get view => 'View';

  @override
  String get showAll => 'Show all';

  @override
  String get edit => 'Edit';

  @override
  String get undo => 'Undo';

  @override
  String get add => 'Add';

  @override
  String get all => 'All';

  @override
  String get more => 'More';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get course => 'Course';

  @override
  String get schedule => 'Schedule';

  @override
  String get agenda => 'Event';

  @override
  String get exam => 'Exam';

  @override
  String get deadline => 'DDL';

  @override
  String get activity => 'Event';

  @override
  String courseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courses',
      one: '1 course',
    );
    return '$_temp0';
  }

  @override
  String sessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String creditCount(String count) {
    return '$count credits';
  }

  @override
  String minuteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String weekNumber(int week) {
    return 'Week $week';
  }

  @override
  String weekNumberCompact(int week) {
    return 'Week $week';
  }

  @override
  String get thisWeekSuffix => ', this week';

  @override
  String get schoolWeek => 'School schedule';

  @override
  String get chooseWeek => 'Choose week';

  @override
  String weekRange(int first, int last) {
    return 'Weeks $first–$last';
  }

  @override
  String weekRangeShort(int first, int last) {
    return '$first - $last weeks';
  }

  @override
  String weekList(String ranges) {
    return 'Weeks $ranges';
  }

  @override
  String get weeksPending => 'Weeks TBD';

  @override
  String get listSeparator => ', ';

  @override
  String get weekdayMonday => 'Monday';

  @override
  String get weekdayTuesday => 'Tuesday';

  @override
  String get weekdayWednesday => 'Wednesday';

  @override
  String get weekdayThursday => 'Thursday';

  @override
  String get weekdayFriday => 'Friday';

  @override
  String get weekdaySaturday => 'Saturday';

  @override
  String get weekdaySunday => 'Sunday';

  @override
  String get weekdayShortMonday => 'Mon';

  @override
  String get weekdayShortTuesday => 'Tue';

  @override
  String get weekdayShortWednesday => 'Wed';

  @override
  String get weekdayShortThursday => 'Thu';

  @override
  String get weekdayShortFriday => 'Fri';

  @override
  String get weekdayShortSaturday => 'Sat';

  @override
  String get weekdayShortSunday => 'Sun';

  @override
  String get weekdayNarrowMonday => 'M';

  @override
  String get weekdayNarrowTuesday => 'T';

  @override
  String get weekdayNarrowWednesday => 'W';

  @override
  String get weekdayNarrowThursday => 'T';

  @override
  String get weekdayNarrowFriday => 'F';

  @override
  String get weekdayNarrowSaturday => 'S';

  @override
  String get weekdayNarrowSunday => 'S';

  @override
  String get monthNames => 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String monthDay(String month, int day) {
    return '$month $day';
  }

  @override
  String yearMonthDay(String month, int day, int year) {
    return '$month $day, $year';
  }

  @override
  String dateWithWeekday(String weekday, String date) {
    return '$weekday, $date';
  }

  @override
  String relativeDateWithWeekday(String relative, String weekday, String date) {
    return '$relative, $weekday, $date';
  }

  @override
  String termFall(String years) {
    return 'Fall $years';
  }

  @override
  String termSpring(String years) {
    return 'Spring $years';
  }

  @override
  String get sectionPending => 'Section TBD';

  @override
  String sectionSingle(int section) {
    return 'Section $section';
  }

  @override
  String sectionRange(int start, int end) {
    return 'Sections $start–$end';
  }

  @override
  String sectionRangeCompact(int start, int end) {
    return 'Periods $start–$end';
  }

  @override
  String get timePending => 'Time TBD';

  @override
  String get locationPending => 'Room TBD';

  @override
  String get allDay => 'All day';

  @override
  String get allDayUntil => 'All-day deadline';

  @override
  String dueAt(String time) {
    return 'Due $time';
  }

  @override
  String endsAt(String time) {
    return 'Ends $time';
  }

  @override
  String startedAt(String time) {
    return 'Started $time';
  }

  @override
  String get completed => 'Completed';

  @override
  String get overdue => 'Overdue';

  @override
  String get ended => 'Ended';

  @override
  String get inProgress => 'In progress';

  @override
  String get due => 'Due';

  @override
  String get start => 'Start';

  @override
  String get end => 'End';

  @override
  String get settingsDeleteScheduleQuestion => 'Delete the local schedule?';

  @override
  String get settingsDeleteScheduleBody =>
      'This deletes schedules for every term, including manually added courses. This cannot be undone.';

  @override
  String get settingsDeleteSchedule => 'Delete schedule';

  @override
  String get settingsTerm => 'Term';

  @override
  String get settingsWeekManagement => 'Week range';

  @override
  String get settingsDeleteLocalSchedule => 'Delete local schedule';

  @override
  String get settingsDeleteDeadlines => 'Delete DDLs';

  @override
  String settingsDeleteDeadlinesBody(int count) {
    return 'Choose sources such as manual, physics lab, Lexue, or E-Learning.\n$count total across all terms, including completed and deleted items';
  }

  @override
  String get settingsLocalSchedule => 'Local schedule';

  @override
  String get settingsLocalAgenda => 'Local agenda';

  @override
  String get settingsApplication => 'Application';

  @override
  String get settingsExportLogs => 'Export logs';

  @override
  String get settingsCheckUpdates => 'Check for updates';

  @override
  String get settingsCheckingUpdates => 'Checking for updates…';

  @override
  String get settingsAbout => 'About BITree';

  @override
  String settingsBuiltAt(String date, String time) {
    return 'Built $date at $time';
  }

  @override
  String get settingsLicenses => 'Licenses';

  @override
  String get aboutOpenBitoolkitFailed => 'Could not open BIToolkit';

  @override
  String get aboutOpenGitHubFailed => 'Could not open GitHub';

  @override
  String get aboutLicenseName => 'BITree 理枝';

  @override
  String get homeTitle => 'Home';

  @override
  String get backToThisWeek => 'Back to this week';

  @override
  String get timedCourses => 'Courses without a fixed time';

  @override
  String get addCourse => 'Add course';

  @override
  String get chooseCourse => 'Choose a course';

  @override
  String coursesOverlap(int count, String summary) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courses have time conflicts, $summary. Choose a course',
      one: '1 course has a time conflict, $summary. Choose a course',
    );
    return '$_temp0';
  }

  @override
  String courseOverlapCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courses',
      one: '1 course',
    );
    return '$_temp0';
  }

  @override
  String courseOngoingUntil(String time) {
    return 'In class · ends $time';
  }

  @override
  String minutesUntilEnd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes left',
      one: '1 minute left',
    );
    return '$_temp0';
  }

  @override
  String get courseNext => 'Next class';

  @override
  String get sameBuilding => 'Same building';

  @override
  String get sameArea => 'Move within the same area';

  @override
  String get differentArea => 'Move across campus areas';

  @override
  String get copyCourseNameSuccess => 'Course name copied';

  @override
  String get copyCourseNameFailure => 'Copy failed. Try again.';

  @override
  String get deleteCourseQuestion => 'Delete this course?';

  @override
  String deleteCourseBody(String course) {
    return 'Remove “$course” from the local schedule?';
  }

  @override
  String get deleteCourse => 'Delete course';

  @override
  String courseDetailsSemantics(
    String name,
    String time,
    String room,
    String progress,
  ) {
    return '$name, $time, $room$progress, view details';
  }

  @override
  String get courseIsToday => ', today';

  @override
  String get courseIsOngoing => ', in progress';

  @override
  String get courseEditorAddTitle => 'Add course';

  @override
  String get courseEditorEditTitle => 'Edit course';

  @override
  String get courseEditorSave => 'Save course';

  @override
  String get courseEditorTerm => 'Term';

  @override
  String get courseEditorTermRequired => 'Enter a term';

  @override
  String get courseEditorMonday => 'Monday of week 1';

  @override
  String get courseEditorMondayHelp => 'Choose Monday of week 1';

  @override
  String courseEditorMondayLabel(String date) {
    return 'Monday of week 1: $date';
  }

  @override
  String get courseEditorName => 'Course name';

  @override
  String get courseEditorNameRequired => 'Enter a course name';

  @override
  String get courseEditorRoom => 'Room (optional)';

  @override
  String get courseEditorTeacher => 'Instructor (optional)';

  @override
  String get courseEditorWeekday => 'Weekday';

  @override
  String get courseEditorWeeksRequired => 'Select at least one week';

  @override
  String get courseEditorWeeks => 'Weeks';

  @override
  String get courseEditorPeriodStart => 'Starting section';

  @override
  String get courseEditorPeriodEnd => 'Ending section';

  @override
  String coursePeriodRange(
    int section,
    String linebreak,
    String start,
    String end,
  ) {
    return 'Section $section$linebreak($start–$end)';
  }

  @override
  String get weekSelectionAll => 'All';

  @override
  String get weekSelectionNone => 'None';

  @override
  String get weekSelectionSummer => 'Summer term';

  @override
  String get weekSelectionRegular => 'Regular term';

  @override
  String get weekManagement => 'Week range';

  @override
  String get weekIntegerRequired => 'Enter a whole-number week';

  @override
  String get weekZeroInvalid => 'Week 0 does not exist';

  @override
  String get decreaseWeek => 'Remove one week';

  @override
  String get increaseWeek => 'Add one week';

  @override
  String get weekOrderInvalid => 'The end week cannot be before the start week';

  @override
  String get weekStart => 'Start week';

  @override
  String get weekEnd => 'End week';

  @override
  String get weekRangeDialogTitle => 'Week range';

  @override
  String monthHeader(String month) {
    return '$month';
  }

  @override
  String timetableDaySemantics(
    String date,
    String weekday,
    String today,
    String agenda,
  ) {
    return '$weekday, $date$today$agenda';
  }

  @override
  String get timetableTodaySuffix => ', today';

  @override
  String timetableAgendaSuffix(int count) {
    return ', $count agenda items';
  }

  @override
  String sectionSemantics(int section, String start, String end) {
    return 'Section $section, $start–$end';
  }

  @override
  String get exportSchedule => 'Export schedule';

  @override
  String get exportScheduleEmpty =>
      'There are no courses to export. Add a course or set its class time first.';

  @override
  String get exportScheduleSuccess => 'Schedule exported';

  @override
  String exportScheduleSkipped(int count) {
    return 'Schedule exported; skipped $count courses without a fixed time';
  }

  @override
  String get desktopAgendaWidget => 'Desktop agenda';

  @override
  String get exportIcs => 'Export ICS';

  @override
  String icsCalendarName(String term) {
    return 'BITree $term';
  }

  @override
  String icsEventDescription(String week, String section) {
    return '$week, $section';
  }

  @override
  String icsTeacher(String teacher) {
    return 'Instructor: $teacher';
  }

  @override
  String icsCourseNumber(String number) {
    return 'Course number: $number';
  }

  @override
  String get agendaTitle => 'Agenda';

  @override
  String get agendaReload => 'Reload agenda';

  @override
  String agendaPendingTab(int count) {
    return 'To do $count';
  }

  @override
  String agendaCompletedTab(int count) {
    return 'Completed $count';
  }

  @override
  String get agendaSwitchToList => 'Switch to list';

  @override
  String get agendaSwitchToTimeline => 'Switch to timeline';

  @override
  String agendaOverdueHiddenLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count overdue agenda items',
      one: '1 overdue agenda item',
    );
    return '$_temp0';
  }

  @override
  String get agendaNoCompleted => 'No completed agenda items yet';

  @override
  String get agendaNoUpcoming => 'No upcoming agenda items';

  @override
  String get agendaNoPending => 'No pending agenda items';

  @override
  String get agendaType => 'Agenda type';

  @override
  String agendaCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agenda items',
      one: '1 agenda item',
    );
    return '$_temp0';
  }

  @override
  String get agendaNoPendingShort => 'No pending agenda items';

  @override
  String agendaCompletedCount(int count) {
    return 'Completed $count';
  }

  @override
  String get agendaDayEmpty => 'Nothing scheduled for this day';

  @override
  String get agendaChooseItems => 'Choose an item';

  @override
  String agendaItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get agendaDetails => 'Agenda details';

  @override
  String agendaOverdueAt(String time) {
    return 'Overdue at $time';
  }

  @override
  String agendaStartsAt(String time) {
    return 'Starts at $time';
  }

  @override
  String get agendaMarkDone => 'Mark complete';

  @override
  String get agendaMarkUndone => 'Mark incomplete';

  @override
  String get agendaNotes => 'Notes';

  @override
  String get agendaOpenLink => 'Open assignment';

  @override
  String get agendaDueBeforeEndOfDay => 'Before the end of that day';

  @override
  String get agendaDeleteAction => 'Delete';

  @override
  String get agendaSwipeDelete => 'Delete';

  @override
  String get agendaSwipeDeleteRelease => 'Release to delete';

  @override
  String get agendaSwipeRestore => 'Mark incomplete';

  @override
  String get agendaSwipeRestoreRelease => 'Release to restore';

  @override
  String get agendaSwipeDone => 'Complete';

  @override
  String get agendaSwipeDoneRelease => 'Release to complete';

  @override
  String agendaDeleteQuestion(String kind) {
    return 'Delete $kind?';
  }

  @override
  String agendaRestored(String title) {
    return 'Restored “$title”';
  }

  @override
  String agendaDeleted(String title) {
    return 'Deleted “$title”';
  }

  @override
  String agendaAddTitle(String kind) {
    return 'Add $kind';
  }

  @override
  String get addAgenda => 'Add event';

  @override
  String get addDeadline => 'Add DDL';

  @override
  String agendaEditTitle(String kind) {
    return 'Edit $kind';
  }

  @override
  String get agendaName => 'Name';

  @override
  String get agendaNameRequired => 'Enter a name';

  @override
  String get agendaAllDay => 'All day';

  @override
  String get agendaLocationOptional => 'Location (optional)';

  @override
  String get agendaNotesOptional => 'Notes (optional)';

  @override
  String get agendaEndAfterStart => 'The end must be later than the start';

  @override
  String agendaReminderOverdue(String time) {
    return '$time · overdue';
  }

  @override
  String agendaReminderStarts(String time) {
    return '$time · starts';
  }

  @override
  String agendaReminderCount(int count) {
    return '$count to do';
  }

  @override
  String get agendaReminderCollapse => 'Collapse reminders';

  @override
  String get agendaTimelineOneDay => '1 day / cell';

  @override
  String get agendaTimelineOneHour => '1 hour / cell';

  @override
  String agendaTimelineHours(String hours) {
    return '$hours hours / cell';
  }

  @override
  String get agendaTimelineZoom =>
      'Zoom: from one day per cell to one hour per cell';

  @override
  String get agendaTimelineEmpty =>
      'No agenda items\nDrag the timeline or add a new item';

  @override
  String get agendaTimelineSemantics => 'Agenda timeline';

  @override
  String get agendaTimelineAllDay => 'All day';

  @override
  String agendaTimelineStarts(String time) {
    return 'Starts: $time';
  }

  @override
  String agendaTimelineEnds(String time) {
    return 'Ends: $time';
  }

  @override
  String agendaTimelineDue(String time) {
    return 'Due: $time';
  }

  @override
  String agendaTimelineCourse(String course) {
    return 'Course: $course';
  }

  @override
  String agendaTimelineLocation(String location) {
    return 'Location: $location';
  }

  @override
  String agendaTimelineSemanticsEntry(
    String kind,
    String title,
    String time,
    String course,
    String location,
    String status,
  ) {
    return '$kind, $title, $time$course$location$status';
  }

  @override
  String get agendaTimelineStatusCompleted => 'Status: completed';

  @override
  String get agendaTimelineStatusOverdue => 'Status: overdue';

  @override
  String get agendaTimelineStatusEnded => 'Status: ended';

  @override
  String get clearDeadlinesTitle => 'Delete DDLs';

  @override
  String get clearDeadlinesIntro =>
      'Select one or more sources. Counts include every term and completed or deleted DDLs.';

  @override
  String get clearDeadlinesSelectAll => 'Select all';

  @override
  String clearDeadlinesSourceCount(String source, int count) {
    return '$source ($count)';
  }

  @override
  String clearDeadlinesSelection(int categories, int count) {
    return '$categories selected, $count DDLs total.';
  }

  @override
  String get clearDeadlinesWarning =>
      'This cannot be undone and deleted DDLs cannot be restored. Unselected sources, exams, and other agenda items are unaffected.';

  @override
  String get clearDeadlinesRecovery =>
      'Platform DDLs can be synchronized again; physics lab DDLs can be regenerated from the schedule; manually created DDLs cannot be restored.';

  @override
  String clearDeadlinesDeleteCount(int count) {
    return 'Delete $count DDLs';
  }

  @override
  String get clearDeadlinesDeleting => 'Deleting…';

  @override
  String get clearDeadlinesUnavailable =>
      'The agenda is not loaded or is being saved. Try again shortly.';

  @override
  String clearDeadlinesDeleted(int count) {
    return 'Deleted $count DDLs.';
  }

  @override
  String get deletedDeadlinesTitle => 'Deleted DDLs';

  @override
  String get deletedDeadlinesNone => 'No deleted DDLs';

  @override
  String get deletedDeadlinesRestoreAll => 'Restore all';

  @override
  String get deletedDeadlinesRestoreAction => 'Restore';

  @override
  String deletedDeadlinesRestored(String title) {
    return 'Restored “$title”';
  }

  @override
  String get deletedDeadlinesRestoredAll => 'Restored all DDLs';

  @override
  String get deadlineManual => 'Manually created';

  @override
  String get deadlineManualScope => 'Manually created DDLs';

  @override
  String get deadlineManualScopeDescription =>
      'Manually added DDLs, excluding physics lab and synchronized platform items';

  @override
  String get deadlinePhysicsLab => 'Physics lab DDLs';

  @override
  String get deadlinePhysicsLabScopeDescription =>
      'Physics lab DDLs generated from the schedule, including locally edited items';

  @override
  String get deadlineLexue => 'Lexue DDLs';

  @override
  String get deadlineLexueScopeDescription =>
      'DDLs synchronized from Lexue, including locally edited items';

  @override
  String get deadlineEclass => 'E-Learning DDLs';

  @override
  String get deadlineEclassScopeDescription =>
      'DDLs synchronized from E-Learning, including locally edited items';

  @override
  String get deadlineMooc => 'MOOC DDLs';

  @override
  String get deadlineMoocScopeDescription =>
      'DDLs synchronized from China University MOOC, including locally edited items';

  @override
  String get deadlineSourceLexue => 'Lexue';

  @override
  String get deadlineSourceEclass => 'E-Learning';

  @override
  String get deadlineSourceMooc => 'China University MOOC';

  @override
  String get deadlineSourcePlatform => 'Platform DDL';

  @override
  String get agendaKindEvent => 'Event';

  @override
  String get agendaKindDeadline => 'DDL';

  @override
  String get agendaKindExam => 'Exam';

  @override
  String timeRange(String start, String end) {
    return '$start–$end';
  }

  @override
  String get syncAll => 'Sync all';

  @override
  String get customSync => 'Custom sync';

  @override
  String get deletedDdlMenu => 'Deleted DDLs';

  @override
  String get syncTooltip => 'Sync';

  @override
  String get viewSyncProgress => 'View sync progress';

  @override
  String get syncComplete => 'Sync complete';

  @override
  String get syncPartial => 'Some items were not synchronized';

  @override
  String selectedItems(int count) {
    return '$count selected';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get clearSelection => 'Clear';

  @override
  String get loginAfterSelection => 'Not signed in; sign in after selecting';

  @override
  String get syncSelected => 'Sync selected';

  @override
  String get syncProgress => 'Sync progress';

  @override
  String get collapse => 'Collapse';

  @override
  String syncProcessed(int done, int total) {
    return 'Processed $done / $total';
  }

  @override
  String get syncCancelled => 'Sync cancelled';

  @override
  String get continueAfterCollapse => 'Continues after collapsing';

  @override
  String get cancelSync => 'Cancel sync';

  @override
  String get cancelling => 'Cancelling…';

  @override
  String get verifying => 'Verifying…';

  @override
  String get retryIncomplete => 'Retry incomplete items';

  @override
  String get syncTargetSchedule => 'Schedule';

  @override
  String get syncTargetExams => 'Exam schedule';

  @override
  String get syncTargetGrades => 'Grades';

  @override
  String get syncTargetStudyPlan => 'Credit progress';

  @override
  String get syncTargetLexue => 'Lexue DDLs';

  @override
  String get syncTargetEclass => 'E-Learning DDLs';

  @override
  String get syncTargetMooc => 'MOOC DDLs';

  @override
  String get syncTargetPhysicsLab => 'Physics lab DDLs';

  @override
  String get syncActionSchedule => 'Sync schedule';

  @override
  String get syncActionExams => 'Sync exam schedule';

  @override
  String get syncActionGrades => 'Sync grades';

  @override
  String get syncActionStudyPlan => 'Sync credit progress';

  @override
  String get syncActionLexue => 'Sync Lexue DDLs';

  @override
  String get syncActionEclass => 'Sync E-Learning DDLs';

  @override
  String get syncActionMooc => 'Sync MOOC DDLs';

  @override
  String get syncActionPhysicsLab => 'Update physics lab DDLs';

  @override
  String get syncing => 'Synchronizing…';

  @override
  String get waitingForSchool => 'Waiting for the school request';

  @override
  String get waitingToSync => 'Waiting to sync';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get synced => 'Synced';

  @override
  String get syncNotFinished => 'Sync did not finish. Try again.';

  @override
  String get noScheduleAvailable => 'No schedule available';

  @override
  String get physicsLabSaveFailed => 'Could not save physics lab DDLs';

  @override
  String physicsLabPreviewReport(String course) {
    return 'Pre-lab report $course';
  }

  @override
  String physicsLabReport(String course) {
    return 'Lab report $course';
  }

  @override
  String physicsLabGeneratedNotes(String term, String date, String time) {
    return 'Generated from the $term schedule\nClass: $date $time';
  }

  @override
  String updatedDdlCount(int count) {
    return 'Updated $count DDLs';
  }

  @override
  String get syncResultSaveFailed => 'Could not save the sync result';

  @override
  String syncedDdlCount(int count) {
    return 'Synced $count DDLs';
  }

  @override
  String get syncFailed => 'Sync failed. Try again.';

  @override
  String get schoolLoginRequired => 'Sign in to your school account';

  @override
  String get syncVerificationRequired => 'Complete school sign-in verification';

  @override
  String syncCourseFailure(String course, String message) {
    return '$course: $message';
  }

  @override
  String get accountUnverified => 'Not connected';

  @override
  String get accountSignedIn => 'Signed in';

  @override
  String get accountSignedOut => 'Signed out';

  @override
  String get accountExpired => 'Sign in again';

  @override
  String get accountSmsRequired => 'SMS verification required';

  @override
  String get accountImageRequired => 'Image verification required';

  @override
  String get moocName => 'China University MOOC';

  @override
  String get moocSignOutQuestion => 'Sign out of China University MOOC?';

  @override
  String get moocSignOutBody =>
      'The saved login session on this device will be deleted. Imported DDLs will remain.';

  @override
  String get exitAction => 'Exit';

  @override
  String get webLogin => 'Web sign-in';

  @override
  String get relogin => 'Sign in again';

  @override
  String get moocLoginMethods => 'Phone, email, verification code, or QR code';

  @override
  String get useCookie => 'Use cookies';

  @override
  String get backupLogin => 'Backup sign-in method';

  @override
  String get moocSignOutAccount => 'Sign out';

  @override
  String get moocConnectionCancelled => 'Connection cancelled';

  @override
  String get moocConnecting => 'Connecting…';

  @override
  String get connect => 'Connect';

  @override
  String get moocCookieInstructions =>
      'In a signed-in MOOC web page, copy the request Cookie from the Network panel in developer tools. Use this only when web sign-in does not work.';

  @override
  String get moocPasteCookie => 'Paste a Cookie';

  @override
  String get openMoocFailed => 'Could not open MOOC';

  @override
  String get openOfficialLogin => 'Open official sign-in page';

  @override
  String get moocLoginTitle => 'Sign in to China University MOOC';

  @override
  String get refreshLoginPage => 'Refresh sign-in page';

  @override
  String get completeLogin => 'Finish sign-in';

  @override
  String get moocLoginPageLoadFailed =>
      'The sign-in page could not load. Check your connection and refresh.';

  @override
  String get moocLoginPageOpenFailed =>
      'Could not open the sign-in page. Try again.';

  @override
  String get moocOpenAppFailed =>
      'Could not open the app. Choose another sign-in method on the page.';

  @override
  String get moocCompleteLoginFirst => 'Complete sign-in on the page first.';

  @override
  String get moocAccountReadFailed =>
      'Could not read the MOOC account. Refresh the sign-in page.';

  @override
  String get moocSessionNotReady =>
      'The login session is not ready yet. Try again shortly.';

  @override
  String get moocSavingLogin => 'Saving sign-in…';

  @override
  String get moocLoginStateReadFailed =>
      'Could not read the sign-in state. Refresh or tap “Finish sign-in” to retry.';

  @override
  String get moocConnected => 'Connected';

  @override
  String get moocNeedsLogin => 'Sign in again';

  @override
  String get moocSignedOut => 'Not signed in';

  @override
  String get moocLoginRequired =>
      'Sign in to your China University MOOC account';

  @override
  String get moocUserFallback => 'MOOC user';

  @override
  String get moocReadingCourses => 'Reading MOOC courses…';

  @override
  String get moocReadingSpocCourses => 'Reading SPOC courses…';

  @override
  String moocReadingCourse(int done, int total, String course) {
    return 'Reading $done/$total: $course';
  }

  @override
  String get moocNoSession =>
      'No China University MOOC session was found. Sign in first.';

  @override
  String get moocLoginExpired =>
      'The China University MOOC session expired. Sign in again.';

  @override
  String get moocRequestBusy =>
      'MOOC is already handling a request. Try again shortly.';

  @override
  String get moocReadAccountFailed =>
      'Could not read the saved MOOC sign-in. Sign in again.';

  @override
  String get moocSaveResultFailed =>
      'Could not save the sync result. Try again shortly.';

  @override
  String get schoolLogin => 'Sign in to school account';

  @override
  String get schoolStudentId => 'Student ID';

  @override
  String get schoolEnterStudentId => 'Enter your student ID';

  @override
  String get schoolPassword => 'Password';

  @override
  String get schoolEnterPassword => 'Enter your password';

  @override
  String get schoolShowPassword => 'Show password';

  @override
  String get schoolHidePassword => 'Hide password';

  @override
  String get schoolLoggingIn => 'Signing in…';

  @override
  String get schoolSignOutQuestion => 'Sign out of the school account?';

  @override
  String get schoolSignOutBody =>
      'The sign-in information on this device will be removed. Local schedules and agenda items will remain.';

  @override
  String get schoolSignOutAction => 'Sign out';

  @override
  String get verifyAction => 'Verify';

  @override
  String get schoolVerified => 'School account verified';

  @override
  String get schoolSmsVerification => 'SMS verification';

  @override
  String get schoolImageVerification => 'Image verification';

  @override
  String schoolSentToPhone(String phone) {
    return 'Sent to $phone';
  }

  @override
  String get schoolVerificationCode => 'Verification code';

  @override
  String get schoolEnterVerificationCode => 'Enter the verification code';

  @override
  String get schoolRefreshImage => 'New image';

  @override
  String schoolResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get schoolResend => 'Resend';

  @override
  String get schoolVerifying => 'Verifying…';

  @override
  String get toolsTitle => 'Tools';

  @override
  String get gradesAndAcademics => 'Grades and academics';

  @override
  String get gradeSimulation => 'Grade projection';

  @override
  String get creditProgress => 'Degree credit progress';

  @override
  String get examScheduleTool => 'Exam schedule and conflict check';

  @override
  String get emptyClassroomQuery => 'Find empty classrooms';

  @override
  String get wencuiMap => 'Wencui map';

  @override
  String get logsTitle => 'Logs';

  @override
  String get logsRecent => 'Last 100 lines, kept locally for seven days';

  @override
  String get exportingLogs => 'Exporting…';

  @override
  String get exportLogs => 'Export logs';

  @override
  String get reloadLogs => 'Reload logs';

  @override
  String get noLogs => 'No logs';

  @override
  String get logsExported => 'Logs exported';

  @override
  String get widgetGuideTitle => 'Desktop agenda';

  @override
  String get widgetSingleColumn => '2×2 single column';

  @override
  String get widgetDoubleColumn => '2×4 double column';

  @override
  String get widgetStepOpen =>
      'Touch and hold an empty area of the desktop, then open Widgets.';

  @override
  String get widgetStepFind =>
      'Find the BITree agenda, choose a single- or double-column layout, and drag it to the desktop.';

  @override
  String get widgetStepScroll =>
      'Scroll up or down to see courses, exams, DDLs, and events.';

  @override
  String get widgetGuideTomorrow =>
      'After today\'s schedule ends, tomorrow\'s agenda is shown from 21:00.';

  @override
  String get gotIt => 'Got it';

  @override
  String openInBrowser(String url) {
    return 'Open this link in a browser:\n$url';
  }

  @override
  String get takeBack => 'Take back';

  @override
  String viewHidden(String label) {
    return 'View $label';
  }

  @override
  String releaseToView(String label) {
    return 'Release to view $label';
  }

  @override
  String pullToView(String label) {
    return 'Pull down to view $label';
  }

  @override
  String get gpaRules => 'GPA rules';

  @override
  String get gpaRulesTitle => 'GPA calculation rules';

  @override
  String get gpaRuleIntro =>
      'Uses the Beijing Institute of Technology undergraduate GPA calculation method (trial).';

  @override
  String get gpaRulePercent =>
      'Percentage scores: 60 and above use 4 − 3 × (100 − score)² ÷ 1600, rounded to one decimal place; below 60 is 0.';

  @override
  String get gpaRuleFive =>
      'Five-level scores: Excellent 4.0, Good 3.6, Average 2.8, Pass 1.7, Fail 0.';

  @override
  String get gpaRuleWeighting =>
      'Weighted by credits. Only the highest result for a course is used; failed university elective courses do not count toward GPA. Pass/fail courses contribute credits only, and the weighted average uses percentage scores only.';

  @override
  String get openGpaRulesFailed => 'Could not open the GPA rules';

  @override
  String get schoolSource => 'School source';

  @override
  String syncedAt(String date, String time) {
    return 'Synchronized $date $time';
  }

  @override
  String get failedCourse => 'Not passed';

  @override
  String get gradesReadFailed => 'Academic data is temporarily unavailable';

  @override
  String get noSyncedGrades => 'No grades have been synchronized';

  @override
  String get allSemesters => 'All semesters';

  @override
  String get averageGpa => 'Average GPA';

  @override
  String get weightedAverageScore => 'Weighted average';

  @override
  String get earnedCredits => 'Credits earned';

  @override
  String get courseGrades => 'Course grades';

  @override
  String get termPerformance => 'Term performance';

  @override
  String get onlyFailedCourses => 'Showing failed courses only';

  @override
  String coursesNotPassed(int count) {
    return '$count courses not passed';
  }

  @override
  String termCoursesNotPassed(int count) {
    return '$count courses were not passed this term';
  }

  @override
  String get noGradesThisTerm => 'No grades in this semester';

  @override
  String weightedAverageValue(String value) {
    return 'Weighted average $value';
  }

  @override
  String get creditProgressTitle => 'Degree credit progress';

  @override
  String get reviewCreditTargets => 'Review credit targets';

  @override
  String get academicReadFailed => 'Academic data is temporarily unavailable';

  @override
  String get noCreditRecords => 'No credit records yet';

  @override
  String get creditsFromGrades => 'Credits earned from grades';

  @override
  String get completedCreditsSchool => 'Credits completed in school records';

  @override
  String get schoolRequiredCredits => 'Credits required by the school';

  @override
  String get reviewTargetCredits => 'Reviewed target credits';

  @override
  String get creditsRemaining => 'Credits remaining';

  @override
  String get notAvailable => 'Not available';

  @override
  String requiredCoursesPending(int count) {
    return '$count required courses still to pass';
  }

  @override
  String get pendingRequiredCourses => 'Required courses still to pass';

  @override
  String get reviewByCategory => 'Review by course category';

  @override
  String get setTargets => 'Set targets';

  @override
  String get syncGradesForCredit => 'Sync grades to view category credits';

  @override
  String get creditCategoryNote =>
      'Category credits are based on synchronized grades, counting each course once. Check category requirements against your study plan; in-progress credits are not estimated. Graduation is subject to school review.';

  @override
  String get noCategoryGrades => 'No course grades in this category';

  @override
  String credits(String count) {
    return '$count credits';
  }

  @override
  String creditProgressValue(String earned, String target) {
    return '$earned / $target';
  }

  @override
  String get creditTargetNotSet => 'No category target set';

  @override
  String creditsStillNeeded(String count) {
    return '$count more credits needed';
  }

  @override
  String get totalCreditTarget => 'Total credit target';

  @override
  String get leaveBlankSchoolRequirement =>
      'Leave blank to use the school requirement';

  @override
  String categoryCreditTarget(String category) {
    return '$category credit target';
  }

  @override
  String get leaveBlankCancelTarget =>
      'Leave blank to cancel this category target';

  @override
  String get addCourseCategory => 'Add course category';

  @override
  String get addCategory => 'Add category';

  @override
  String get enterNonNegativeCredits =>
      'Enter a non-negative number of credits';

  @override
  String get examScheduleAndConflicts => 'Exam schedule and conflict check';

  @override
  String get checkLocalSchedule => 'Also check the local schedule';

  @override
  String get syncScheduleConflictHint =>
      'Sync a schedule to check exam and class time conflicts.';

  @override
  String timeConflictsFound(int count) {
    return '$count time conflicts found';
  }

  @override
  String get noUpcomingExams => 'No upcoming exams';

  @override
  String get noExams => 'No exams scheduled';

  @override
  String get hideFinishedExams => 'Hide finished exams';

  @override
  String get showFinishedExams => 'Show finished exams';

  @override
  String get examAgendaSharedNote =>
      'Exams and agenda items share records. Syncing, editing, and deleting affect both places.';

  @override
  String overlapsClass(String title) {
    return 'Overlaps $title class time';
  }

  @override
  String overlapsExam(String title) {
    return 'Overlaps $title exam time';
  }

  @override
  String get timeConflict => 'Time conflict';

  @override
  String get noTimeConflict => 'No time conflicts';

  @override
  String overlapMinutes(String date, int minutes) {
    return '$date  Overlap: $minutes minutes';
  }

  @override
  String get courseGradeTitle => 'Course grade';

  @override
  String get courseNumber => 'Course number';

  @override
  String get courseCredits => 'Course credits';

  @override
  String get courseAttribute => 'Course attribute';

  @override
  String get courseCategory => 'Course category';

  @override
  String get examType => 'Exam type';

  @override
  String get courseGpa => 'Course GPA';

  @override
  String get notCounted => 'Not counted';

  @override
  String get creditReviewCategory => 'Credit review category';

  @override
  String get simulateRetake => 'Project retake grade';

  @override
  String get removeSimulatedCourseQuestion => 'Remove projected course?';

  @override
  String get removeAction => 'Remove';

  @override
  String currentGpaCredits(String credits, String gpa) {
    return 'Current GPA credits $credits, average GPA $gpa';
  }

  @override
  String get simulateByCourse => 'Project by course';

  @override
  String get targetBackCalculation => 'Target back-calculation';

  @override
  String get targetCumulativeGpa => 'Target cumulative GPA';

  @override
  String get enterGpaRange => 'Enter a GPA from 0 to 4';

  @override
  String get requiredPerCourse => 'Each projected course must reach';

  @override
  String get projectedCumulativeGpa => 'Projected cumulative GPA';

  @override
  String get addSimulatedCourseFirst => 'Add a projected course first';

  @override
  String get targetUnreachable =>
      'Target cannot be reached even with full marks';

  @override
  String scoreValue(String score) {
    return '$score points';
  }

  @override
  String gpaChange(String value) {
    return 'Cumulative GPA change $value';
  }

  @override
  String get simulatedCourses => 'Projected courses';

  @override
  String get retake => 'Retake';

  @override
  String get editAction => 'Edit';

  @override
  String get removeSimulatedCourse => 'Remove projected course';

  @override
  String get retakeUsesHighest => 'Use the highest retake grade';

  @override
  String get simulationDoesNotChange =>
      'Projection does not change synchronized grades.';

  @override
  String get simulationIncludesBoth =>
      'This projection counts both the original and retake grades instead of applying the school\'s highest-grade rule.';

  @override
  String get addProjectedCourse => 'Add projected course';

  @override
  String get editProjectedCourse => 'Edit projected course';

  @override
  String get selectCourseOptional => 'Select course (optional)';

  @override
  String get manualEntry => 'Enter manually';

  @override
  String retakeSuffix(String name) {
    return '$name (retake)';
  }

  @override
  String get courseName => 'Course name';

  @override
  String get enterCourseName => 'Enter a course name';

  @override
  String get enterPositiveCredits => 'Enter credits greater than 0';

  @override
  String get expectedScore => 'Expected score';

  @override
  String get enterScoreRange => 'Enter a score from 0 to 100';

  @override
  String get loadBuildings => 'Load buildings';

  @override
  String get noQueryableCampuses => 'No campuses available to query';

  @override
  String get reloadAction => 'Reload';

  @override
  String get campus => 'Campus';

  @override
  String get date => 'Date';

  @override
  String todayDate(String date) {
    return 'Today $date';
  }

  @override
  String tomorrowDate(String date) {
    return 'Tomorrow $date';
  }

  @override
  String get otherDate => 'Other date';

  @override
  String get building => 'Building';

  @override
  String get allBuildings => 'All buildings';

  @override
  String get wencuiBuildingAll => 'Wencui Building (all)';

  @override
  String get classroomFreeTime => 'Classroom availability';

  @override
  String get roomsMatchingPeriod => 'Rooms matching the selected time';

  @override
  String get querying => 'Querying…';

  @override
  String roomCount(int count) {
    return '$count rooms';
  }

  @override
  String get showsFreePeriods => 'Shows each room\'s free periods for the day';

  @override
  String freeThroughoutPeriod(String period) {
    return 'Free throughout $period';
  }

  @override
  String get loginToQuery => 'Sign in to query empty classrooms';

  @override
  String get queryIncomplete => 'Query did not finish';

  @override
  String get queryAgain => 'Query again';

  @override
  String get noBuildingInfo => 'No building information for this campus yet';

  @override
  String get noFreeClassrooms => 'No empty classrooms during this period';

  @override
  String get noFreePeriods => 'No free periods that day';

  @override
  String get reloadBuildings => 'Reload buildings';

  @override
  String get viewAnyPeriod => 'View any period';

  @override
  String get viewAllBuildings => 'View all buildings';

  @override
  String get changeDate => 'Change date';

  @override
  String get freeMeansNoClass =>
      'Free means no class is scheduled during that period';

  @override
  String get busyStatus => 'Class';

  @override
  String get freeStatus => 'Free';

  @override
  String get allPeriods => 'Any period';

  @override
  String get currentPeriod => 'Current period';

  @override
  String get morning => 'Morning';

  @override
  String get afternoon => 'Afternoon';

  @override
  String get evening => 'Evening';

  @override
  String get customPeriods => 'Choose periods';

  @override
  String get freeTime => 'Free time';

  @override
  String get viewAllFreePeriods => 'View all free periods for the day';

  @override
  String get chooseOneOrMoreSections =>
      'Choose one or more consecutive periods';

  @override
  String get chooseFreePeriod => 'Choose free periods';

  @override
  String get periodSelectionHint =>
      'Choose the start period, then the end period. Choose one period to apply immediately.';

  @override
  String freeThroughoutSections(String period) {
    return 'Free throughout $period';
  }

  @override
  String sectionShort(int section) {
    return 'Period $section';
  }

  @override
  String periodAndSection(String time, String section) {
    return '$time ($section)';
  }

  @override
  String get apply => 'Apply';

  @override
  String get mapInfoTitle => 'Map help';

  @override
  String get mapInfoBody =>
      'Tap a building to zoom in, then tap a room to see its location. Use two fingers, the mouse wheel, or the zoom buttons to change scale.\n\nOn floor plans, east is up and north is left; the original aspect ratio is preserved. Floor plans 1–10 and the location index are stored locally and require no sign-in. Unindexed room numbers locate the building only.\n\nThe base maps come from a public archive of the school\'s Wencui map. Door and passage availability may differ on site.';

  @override
  String get mapSource => 'Map source';

  @override
  String get school3dNavigation => 'School 3D map';

  @override
  String get openMapSourceFailed => 'Could not open the map source';

  @override
  String get openSchoolNavigationFailed => 'Could not open the school map';

  @override
  String get myWencuiCourses => 'My Wencui courses';

  @override
  String get viewBuildingBounds => 'View building bounds';

  @override
  String get wencuiCourseSearchHint =>
      'Room number, course name, stairs, or lift';

  @override
  String get wencuiSearchHint => 'Room number or course name, e.g. F704';

  @override
  String get noMapResults =>
      'No result. Try F704, J1006, or a course name from the schedule.';

  @override
  String get upperFloor => 'Floor above';

  @override
  String get lowerFloor => 'Floor below';

  @override
  String currentFloor(int floor) {
    return 'Floor $floor';
  }

  @override
  String selectFloorSemantics(int floor) {
    return 'Select floor; currently floor $floor';
  }

  @override
  String get tapBuildingOrSearch =>
      'Tap a building to zoom in, or search for a room';

  @override
  String wencuiRoomDetails(String wing, String floor) {
    return 'Wencui Building $wing · $floor';
  }

  @override
  String viewingFloor(String details, int floor) {
    return '$details, viewing floor $floor';
  }

  @override
  String get clearDestination => 'Clear destination';

  @override
  String roomNotMarked(String room, String wing) {
    return '$room is not marked on this floor plan. Showing the $wing bounds.';
  }

  @override
  String selectedFeature(String title) {
    return 'Selected: $title';
  }

  @override
  String get stairs => 'Stairs';

  @override
  String get lift => 'Lift';

  @override
  String get restroom => 'Restroom';

  @override
  String get firstFloorEntrance => 'Ground-floor entrance';

  @override
  String get backToBuilding => 'Back to building';

  @override
  String get backToRoom => 'Back to room';

  @override
  String get mapLoadFailed =>
      'Could not load the map. Reopen it; details can be exported from Logs in Settings.';

  @override
  String get mapLegend => 'East ↑ · North ←';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get fitFloor => 'Fit floor';

  @override
  String get returnToSelection => 'Return to selection';

  @override
  String enlargeWing(String wing) {
    return 'Enlarge Wencui Building $wing';
  }

  @override
  String featureSemantics(String title, int floor) {
    return '$title, floor $floor';
  }

  @override
  String floorPlanSemantics(int floor) {
    return 'Wencui Building floor $floor plan, east up, north left';
  }

  @override
  String wencuiLocation(String room) {
    return 'Wencui Building $room';
  }

  @override
  String wencuiWingFloor(String wing, int floor) {
    return '$wing · Floor $floor';
  }

  @override
  String wencuiWing(String wing) {
    return 'Wing $wing';
  }

  @override
  String wencuiFeatureLocation(String place, String feature) {
    return '$place · $feature';
  }

  @override
  String wencuiWingFloorRange(String wing, int first, int last) {
    return '$wing · Floors $first–$last';
  }

  @override
  String get viewClassroomLocation => 'View classroom location';

  @override
  String get latestVersion => 'You\'re on the latest version';

  @override
  String get updateCheckFailed =>
      'Could not check for updates. Check your connection and try again.';

  @override
  String get updateAvailable => 'Update available';

  @override
  String get developmentBuild => 'Beta';

  @override
  String get stableBuild => 'Stable';

  @override
  String get unableOpenDownload => 'Could not open the download link';

  @override
  String get unableOpenLink => 'Could not open the link';

  @override
  String get later => 'Later';

  @override
  String get releasePage => 'Release page';

  @override
  String get unableOpenReleasePage => 'Could not open the release page';

  @override
  String get downloadDevelopment => 'Download beta';

  @override
  String get downloadStable => 'Download stable';

  @override
  String get releaseNotesUnchanged =>
      'This build has no new code changes. See the release page for full notes.';

  @override
  String get releaseNotesUnavailable =>
      'Release notes are temporarily unavailable. See the release page.';

  @override
  String releaseMoreChanges(int count, String url) {
    return 'Plus $count more changes. [View full changes]($url).';
  }

  @override
  String releaseVersion(String channel, String version) {
    return '$channel $version';
  }
}
