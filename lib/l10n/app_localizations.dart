import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'BITree'**
  String get appName;

  /// No description provided for @appChineseName.
  ///
  /// In en, this message translates to:
  /// **'理枝'**
  String get appChineseName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'A handy toolkit for Beijing Institute of Technology.'**
  String get appTagline;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navAgenda.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get navAgenda;

  /// No description provided for @navTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get navTools;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get followSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @course.
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get course;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @agenda.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get agenda;

  /// No description provided for @exam.
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get exam;

  /// No description provided for @deadline.
  ///
  /// In en, this message translates to:
  /// **'DDL'**
  String get deadline;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get activity;

  /// No description provided for @courseCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 course} other{{count} courses}}'**
  String courseCount(int count);

  /// No description provided for @sessionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String sessionCount(int count);

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemCount(int count);

  /// No description provided for @creditCount.
  ///
  /// In en, this message translates to:
  /// **'{count} credits'**
  String creditCount(String count);

  /// No description provided for @minuteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String minuteCount(int count);

  /// No description provided for @weekNumber.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String weekNumber(int week);

  /// No description provided for @weekNumberCompact.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String weekNumberCompact(int week);

  /// No description provided for @thisWeekSuffix.
  ///
  /// In en, this message translates to:
  /// **', this week'**
  String get thisWeekSuffix;

  /// No description provided for @schoolWeek.
  ///
  /// In en, this message translates to:
  /// **'School schedule'**
  String get schoolWeek;

  /// No description provided for @chooseWeek.
  ///
  /// In en, this message translates to:
  /// **'Choose week'**
  String get chooseWeek;

  /// No description provided for @weekRange.
  ///
  /// In en, this message translates to:
  /// **'Weeks {first}–{last}'**
  String weekRange(int first, int last);

  /// No description provided for @weekRangeShort.
  ///
  /// In en, this message translates to:
  /// **'{first} - {last} weeks'**
  String weekRangeShort(int first, int last);

  /// No description provided for @weekList.
  ///
  /// In en, this message translates to:
  /// **'Weeks {ranges}'**
  String weekList(String ranges);

  /// No description provided for @weeksPending.
  ///
  /// In en, this message translates to:
  /// **'Weeks TBD'**
  String get weeksPending;

  /// No description provided for @listSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get listSeparator;

  /// No description provided for @weekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayMonday;

  /// No description provided for @weekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayTuesday;

  /// No description provided for @weekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayWednesday;

  /// No description provided for @weekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayThursday;

  /// No description provided for @weekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFriday;

  /// No description provided for @weekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdaySaturday;

  /// No description provided for @weekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdaySunday;

  /// No description provided for @weekdayShortMonday.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayShortMonday;

  /// No description provided for @weekdayShortTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayShortTuesday;

  /// No description provided for @weekdayShortWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayShortWednesday;

  /// No description provided for @weekdayShortThursday.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayShortThursday;

  /// No description provided for @weekdayShortFriday.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayShortFriday;

  /// No description provided for @weekdayShortSaturday.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdayShortSaturday;

  /// No description provided for @weekdayShortSunday.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdayShortSunday;

  /// No description provided for @weekdayNarrowMonday.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get weekdayNarrowMonday;

  /// No description provided for @weekdayNarrowTuesday.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayNarrowTuesday;

  /// No description provided for @weekdayNarrowWednesday.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get weekdayNarrowWednesday;

  /// No description provided for @weekdayNarrowThursday.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayNarrowThursday;

  /// No description provided for @weekdayNarrowFriday.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get weekdayNarrowFriday;

  /// No description provided for @weekdayNarrowSaturday.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdayNarrowSaturday;

  /// No description provided for @weekdayNarrowSunday.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdayNarrowSunday;

  /// No description provided for @monthNames.
  ///
  /// In en, this message translates to:
  /// **'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec'**
  String get monthNames;

  /// No description provided for @monthDay.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}'**
  String monthDay(String month, int day);

  /// No description provided for @yearMonthDay.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}'**
  String yearMonthDay(String month, int day, int year);

  /// No description provided for @dateWithWeekday.
  ///
  /// In en, this message translates to:
  /// **'{weekday}, {date}'**
  String dateWithWeekday(String weekday, String date);

  /// No description provided for @relativeDateWithWeekday.
  ///
  /// In en, this message translates to:
  /// **'{relative}, {weekday}, {date}'**
  String relativeDateWithWeekday(String relative, String weekday, String date);

  /// No description provided for @termFall.
  ///
  /// In en, this message translates to:
  /// **'Fall {years}'**
  String termFall(String years);

  /// No description provided for @termSpring.
  ///
  /// In en, this message translates to:
  /// **'Spring {years}'**
  String termSpring(String years);

  /// No description provided for @sectionPending.
  ///
  /// In en, this message translates to:
  /// **'Section TBD'**
  String get sectionPending;

  /// No description provided for @sectionSingle.
  ///
  /// In en, this message translates to:
  /// **'Section {section}'**
  String sectionSingle(int section);

  /// No description provided for @sectionRange.
  ///
  /// In en, this message translates to:
  /// **'Sections {start}–{end}'**
  String sectionRange(int start, int end);

  /// No description provided for @sectionRangeCompact.
  ///
  /// In en, this message translates to:
  /// **'Periods {start}–{end}'**
  String sectionRangeCompact(int start, int end);

  /// No description provided for @timePending.
  ///
  /// In en, this message translates to:
  /// **'Time TBD'**
  String get timePending;

  /// No description provided for @locationPending.
  ///
  /// In en, this message translates to:
  /// **'Room TBD'**
  String get locationPending;

  /// No description provided for @allDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get allDay;

  /// No description provided for @allDayUntil.
  ///
  /// In en, this message translates to:
  /// **'All-day deadline'**
  String get allDayUntil;

  /// No description provided for @dueAt.
  ///
  /// In en, this message translates to:
  /// **'Due {time}'**
  String dueAt(String time);

  /// No description provided for @endsAt.
  ///
  /// In en, this message translates to:
  /// **'Ends {time}'**
  String endsAt(String time);

  /// No description provided for @startedAt.
  ///
  /// In en, this message translates to:
  /// **'Started {time}'**
  String startedAt(String time);

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @ended.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get ended;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgress;

  /// No description provided for @due.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get due;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @settingsDeleteScheduleQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete the local schedule?'**
  String get settingsDeleteScheduleQuestion;

  /// No description provided for @settingsDeleteScheduleBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes schedules for every term, including manually added courses. This cannot be undone.'**
  String get settingsDeleteScheduleBody;

  /// No description provided for @settingsDeleteSchedule.
  ///
  /// In en, this message translates to:
  /// **'Delete schedule'**
  String get settingsDeleteSchedule;

  /// No description provided for @settingsTerm.
  ///
  /// In en, this message translates to:
  /// **'Term'**
  String get settingsTerm;

  /// No description provided for @settingsWeekManagement.
  ///
  /// In en, this message translates to:
  /// **'Week range'**
  String get settingsWeekManagement;

  /// No description provided for @settingsDeleteLocalSchedule.
  ///
  /// In en, this message translates to:
  /// **'Delete local schedule'**
  String get settingsDeleteLocalSchedule;

  /// No description provided for @settingsDeleteDeadlines.
  ///
  /// In en, this message translates to:
  /// **'Delete DDLs'**
  String get settingsDeleteDeadlines;

  /// No description provided for @settingsDeleteDeadlinesBody.
  ///
  /// In en, this message translates to:
  /// **'Choose sources such as manual, physics lab, Lexue, or E-Learning.\n{count} total across all terms, including completed and deleted items'**
  String settingsDeleteDeadlinesBody(int count);

  /// No description provided for @settingsLocalSchedule.
  ///
  /// In en, this message translates to:
  /// **'Local schedule'**
  String get settingsLocalSchedule;

  /// No description provided for @settingsLocalAgenda.
  ///
  /// In en, this message translates to:
  /// **'Local agenda'**
  String get settingsLocalAgenda;

  /// No description provided for @settingsApplication.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get settingsApplication;

  /// No description provided for @settingsExportLogs.
  ///
  /// In en, this message translates to:
  /// **'Export logs'**
  String get settingsExportLogs;

  /// No description provided for @settingsCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsCheckUpdates;

  /// No description provided for @settingsCheckingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get settingsCheckingUpdates;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About BITree'**
  String get settingsAbout;

  /// No description provided for @settingsBuiltAt.
  ///
  /// In en, this message translates to:
  /// **'Built {date} at {time}'**
  String settingsBuiltAt(String date, String time);

  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get settingsLicenses;

  /// No description provided for @aboutOpenBitoolkitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open BIToolkit'**
  String get aboutOpenBitoolkitFailed;

  /// No description provided for @aboutOpenGitHubFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open GitHub'**
  String get aboutOpenGitHubFailed;

  /// No description provided for @aboutLicenseName.
  ///
  /// In en, this message translates to:
  /// **'BITree 理枝'**
  String get aboutLicenseName;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @backToThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Back to this week'**
  String get backToThisWeek;

  /// No description provided for @timedCourses.
  ///
  /// In en, this message translates to:
  /// **'Courses without a fixed time'**
  String get timedCourses;

  /// No description provided for @addCourse.
  ///
  /// In en, this message translates to:
  /// **'Add course'**
  String get addCourse;

  /// No description provided for @chooseCourse.
  ///
  /// In en, this message translates to:
  /// **'Choose a course'**
  String get chooseCourse;

  /// No description provided for @coursesOverlap.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 course has a time conflict, {summary}. Choose a course} other{{count} courses have time conflicts, {summary}. Choose a course}}'**
  String coursesOverlap(int count, String summary);

  /// No description provided for @courseOverlapCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 course} other{{count} courses}}'**
  String courseOverlapCount(int count);

  /// No description provided for @courseOngoingUntil.
  ///
  /// In en, this message translates to:
  /// **'In class · ends {time}'**
  String courseOngoingUntil(String time);

  /// No description provided for @minutesUntilEnd.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute left} other{{count} minutes left}}'**
  String minutesUntilEnd(int count);

  /// No description provided for @courseNext.
  ///
  /// In en, this message translates to:
  /// **'Next class'**
  String get courseNext;

  /// No description provided for @sameBuilding.
  ///
  /// In en, this message translates to:
  /// **'Same building'**
  String get sameBuilding;

  /// No description provided for @sameArea.
  ///
  /// In en, this message translates to:
  /// **'Move within the same area'**
  String get sameArea;

  /// No description provided for @differentArea.
  ///
  /// In en, this message translates to:
  /// **'Move across campus areas'**
  String get differentArea;

  /// No description provided for @copyCourseNameSuccess.
  ///
  /// In en, this message translates to:
  /// **'Course name copied'**
  String get copyCourseNameSuccess;

  /// No description provided for @copyCourseNameFailure.
  ///
  /// In en, this message translates to:
  /// **'Copy failed. Try again.'**
  String get copyCourseNameFailure;

  /// No description provided for @deleteCourseQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this course?'**
  String get deleteCourseQuestion;

  /// No description provided for @deleteCourseBody.
  ///
  /// In en, this message translates to:
  /// **'Remove “{course}” from the local schedule?'**
  String deleteCourseBody(String course);

  /// No description provided for @deleteCourse.
  ///
  /// In en, this message translates to:
  /// **'Delete course'**
  String get deleteCourse;

  /// No description provided for @courseDetailsSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, {time}, {room}{progress}, view details'**
  String courseDetailsSemantics(
    String name,
    String time,
    String room,
    String progress,
  );

  /// No description provided for @courseIsToday.
  ///
  /// In en, this message translates to:
  /// **', today'**
  String get courseIsToday;

  /// No description provided for @courseIsOngoing.
  ///
  /// In en, this message translates to:
  /// **', in progress'**
  String get courseIsOngoing;

  /// No description provided for @courseEditorAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add course'**
  String get courseEditorAddTitle;

  /// No description provided for @courseEditorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit course'**
  String get courseEditorEditTitle;

  /// No description provided for @courseEditorSave.
  ///
  /// In en, this message translates to:
  /// **'Save course'**
  String get courseEditorSave;

  /// No description provided for @courseEditorTerm.
  ///
  /// In en, this message translates to:
  /// **'Term'**
  String get courseEditorTerm;

  /// No description provided for @courseEditorTermRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a term'**
  String get courseEditorTermRequired;

  /// No description provided for @courseEditorMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday of week 1'**
  String get courseEditorMonday;

  /// No description provided for @courseEditorMondayHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose Monday of week 1'**
  String get courseEditorMondayHelp;

  /// No description provided for @courseEditorMondayLabel.
  ///
  /// In en, this message translates to:
  /// **'Monday of week 1: {date}'**
  String courseEditorMondayLabel(String date);

  /// No description provided for @courseEditorName.
  ///
  /// In en, this message translates to:
  /// **'Course name'**
  String get courseEditorName;

  /// No description provided for @courseEditorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a course name'**
  String get courseEditorNameRequired;

  /// No description provided for @courseEditorRoom.
  ///
  /// In en, this message translates to:
  /// **'Room (optional)'**
  String get courseEditorRoom;

  /// No description provided for @courseEditorTeacher.
  ///
  /// In en, this message translates to:
  /// **'Instructor (optional)'**
  String get courseEditorTeacher;

  /// No description provided for @courseEditorWeekday.
  ///
  /// In en, this message translates to:
  /// **'Weekday'**
  String get courseEditorWeekday;

  /// No description provided for @courseEditorWeeksRequired.
  ///
  /// In en, this message translates to:
  /// **'Select at least one week'**
  String get courseEditorWeeksRequired;

  /// No description provided for @courseEditorWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get courseEditorWeeks;

  /// No description provided for @courseEditorPeriodStart.
  ///
  /// In en, this message translates to:
  /// **'Starting section'**
  String get courseEditorPeriodStart;

  /// No description provided for @courseEditorPeriodEnd.
  ///
  /// In en, this message translates to:
  /// **'Ending section'**
  String get courseEditorPeriodEnd;

  /// No description provided for @coursePeriodRange.
  ///
  /// In en, this message translates to:
  /// **'Section {section}{linebreak}({start}–{end})'**
  String coursePeriodRange(
    int section,
    String linebreak,
    String start,
    String end,
  );

  /// No description provided for @weekSelectionAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get weekSelectionAll;

  /// No description provided for @weekSelectionNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get weekSelectionNone;

  /// No description provided for @weekSelectionSummer.
  ///
  /// In en, this message translates to:
  /// **'Summer term'**
  String get weekSelectionSummer;

  /// No description provided for @weekSelectionRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular term'**
  String get weekSelectionRegular;

  /// No description provided for @weekManagement.
  ///
  /// In en, this message translates to:
  /// **'Week range'**
  String get weekManagement;

  /// No description provided for @weekIntegerRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole-number week'**
  String get weekIntegerRequired;

  /// No description provided for @weekZeroInvalid.
  ///
  /// In en, this message translates to:
  /// **'Week 0 does not exist'**
  String get weekZeroInvalid;

  /// No description provided for @decreaseWeek.
  ///
  /// In en, this message translates to:
  /// **'Remove one week'**
  String get decreaseWeek;

  /// No description provided for @increaseWeek.
  ///
  /// In en, this message translates to:
  /// **'Add one week'**
  String get increaseWeek;

  /// No description provided for @weekOrderInvalid.
  ///
  /// In en, this message translates to:
  /// **'The end week cannot be before the start week'**
  String get weekOrderInvalid;

  /// No description provided for @weekStart.
  ///
  /// In en, this message translates to:
  /// **'Start week'**
  String get weekStart;

  /// No description provided for @weekEnd.
  ///
  /// In en, this message translates to:
  /// **'End week'**
  String get weekEnd;

  /// No description provided for @weekRangeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Week range'**
  String get weekRangeDialogTitle;

  /// No description provided for @monthHeader.
  ///
  /// In en, this message translates to:
  /// **'{month}'**
  String monthHeader(String month);

  /// No description provided for @timetableDaySemantics.
  ///
  /// In en, this message translates to:
  /// **'{weekday}, {date}{today}{agenda}'**
  String timetableDaySemantics(
    String date,
    String weekday,
    String today,
    String agenda,
  );

  /// No description provided for @timetableTodaySuffix.
  ///
  /// In en, this message translates to:
  /// **', today'**
  String get timetableTodaySuffix;

  /// No description provided for @timetableAgendaSuffix.
  ///
  /// In en, this message translates to:
  /// **', {count} agenda items'**
  String timetableAgendaSuffix(int count);

  /// No description provided for @sectionSemantics.
  ///
  /// In en, this message translates to:
  /// **'Section {section}, {start}–{end}'**
  String sectionSemantics(int section, String start, String end);

  /// No description provided for @exportSchedule.
  ///
  /// In en, this message translates to:
  /// **'Export schedule'**
  String get exportSchedule;

  /// No description provided for @exportScheduleEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no courses to export. Add a course or set its class time first.'**
  String get exportScheduleEmpty;

  /// No description provided for @exportScheduleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Schedule exported'**
  String get exportScheduleSuccess;

  /// No description provided for @exportScheduleSkipped.
  ///
  /// In en, this message translates to:
  /// **'Schedule exported; skipped {count} courses without a fixed time'**
  String exportScheduleSkipped(int count);

  /// No description provided for @desktopAgendaWidget.
  ///
  /// In en, this message translates to:
  /// **'Desktop agenda'**
  String get desktopAgendaWidget;

  /// No description provided for @exportIcs.
  ///
  /// In en, this message translates to:
  /// **'Export ICS'**
  String get exportIcs;

  /// No description provided for @icsCalendarName.
  ///
  /// In en, this message translates to:
  /// **'BITree {term}'**
  String icsCalendarName(String term);

  /// No description provided for @icsEventDescription.
  ///
  /// In en, this message translates to:
  /// **'{week}, {section}'**
  String icsEventDescription(String week, String section);

  /// No description provided for @icsTeacher.
  ///
  /// In en, this message translates to:
  /// **'Instructor: {teacher}'**
  String icsTeacher(String teacher);

  /// No description provided for @icsCourseNumber.
  ///
  /// In en, this message translates to:
  /// **'Course number: {number}'**
  String icsCourseNumber(String number);

  /// No description provided for @agendaTitle.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get agendaTitle;

  /// No description provided for @agendaReload.
  ///
  /// In en, this message translates to:
  /// **'Reload agenda'**
  String get agendaReload;

  /// No description provided for @agendaPendingTab.
  ///
  /// In en, this message translates to:
  /// **'To do {count}'**
  String agendaPendingTab(int count);

  /// No description provided for @agendaCompletedTab.
  ///
  /// In en, this message translates to:
  /// **'Completed {count}'**
  String agendaCompletedTab(int count);

  /// No description provided for @agendaSwitchToList.
  ///
  /// In en, this message translates to:
  /// **'Switch to list'**
  String get agendaSwitchToList;

  /// No description provided for @agendaSwitchToTimeline.
  ///
  /// In en, this message translates to:
  /// **'Switch to timeline'**
  String get agendaSwitchToTimeline;

  /// No description provided for @agendaOverdueHiddenLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 overdue agenda item} other{{count} overdue agenda items}}'**
  String agendaOverdueHiddenLabel(int count);

  /// No description provided for @agendaNoCompleted.
  ///
  /// In en, this message translates to:
  /// **'No completed agenda items yet'**
  String get agendaNoCompleted;

  /// No description provided for @agendaNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming agenda items'**
  String get agendaNoUpcoming;

  /// No description provided for @agendaNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending agenda items'**
  String get agendaNoPending;

  /// No description provided for @agendaType.
  ///
  /// In en, this message translates to:
  /// **'Agenda type'**
  String get agendaType;

  /// No description provided for @agendaCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 agenda item} other{{count} agenda items}}'**
  String agendaCount(int count);

  /// No description provided for @agendaNoPendingShort.
  ///
  /// In en, this message translates to:
  /// **'No pending agenda items'**
  String get agendaNoPendingShort;

  /// No description provided for @agendaCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'Completed {count}'**
  String agendaCompletedCount(int count);

  /// No description provided for @agendaDayEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled for this day'**
  String get agendaDayEmpty;

  /// No description provided for @agendaChooseItems.
  ///
  /// In en, this message translates to:
  /// **'Choose an item'**
  String get agendaChooseItems;

  /// No description provided for @agendaItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String agendaItemCount(int count);

  /// No description provided for @agendaDetails.
  ///
  /// In en, this message translates to:
  /// **'Agenda details'**
  String get agendaDetails;

  /// No description provided for @agendaOverdueAt.
  ///
  /// In en, this message translates to:
  /// **'Overdue at {time}'**
  String agendaOverdueAt(String time);

  /// No description provided for @agendaStartsAt.
  ///
  /// In en, this message translates to:
  /// **'Starts at {time}'**
  String agendaStartsAt(String time);

  /// No description provided for @agendaMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark complete'**
  String get agendaMarkDone;

  /// No description provided for @agendaMarkUndone.
  ///
  /// In en, this message translates to:
  /// **'Mark incomplete'**
  String get agendaMarkUndone;

  /// No description provided for @agendaNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get agendaNotes;

  /// No description provided for @agendaOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open assignment'**
  String get agendaOpenLink;

  /// No description provided for @agendaDueBeforeEndOfDay.
  ///
  /// In en, this message translates to:
  /// **'Before the end of that day'**
  String get agendaDueBeforeEndOfDay;

  /// No description provided for @agendaDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get agendaDeleteAction;

  /// No description provided for @agendaSwipeDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get agendaSwipeDelete;

  /// No description provided for @agendaSwipeDeleteRelease.
  ///
  /// In en, this message translates to:
  /// **'Release to delete'**
  String get agendaSwipeDeleteRelease;

  /// No description provided for @agendaSwipeRestore.
  ///
  /// In en, this message translates to:
  /// **'Mark incomplete'**
  String get agendaSwipeRestore;

  /// No description provided for @agendaSwipeRestoreRelease.
  ///
  /// In en, this message translates to:
  /// **'Release to restore'**
  String get agendaSwipeRestoreRelease;

  /// No description provided for @agendaSwipeDone.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get agendaSwipeDone;

  /// No description provided for @agendaSwipeDoneRelease.
  ///
  /// In en, this message translates to:
  /// **'Release to complete'**
  String get agendaSwipeDoneRelease;

  /// No description provided for @agendaDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete {kind}?'**
  String agendaDeleteQuestion(String kind);

  /// No description provided for @agendaRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored “{title}”'**
  String agendaRestored(String title);

  /// No description provided for @agendaDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted “{title}”'**
  String agendaDeleted(String title);

  /// No description provided for @agendaAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add {kind}'**
  String agendaAddTitle(String kind);

  /// No description provided for @addAgenda.
  ///
  /// In en, this message translates to:
  /// **'Add event'**
  String get addAgenda;

  /// No description provided for @addDeadline.
  ///
  /// In en, this message translates to:
  /// **'Add DDL'**
  String get addDeadline;

  /// No description provided for @agendaEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {kind}'**
  String agendaEditTitle(String kind);

  /// No description provided for @agendaName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get agendaName;

  /// No description provided for @agendaNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get agendaNameRequired;

  /// No description provided for @agendaAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get agendaAllDay;

  /// No description provided for @agendaLocationOptional.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get agendaLocationOptional;

  /// No description provided for @agendaNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get agendaNotesOptional;

  /// No description provided for @agendaEndAfterStart.
  ///
  /// In en, this message translates to:
  /// **'The end must be later than the start'**
  String get agendaEndAfterStart;

  /// No description provided for @agendaReminderOverdue.
  ///
  /// In en, this message translates to:
  /// **'{time} · overdue'**
  String agendaReminderOverdue(String time);

  /// No description provided for @agendaReminderStarts.
  ///
  /// In en, this message translates to:
  /// **'{time} · starts'**
  String agendaReminderStarts(String time);

  /// No description provided for @agendaReminderCount.
  ///
  /// In en, this message translates to:
  /// **'{count} to do'**
  String agendaReminderCount(int count);

  /// No description provided for @agendaReminderCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse reminders'**
  String get agendaReminderCollapse;

  /// No description provided for @agendaTimelineOneDay.
  ///
  /// In en, this message translates to:
  /// **'1 day / cell'**
  String get agendaTimelineOneDay;

  /// No description provided for @agendaTimelineOneHour.
  ///
  /// In en, this message translates to:
  /// **'1 hour / cell'**
  String get agendaTimelineOneHour;

  /// No description provided for @agendaTimelineHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours / cell'**
  String agendaTimelineHours(String hours);

  /// No description provided for @agendaTimelineZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom: from one day per cell to one hour per cell'**
  String get agendaTimelineZoom;

  /// No description provided for @agendaTimelineEmpty.
  ///
  /// In en, this message translates to:
  /// **'No agenda items\nDrag the timeline or add a new item'**
  String get agendaTimelineEmpty;

  /// No description provided for @agendaTimelineSemantics.
  ///
  /// In en, this message translates to:
  /// **'Agenda timeline'**
  String get agendaTimelineSemantics;

  /// No description provided for @agendaTimelineAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get agendaTimelineAllDay;

  /// No description provided for @agendaTimelineStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts: {time}'**
  String agendaTimelineStarts(String time);

  /// No description provided for @agendaTimelineEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends: {time}'**
  String agendaTimelineEnds(String time);

  /// No description provided for @agendaTimelineDue.
  ///
  /// In en, this message translates to:
  /// **'Due: {time}'**
  String agendaTimelineDue(String time);

  /// No description provided for @agendaTimelineCourse.
  ///
  /// In en, this message translates to:
  /// **'Course: {course}'**
  String agendaTimelineCourse(String course);

  /// No description provided for @agendaTimelineLocation.
  ///
  /// In en, this message translates to:
  /// **'Location: {location}'**
  String agendaTimelineLocation(String location);

  /// No description provided for @agendaTimelineSemanticsEntry.
  ///
  /// In en, this message translates to:
  /// **'{kind}, {title}, {time}{course}{location}{status}'**
  String agendaTimelineSemanticsEntry(
    String kind,
    String title,
    String time,
    String course,
    String location,
    String status,
  );

  /// No description provided for @agendaTimelineStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Status: completed'**
  String get agendaTimelineStatusCompleted;

  /// No description provided for @agendaTimelineStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Status: overdue'**
  String get agendaTimelineStatusOverdue;

  /// No description provided for @agendaTimelineStatusEnded.
  ///
  /// In en, this message translates to:
  /// **'Status: ended'**
  String get agendaTimelineStatusEnded;

  /// No description provided for @clearDeadlinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete DDLs'**
  String get clearDeadlinesTitle;

  /// No description provided for @clearDeadlinesIntro.
  ///
  /// In en, this message translates to:
  /// **'Select one or more sources. Counts include every term and completed or deleted DDLs.'**
  String get clearDeadlinesIntro;

  /// No description provided for @clearDeadlinesSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get clearDeadlinesSelectAll;

  /// No description provided for @clearDeadlinesSourceCount.
  ///
  /// In en, this message translates to:
  /// **'{source} ({count})'**
  String clearDeadlinesSourceCount(String source, int count);

  /// No description provided for @clearDeadlinesSelection.
  ///
  /// In en, this message translates to:
  /// **'{categories} selected, {count} DDLs total.'**
  String clearDeadlinesSelection(int categories, int count);

  /// No description provided for @clearDeadlinesWarning.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone and deleted DDLs cannot be restored. Unselected sources, exams, and other agenda items are unaffected.'**
  String get clearDeadlinesWarning;

  /// No description provided for @clearDeadlinesRecovery.
  ///
  /// In en, this message translates to:
  /// **'Platform DDLs can be synchronized again; physics lab DDLs can be regenerated from the schedule; manually created DDLs cannot be restored.'**
  String get clearDeadlinesRecovery;

  /// No description provided for @clearDeadlinesDeleteCount.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} DDLs'**
  String clearDeadlinesDeleteCount(int count);

  /// No description provided for @clearDeadlinesDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting…'**
  String get clearDeadlinesDeleting;

  /// No description provided for @clearDeadlinesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The agenda is not loaded or is being saved. Try again shortly.'**
  String get clearDeadlinesUnavailable;

  /// No description provided for @clearDeadlinesDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} DDLs.'**
  String clearDeadlinesDeleted(int count);

  /// No description provided for @deletedDeadlinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted DDLs'**
  String get deletedDeadlinesTitle;

  /// No description provided for @deletedDeadlinesNone.
  ///
  /// In en, this message translates to:
  /// **'No deleted DDLs'**
  String get deletedDeadlinesNone;

  /// No description provided for @deletedDeadlinesRestoreAll.
  ///
  /// In en, this message translates to:
  /// **'Restore all'**
  String get deletedDeadlinesRestoreAll;

  /// No description provided for @deletedDeadlinesRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get deletedDeadlinesRestoreAction;

  /// No description provided for @deletedDeadlinesRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored “{title}”'**
  String deletedDeadlinesRestored(String title);

  /// No description provided for @deletedDeadlinesRestoredAll.
  ///
  /// In en, this message translates to:
  /// **'Restored all DDLs'**
  String get deletedDeadlinesRestoredAll;

  /// No description provided for @deadlineManual.
  ///
  /// In en, this message translates to:
  /// **'Manually created'**
  String get deadlineManual;

  /// No description provided for @deadlineManualScope.
  ///
  /// In en, this message translates to:
  /// **'Manually created DDLs'**
  String get deadlineManualScope;

  /// No description provided for @deadlineManualScopeDescription.
  ///
  /// In en, this message translates to:
  /// **'Manually added DDLs, excluding physics lab and synchronized platform items'**
  String get deadlineManualScopeDescription;

  /// No description provided for @deadlinePhysicsLab.
  ///
  /// In en, this message translates to:
  /// **'Physics lab DDLs'**
  String get deadlinePhysicsLab;

  /// No description provided for @deadlinePhysicsLabScopeDescription.
  ///
  /// In en, this message translates to:
  /// **'Physics lab DDLs generated from the schedule, including locally edited items'**
  String get deadlinePhysicsLabScopeDescription;

  /// No description provided for @deadlineLexue.
  ///
  /// In en, this message translates to:
  /// **'Lexue DDLs'**
  String get deadlineLexue;

  /// No description provided for @deadlineLexueScopeDescription.
  ///
  /// In en, this message translates to:
  /// **'DDLs synchronized from Lexue, including locally edited items'**
  String get deadlineLexueScopeDescription;

  /// No description provided for @deadlineEclass.
  ///
  /// In en, this message translates to:
  /// **'E-Learning DDLs'**
  String get deadlineEclass;

  /// No description provided for @deadlineEclassScopeDescription.
  ///
  /// In en, this message translates to:
  /// **'DDLs synchronized from E-Learning, including locally edited items'**
  String get deadlineEclassScopeDescription;

  /// No description provided for @deadlineMooc.
  ///
  /// In en, this message translates to:
  /// **'MOOC DDLs'**
  String get deadlineMooc;

  /// No description provided for @deadlineMoocScopeDescription.
  ///
  /// In en, this message translates to:
  /// **'DDLs synchronized from China University MOOC, including locally edited items'**
  String get deadlineMoocScopeDescription;

  /// No description provided for @deadlineSourceLexue.
  ///
  /// In en, this message translates to:
  /// **'Lexue'**
  String get deadlineSourceLexue;

  /// No description provided for @deadlineSourceEclass.
  ///
  /// In en, this message translates to:
  /// **'E-Learning'**
  String get deadlineSourceEclass;

  /// No description provided for @deadlineSourceMooc.
  ///
  /// In en, this message translates to:
  /// **'China University MOOC'**
  String get deadlineSourceMooc;

  /// No description provided for @deadlineSourcePlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform DDL'**
  String get deadlineSourcePlatform;

  /// No description provided for @agendaKindEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get agendaKindEvent;

  /// No description provided for @agendaKindDeadline.
  ///
  /// In en, this message translates to:
  /// **'DDL'**
  String get agendaKindDeadline;

  /// No description provided for @agendaKindExam.
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get agendaKindExam;

  /// No description provided for @timeRange.
  ///
  /// In en, this message translates to:
  /// **'{start}–{end}'**
  String timeRange(String start, String end);

  /// No description provided for @syncAll.
  ///
  /// In en, this message translates to:
  /// **'Sync all'**
  String get syncAll;

  /// No description provided for @customSync.
  ///
  /// In en, this message translates to:
  /// **'Custom sync'**
  String get customSync;

  /// No description provided for @deletedDdlMenu.
  ///
  /// In en, this message translates to:
  /// **'Deleted DDLs'**
  String get deletedDdlMenu;

  /// No description provided for @syncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTooltip;

  /// No description provided for @viewSyncProgress.
  ///
  /// In en, this message translates to:
  /// **'View sync progress'**
  String get viewSyncProgress;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get syncComplete;

  /// No description provided for @syncPartial.
  ///
  /// In en, this message translates to:
  /// **'Some items were not synchronized'**
  String get syncPartial;

  /// No description provided for @selectedItems.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedItems(int count);

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearSelection;

  /// No description provided for @loginAfterSelection.
  ///
  /// In en, this message translates to:
  /// **'Not signed in; sign in after selecting'**
  String get loginAfterSelection;

  /// No description provided for @syncSelected.
  ///
  /// In en, this message translates to:
  /// **'Sync selected'**
  String get syncSelected;

  /// No description provided for @syncProgress.
  ///
  /// In en, this message translates to:
  /// **'Sync progress'**
  String get syncProgress;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @syncProcessed.
  ///
  /// In en, this message translates to:
  /// **'Processed {done} / {total}'**
  String syncProcessed(int done, int total);

  /// No description provided for @syncCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sync cancelled'**
  String get syncCancelled;

  /// No description provided for @continueAfterCollapse.
  ///
  /// In en, this message translates to:
  /// **'Continues after collapsing'**
  String get continueAfterCollapse;

  /// No description provided for @cancelSync.
  ///
  /// In en, this message translates to:
  /// **'Cancel sync'**
  String get cancelSync;

  /// No description provided for @cancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get cancelling;

  /// No description provided for @verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get verifying;

  /// No description provided for @retryIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Retry incomplete items'**
  String get retryIncomplete;

  /// No description provided for @syncTargetSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get syncTargetSchedule;

  /// No description provided for @syncTargetExams.
  ///
  /// In en, this message translates to:
  /// **'Exam schedule'**
  String get syncTargetExams;

  /// No description provided for @syncTargetGrades.
  ///
  /// In en, this message translates to:
  /// **'Grades'**
  String get syncTargetGrades;

  /// No description provided for @syncTargetStudyPlan.
  ///
  /// In en, this message translates to:
  /// **'Credit progress'**
  String get syncTargetStudyPlan;

  /// No description provided for @syncTargetLexue.
  ///
  /// In en, this message translates to:
  /// **'Lexue DDLs'**
  String get syncTargetLexue;

  /// No description provided for @syncTargetEclass.
  ///
  /// In en, this message translates to:
  /// **'E-Learning DDLs'**
  String get syncTargetEclass;

  /// No description provided for @syncTargetMooc.
  ///
  /// In en, this message translates to:
  /// **'MOOC DDLs'**
  String get syncTargetMooc;

  /// No description provided for @syncTargetPhysicsLab.
  ///
  /// In en, this message translates to:
  /// **'Physics lab DDLs'**
  String get syncTargetPhysicsLab;

  /// No description provided for @syncActionSchedule.
  ///
  /// In en, this message translates to:
  /// **'Sync schedule'**
  String get syncActionSchedule;

  /// No description provided for @syncActionExams.
  ///
  /// In en, this message translates to:
  /// **'Sync exam schedule'**
  String get syncActionExams;

  /// No description provided for @syncActionGrades.
  ///
  /// In en, this message translates to:
  /// **'Sync grades'**
  String get syncActionGrades;

  /// No description provided for @syncActionStudyPlan.
  ///
  /// In en, this message translates to:
  /// **'Sync credit progress'**
  String get syncActionStudyPlan;

  /// No description provided for @syncActionLexue.
  ///
  /// In en, this message translates to:
  /// **'Sync Lexue DDLs'**
  String get syncActionLexue;

  /// No description provided for @syncActionEclass.
  ///
  /// In en, this message translates to:
  /// **'Sync E-Learning DDLs'**
  String get syncActionEclass;

  /// No description provided for @syncActionMooc.
  ///
  /// In en, this message translates to:
  /// **'Sync MOOC DDLs'**
  String get syncActionMooc;

  /// No description provided for @syncActionPhysicsLab.
  ///
  /// In en, this message translates to:
  /// **'Update physics lab DDLs'**
  String get syncActionPhysicsLab;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Synchronizing…'**
  String get syncing;

  /// No description provided for @waitingForSchool.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the school request'**
  String get waitingForSchool;

  /// No description provided for @waitingToSync.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get waitingToSync;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @syncNotFinished.
  ///
  /// In en, this message translates to:
  /// **'Sync did not finish. Try again.'**
  String get syncNotFinished;

  /// No description provided for @noScheduleAvailable.
  ///
  /// In en, this message translates to:
  /// **'No schedule available'**
  String get noScheduleAvailable;

  /// No description provided for @physicsLabSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save physics lab DDLs'**
  String get physicsLabSaveFailed;

  /// No description provided for @physicsLabPreviewReport.
  ///
  /// In en, this message translates to:
  /// **'Pre-lab report {course}'**
  String physicsLabPreviewReport(String course);

  /// No description provided for @physicsLabReport.
  ///
  /// In en, this message translates to:
  /// **'Lab report {course}'**
  String physicsLabReport(String course);

  /// No description provided for @physicsLabGeneratedNotes.
  ///
  /// In en, this message translates to:
  /// **'Generated from the {term} schedule\nClass: {date} {time}'**
  String physicsLabGeneratedNotes(String term, String date, String time);

  /// No description provided for @updatedDdlCount.
  ///
  /// In en, this message translates to:
  /// **'Updated {count} DDLs'**
  String updatedDdlCount(int count);

  /// No description provided for @syncResultSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the sync result'**
  String get syncResultSaveFailed;

  /// No description provided for @syncedDdlCount.
  ///
  /// In en, this message translates to:
  /// **'Synced {count} DDLs'**
  String syncedDdlCount(int count);

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed. Try again.'**
  String get syncFailed;

  /// No description provided for @schoolLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your school account'**
  String get schoolLoginRequired;

  /// No description provided for @syncVerificationRequired.
  ///
  /// In en, this message translates to:
  /// **'Complete school sign-in verification'**
  String get syncVerificationRequired;

  /// No description provided for @syncCourseFailure.
  ///
  /// In en, this message translates to:
  /// **'{course}: {message}'**
  String syncCourseFailure(String course, String message);

  /// No description provided for @accountUnverified.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get accountUnverified;

  /// No description provided for @accountSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get accountSignedIn;

  /// No description provided for @accountSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get accountSignedOut;

  /// No description provided for @accountExpired.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get accountExpired;

  /// No description provided for @accountSmsRequired.
  ///
  /// In en, this message translates to:
  /// **'SMS verification required'**
  String get accountSmsRequired;

  /// No description provided for @accountImageRequired.
  ///
  /// In en, this message translates to:
  /// **'Image verification required'**
  String get accountImageRequired;

  /// No description provided for @moocName.
  ///
  /// In en, this message translates to:
  /// **'China University MOOC'**
  String get moocName;

  /// No description provided for @moocSignOutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Sign out of China University MOOC?'**
  String get moocSignOutQuestion;

  /// No description provided for @moocSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'The saved login session on this device will be deleted. Imported DDLs will remain.'**
  String get moocSignOutBody;

  /// No description provided for @exitAction.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitAction;

  /// No description provided for @webLogin.
  ///
  /// In en, this message translates to:
  /// **'Web sign-in'**
  String get webLogin;

  /// No description provided for @relogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get relogin;

  /// No description provided for @moocLoginMethods.
  ///
  /// In en, this message translates to:
  /// **'Phone, email, verification code, or QR code'**
  String get moocLoginMethods;

  /// No description provided for @useCookie.
  ///
  /// In en, this message translates to:
  /// **'Use cookies'**
  String get useCookie;

  /// No description provided for @backupLogin.
  ///
  /// In en, this message translates to:
  /// **'Backup sign-in method'**
  String get backupLogin;

  /// No description provided for @moocSignOutAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get moocSignOutAccount;

  /// No description provided for @moocConnectionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Connection cancelled'**
  String get moocConnectionCancelled;

  /// No description provided for @moocConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get moocConnecting;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @moocCookieInstructions.
  ///
  /// In en, this message translates to:
  /// **'In a signed-in MOOC web page, copy the request Cookie from the Network panel in developer tools. Use this only when web sign-in does not work.'**
  String get moocCookieInstructions;

  /// No description provided for @moocPasteCookie.
  ///
  /// In en, this message translates to:
  /// **'Paste a Cookie'**
  String get moocPasteCookie;

  /// No description provided for @openMoocFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open MOOC'**
  String get openMoocFailed;

  /// No description provided for @openOfficialLogin.
  ///
  /// In en, this message translates to:
  /// **'Open official sign-in page'**
  String get openOfficialLogin;

  /// No description provided for @moocLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to China University MOOC'**
  String get moocLoginTitle;

  /// No description provided for @refreshLoginPage.
  ///
  /// In en, this message translates to:
  /// **'Refresh sign-in page'**
  String get refreshLoginPage;

  /// No description provided for @completeLogin.
  ///
  /// In en, this message translates to:
  /// **'Finish sign-in'**
  String get completeLogin;

  /// No description provided for @moocLoginPageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The sign-in page could not load. Check your connection and refresh.'**
  String get moocLoginPageLoadFailed;

  /// No description provided for @moocLoginPageOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the sign-in page. Try again.'**
  String get moocLoginPageOpenFailed;

  /// No description provided for @moocOpenAppFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the app. Choose another sign-in method on the page.'**
  String get moocOpenAppFailed;

  /// No description provided for @moocCompleteLoginFirst.
  ///
  /// In en, this message translates to:
  /// **'Complete sign-in on the page first.'**
  String get moocCompleteLoginFirst;

  /// No description provided for @moocAccountReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the MOOC account. Refresh the sign-in page.'**
  String get moocAccountReadFailed;

  /// No description provided for @moocSessionNotReady.
  ///
  /// In en, this message translates to:
  /// **'The login session is not ready yet. Try again shortly.'**
  String get moocSessionNotReady;

  /// No description provided for @moocSavingLogin.
  ///
  /// In en, this message translates to:
  /// **'Saving sign-in…'**
  String get moocSavingLogin;

  /// No description provided for @moocLoginStateReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the sign-in state. Refresh or tap “Finish sign-in” to retry.'**
  String get moocLoginStateReadFailed;

  /// No description provided for @moocConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get moocConnected;

  /// No description provided for @moocNeedsLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get moocNeedsLogin;

  /// No description provided for @moocSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get moocSignedOut;

  /// No description provided for @moocLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your China University MOOC account'**
  String get moocLoginRequired;

  /// No description provided for @moocUserFallback.
  ///
  /// In en, this message translates to:
  /// **'MOOC user'**
  String get moocUserFallback;

  /// No description provided for @moocReadingCourses.
  ///
  /// In en, this message translates to:
  /// **'Reading MOOC courses…'**
  String get moocReadingCourses;

  /// No description provided for @moocReadingSpocCourses.
  ///
  /// In en, this message translates to:
  /// **'Reading SPOC courses…'**
  String get moocReadingSpocCourses;

  /// No description provided for @moocReadingCourse.
  ///
  /// In en, this message translates to:
  /// **'Reading {done}/{total}: {course}'**
  String moocReadingCourse(int done, int total, String course);

  /// No description provided for @moocNoSession.
  ///
  /// In en, this message translates to:
  /// **'No China University MOOC session was found. Sign in first.'**
  String get moocNoSession;

  /// No description provided for @moocLoginExpired.
  ///
  /// In en, this message translates to:
  /// **'The China University MOOC session expired. Sign in again.'**
  String get moocLoginExpired;

  /// No description provided for @moocRequestBusy.
  ///
  /// In en, this message translates to:
  /// **'MOOC is already handling a request. Try again shortly.'**
  String get moocRequestBusy;

  /// No description provided for @moocReadAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the saved MOOC sign-in. Sign in again.'**
  String get moocReadAccountFailed;

  /// No description provided for @moocSaveResultFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the sync result. Try again shortly.'**
  String get moocSaveResultFailed;

  /// No description provided for @schoolLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to school account'**
  String get schoolLogin;

  /// No description provided for @schoolStudentId.
  ///
  /// In en, this message translates to:
  /// **'Student ID'**
  String get schoolStudentId;

  /// No description provided for @schoolEnterStudentId.
  ///
  /// In en, this message translates to:
  /// **'Enter your student ID'**
  String get schoolEnterStudentId;

  /// No description provided for @schoolPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get schoolPassword;

  /// No description provided for @schoolEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get schoolEnterPassword;

  /// No description provided for @schoolShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get schoolShowPassword;

  /// No description provided for @schoolHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get schoolHidePassword;

  /// No description provided for @schoolLoggingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get schoolLoggingIn;

  /// No description provided for @schoolSignOutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Sign out of the school account?'**
  String get schoolSignOutQuestion;

  /// No description provided for @schoolSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'The sign-in information on this device will be removed. Local schedules and agenda items will remain.'**
  String get schoolSignOutBody;

  /// No description provided for @schoolSignOutAction.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get schoolSignOutAction;

  /// No description provided for @verifyAction.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyAction;

  /// No description provided for @schoolVerified.
  ///
  /// In en, this message translates to:
  /// **'School account verified'**
  String get schoolVerified;

  /// No description provided for @schoolSmsVerification.
  ///
  /// In en, this message translates to:
  /// **'SMS verification'**
  String get schoolSmsVerification;

  /// No description provided for @schoolImageVerification.
  ///
  /// In en, this message translates to:
  /// **'Image verification'**
  String get schoolImageVerification;

  /// No description provided for @schoolSentToPhone.
  ///
  /// In en, this message translates to:
  /// **'Sent to {phone}'**
  String schoolSentToPhone(String phone);

  /// No description provided for @schoolVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get schoolVerificationCode;

  /// No description provided for @schoolEnterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code'**
  String get schoolEnterVerificationCode;

  /// No description provided for @schoolRefreshImage.
  ///
  /// In en, this message translates to:
  /// **'New image'**
  String get schoolRefreshImage;

  /// No description provided for @schoolResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String schoolResendIn(int seconds);

  /// No description provided for @schoolResend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get schoolResend;

  /// No description provided for @schoolVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get schoolVerifying;

  /// No description provided for @toolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get toolsTitle;

  /// No description provided for @gradesAndAcademics.
  ///
  /// In en, this message translates to:
  /// **'Grades and academics'**
  String get gradesAndAcademics;

  /// No description provided for @gradeSimulation.
  ///
  /// In en, this message translates to:
  /// **'Grade projection'**
  String get gradeSimulation;

  /// No description provided for @creditProgress.
  ///
  /// In en, this message translates to:
  /// **'Degree credit progress'**
  String get creditProgress;

  /// No description provided for @examScheduleTool.
  ///
  /// In en, this message translates to:
  /// **'Exam schedule and conflict check'**
  String get examScheduleTool;

  /// No description provided for @emptyClassroomQuery.
  ///
  /// In en, this message translates to:
  /// **'Find empty classrooms'**
  String get emptyClassroomQuery;

  /// No description provided for @wencuiMap.
  ///
  /// In en, this message translates to:
  /// **'Wencui map'**
  String get wencuiMap;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @logsRecent.
  ///
  /// In en, this message translates to:
  /// **'Last 100 lines, kept locally for seven days'**
  String get logsRecent;

  /// No description provided for @exportingLogs.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get exportingLogs;

  /// No description provided for @exportLogs.
  ///
  /// In en, this message translates to:
  /// **'Export logs'**
  String get exportLogs;

  /// No description provided for @reloadLogs.
  ///
  /// In en, this message translates to:
  /// **'Reload logs'**
  String get reloadLogs;

  /// No description provided for @noLogs.
  ///
  /// In en, this message translates to:
  /// **'No logs'**
  String get noLogs;

  /// No description provided for @logsExported.
  ///
  /// In en, this message translates to:
  /// **'Logs exported'**
  String get logsExported;

  /// No description provided for @widgetGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Desktop agenda'**
  String get widgetGuideTitle;

  /// No description provided for @widgetSingleColumn.
  ///
  /// In en, this message translates to:
  /// **'2×2 single column'**
  String get widgetSingleColumn;

  /// No description provided for @widgetDoubleColumn.
  ///
  /// In en, this message translates to:
  /// **'2×4 double column'**
  String get widgetDoubleColumn;

  /// No description provided for @widgetStepOpen.
  ///
  /// In en, this message translates to:
  /// **'Touch and hold an empty area of the desktop, then open Widgets.'**
  String get widgetStepOpen;

  /// No description provided for @widgetStepFind.
  ///
  /// In en, this message translates to:
  /// **'Find the BITree agenda, choose a single- or double-column layout, and drag it to the desktop.'**
  String get widgetStepFind;

  /// No description provided for @widgetStepScroll.
  ///
  /// In en, this message translates to:
  /// **'Scroll up or down to see courses, exams, DDLs, and events.'**
  String get widgetStepScroll;

  /// No description provided for @widgetGuideTomorrow.
  ///
  /// In en, this message translates to:
  /// **'After today\'s schedule ends, tomorrow\'s agenda is shown from 21:00.'**
  String get widgetGuideTomorrow;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open this link in a browser:\n{url}'**
  String openInBrowser(String url);

  /// No description provided for @takeBack.
  ///
  /// In en, this message translates to:
  /// **'Take back'**
  String get takeBack;

  /// No description provided for @viewHidden.
  ///
  /// In en, this message translates to:
  /// **'View {label}'**
  String viewHidden(String label);

  /// No description provided for @releaseToView.
  ///
  /// In en, this message translates to:
  /// **'Release to view {label}'**
  String releaseToView(String label);

  /// No description provided for @pullToView.
  ///
  /// In en, this message translates to:
  /// **'Pull down to view {label}'**
  String pullToView(String label);

  /// No description provided for @gpaRules.
  ///
  /// In en, this message translates to:
  /// **'GPA rules'**
  String get gpaRules;

  /// No description provided for @gpaRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'GPA calculation rules'**
  String get gpaRulesTitle;

  /// No description provided for @gpaRuleIntro.
  ///
  /// In en, this message translates to:
  /// **'Uses the Beijing Institute of Technology undergraduate GPA calculation method (trial).'**
  String get gpaRuleIntro;

  /// No description provided for @gpaRulePercent.
  ///
  /// In en, this message translates to:
  /// **'Percentage scores: 60 and above use 4 − 3 × (100 − score)² ÷ 1600, rounded to one decimal place; below 60 is 0.'**
  String get gpaRulePercent;

  /// No description provided for @gpaRuleFive.
  ///
  /// In en, this message translates to:
  /// **'Five-level scores: Excellent 4.0, Good 3.6, Average 2.8, Pass 1.7, Fail 0.'**
  String get gpaRuleFive;

  /// No description provided for @gpaRuleWeighting.
  ///
  /// In en, this message translates to:
  /// **'Weighted by credits. Only the highest result for a course is used; failed university elective courses do not count toward GPA. Pass/fail courses contribute credits only, and the weighted average uses percentage scores only.'**
  String get gpaRuleWeighting;

  /// No description provided for @openGpaRulesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the GPA rules'**
  String get openGpaRulesFailed;

  /// No description provided for @schoolSource.
  ///
  /// In en, this message translates to:
  /// **'School source'**
  String get schoolSource;

  /// No description provided for @syncedAt.
  ///
  /// In en, this message translates to:
  /// **'Synchronized {date} {time}'**
  String syncedAt(String date, String time);

  /// No description provided for @failedCourse.
  ///
  /// In en, this message translates to:
  /// **'Not passed'**
  String get failedCourse;

  /// No description provided for @gradesReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Academic data is temporarily unavailable'**
  String get gradesReadFailed;

  /// No description provided for @noSyncedGrades.
  ///
  /// In en, this message translates to:
  /// **'No grades have been synchronized'**
  String get noSyncedGrades;

  /// No description provided for @allSemesters.
  ///
  /// In en, this message translates to:
  /// **'All semesters'**
  String get allSemesters;

  /// No description provided for @averageGpa.
  ///
  /// In en, this message translates to:
  /// **'Average GPA'**
  String get averageGpa;

  /// No description provided for @weightedAverageScore.
  ///
  /// In en, this message translates to:
  /// **'Weighted average'**
  String get weightedAverageScore;

  /// No description provided for @earnedCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits earned'**
  String get earnedCredits;

  /// No description provided for @courseGrades.
  ///
  /// In en, this message translates to:
  /// **'Course grades'**
  String get courseGrades;

  /// No description provided for @termPerformance.
  ///
  /// In en, this message translates to:
  /// **'Term performance'**
  String get termPerformance;

  /// No description provided for @onlyFailedCourses.
  ///
  /// In en, this message translates to:
  /// **'Showing failed courses only'**
  String get onlyFailedCourses;

  /// No description provided for @coursesNotPassed.
  ///
  /// In en, this message translates to:
  /// **'{count} courses not passed'**
  String coursesNotPassed(int count);

  /// No description provided for @termCoursesNotPassed.
  ///
  /// In en, this message translates to:
  /// **'{count} courses were not passed this term'**
  String termCoursesNotPassed(int count);

  /// No description provided for @noGradesThisTerm.
  ///
  /// In en, this message translates to:
  /// **'No grades in this semester'**
  String get noGradesThisTerm;

  /// No description provided for @weightedAverageValue.
  ///
  /// In en, this message translates to:
  /// **'Weighted average {value}'**
  String weightedAverageValue(String value);

  /// No description provided for @creditProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Degree credit progress'**
  String get creditProgressTitle;

  /// No description provided for @reviewCreditTargets.
  ///
  /// In en, this message translates to:
  /// **'Review credit targets'**
  String get reviewCreditTargets;

  /// No description provided for @academicReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Academic data is temporarily unavailable'**
  String get academicReadFailed;

  /// No description provided for @noCreditRecords.
  ///
  /// In en, this message translates to:
  /// **'No credit records yet'**
  String get noCreditRecords;

  /// No description provided for @creditsFromGrades.
  ///
  /// In en, this message translates to:
  /// **'Credits earned from grades'**
  String get creditsFromGrades;

  /// No description provided for @completedCreditsSchool.
  ///
  /// In en, this message translates to:
  /// **'Credits completed in school records'**
  String get completedCreditsSchool;

  /// No description provided for @schoolRequiredCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits required by the school'**
  String get schoolRequiredCredits;

  /// No description provided for @reviewTargetCredits.
  ///
  /// In en, this message translates to:
  /// **'Reviewed target credits'**
  String get reviewTargetCredits;

  /// No description provided for @creditsRemaining.
  ///
  /// In en, this message translates to:
  /// **'Credits remaining'**
  String get creditsRemaining;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @requiredCoursesPending.
  ///
  /// In en, this message translates to:
  /// **'{count} required courses still to pass'**
  String requiredCoursesPending(int count);

  /// No description provided for @pendingRequiredCourses.
  ///
  /// In en, this message translates to:
  /// **'Required courses still to pass'**
  String get pendingRequiredCourses;

  /// No description provided for @reviewByCategory.
  ///
  /// In en, this message translates to:
  /// **'Review by course category'**
  String get reviewByCategory;

  /// No description provided for @setTargets.
  ///
  /// In en, this message translates to:
  /// **'Set targets'**
  String get setTargets;

  /// No description provided for @syncGradesForCredit.
  ///
  /// In en, this message translates to:
  /// **'Sync grades to view category credits'**
  String get syncGradesForCredit;

  /// No description provided for @creditCategoryNote.
  ///
  /// In en, this message translates to:
  /// **'Category credits are based on synchronized grades, counting each course once. Check category requirements against your study plan; in-progress credits are not estimated. Graduation is subject to school review.'**
  String get creditCategoryNote;

  /// No description provided for @noCategoryGrades.
  ///
  /// In en, this message translates to:
  /// **'No course grades in this category'**
  String get noCategoryGrades;

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'{count} credits'**
  String credits(String count);

  /// No description provided for @creditProgressValue.
  ///
  /// In en, this message translates to:
  /// **'{earned} / {target}'**
  String creditProgressValue(String earned, String target);

  /// No description provided for @creditTargetNotSet.
  ///
  /// In en, this message translates to:
  /// **'No category target set'**
  String get creditTargetNotSet;

  /// No description provided for @creditsStillNeeded.
  ///
  /// In en, this message translates to:
  /// **'{count} more credits needed'**
  String creditsStillNeeded(String count);

  /// No description provided for @totalCreditTarget.
  ///
  /// In en, this message translates to:
  /// **'Total credit target'**
  String get totalCreditTarget;

  /// No description provided for @leaveBlankSchoolRequirement.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to use the school requirement'**
  String get leaveBlankSchoolRequirement;

  /// No description provided for @categoryCreditTarget.
  ///
  /// In en, this message translates to:
  /// **'{category} credit target'**
  String categoryCreditTarget(String category);

  /// No description provided for @leaveBlankCancelTarget.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to cancel this category target'**
  String get leaveBlankCancelTarget;

  /// No description provided for @addCourseCategory.
  ///
  /// In en, this message translates to:
  /// **'Add course category'**
  String get addCourseCategory;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @enterNonNegativeCredits.
  ///
  /// In en, this message translates to:
  /// **'Enter a non-negative number of credits'**
  String get enterNonNegativeCredits;

  /// No description provided for @examScheduleAndConflicts.
  ///
  /// In en, this message translates to:
  /// **'Exam schedule and conflict check'**
  String get examScheduleAndConflicts;

  /// No description provided for @checkLocalSchedule.
  ///
  /// In en, this message translates to:
  /// **'Also check the local schedule'**
  String get checkLocalSchedule;

  /// No description provided for @syncScheduleConflictHint.
  ///
  /// In en, this message translates to:
  /// **'Sync a schedule to check exam and class time conflicts.'**
  String get syncScheduleConflictHint;

  /// No description provided for @timeConflictsFound.
  ///
  /// In en, this message translates to:
  /// **'{count} time conflicts found'**
  String timeConflictsFound(int count);

  /// No description provided for @noUpcomingExams.
  ///
  /// In en, this message translates to:
  /// **'No upcoming exams'**
  String get noUpcomingExams;

  /// No description provided for @noExams.
  ///
  /// In en, this message translates to:
  /// **'No exams scheduled'**
  String get noExams;

  /// No description provided for @hideFinishedExams.
  ///
  /// In en, this message translates to:
  /// **'Hide finished exams'**
  String get hideFinishedExams;

  /// No description provided for @showFinishedExams.
  ///
  /// In en, this message translates to:
  /// **'Show finished exams'**
  String get showFinishedExams;

  /// No description provided for @examAgendaSharedNote.
  ///
  /// In en, this message translates to:
  /// **'Exams and agenda items share records. Syncing, editing, and deleting affect both places.'**
  String get examAgendaSharedNote;

  /// No description provided for @overlapsClass.
  ///
  /// In en, this message translates to:
  /// **'Overlaps {title} class time'**
  String overlapsClass(String title);

  /// No description provided for @overlapsExam.
  ///
  /// In en, this message translates to:
  /// **'Overlaps {title} exam time'**
  String overlapsExam(String title);

  /// No description provided for @timeConflict.
  ///
  /// In en, this message translates to:
  /// **'Time conflict'**
  String get timeConflict;

  /// No description provided for @noTimeConflict.
  ///
  /// In en, this message translates to:
  /// **'No time conflicts'**
  String get noTimeConflict;

  /// No description provided for @overlapMinutes.
  ///
  /// In en, this message translates to:
  /// **'{date}  Overlap: {minutes} minutes'**
  String overlapMinutes(String date, int minutes);

  /// No description provided for @courseGradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Course grade'**
  String get courseGradeTitle;

  /// No description provided for @courseNumber.
  ///
  /// In en, this message translates to:
  /// **'Course number'**
  String get courseNumber;

  /// No description provided for @courseCredits.
  ///
  /// In en, this message translates to:
  /// **'Course credits'**
  String get courseCredits;

  /// No description provided for @courseAttribute.
  ///
  /// In en, this message translates to:
  /// **'Course attribute'**
  String get courseAttribute;

  /// No description provided for @courseCategory.
  ///
  /// In en, this message translates to:
  /// **'Course category'**
  String get courseCategory;

  /// No description provided for @examType.
  ///
  /// In en, this message translates to:
  /// **'Exam type'**
  String get examType;

  /// No description provided for @courseGpa.
  ///
  /// In en, this message translates to:
  /// **'Course GPA'**
  String get courseGpa;

  /// No description provided for @notCounted.
  ///
  /// In en, this message translates to:
  /// **'Not counted'**
  String get notCounted;

  /// No description provided for @creditReviewCategory.
  ///
  /// In en, this message translates to:
  /// **'Credit review category'**
  String get creditReviewCategory;

  /// No description provided for @simulateRetake.
  ///
  /// In en, this message translates to:
  /// **'Project retake grade'**
  String get simulateRetake;

  /// No description provided for @removeSimulatedCourseQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove projected course?'**
  String get removeSimulatedCourseQuestion;

  /// No description provided for @removeAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAction;

  /// No description provided for @currentGpaCredits.
  ///
  /// In en, this message translates to:
  /// **'Current GPA credits {credits}, average GPA {gpa}'**
  String currentGpaCredits(String credits, String gpa);

  /// No description provided for @simulateByCourse.
  ///
  /// In en, this message translates to:
  /// **'Project by course'**
  String get simulateByCourse;

  /// No description provided for @targetBackCalculation.
  ///
  /// In en, this message translates to:
  /// **'Target back-calculation'**
  String get targetBackCalculation;

  /// No description provided for @targetCumulativeGpa.
  ///
  /// In en, this message translates to:
  /// **'Target cumulative GPA'**
  String get targetCumulativeGpa;

  /// No description provided for @enterGpaRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a GPA from 0 to 4'**
  String get enterGpaRange;

  /// No description provided for @requiredPerCourse.
  ///
  /// In en, this message translates to:
  /// **'Each projected course must reach'**
  String get requiredPerCourse;

  /// No description provided for @projectedCumulativeGpa.
  ///
  /// In en, this message translates to:
  /// **'Projected cumulative GPA'**
  String get projectedCumulativeGpa;

  /// No description provided for @addSimulatedCourseFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a projected course first'**
  String get addSimulatedCourseFirst;

  /// No description provided for @targetUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Target cannot be reached even with full marks'**
  String get targetUnreachable;

  /// No description provided for @scoreValue.
  ///
  /// In en, this message translates to:
  /// **'{score} points'**
  String scoreValue(String score);

  /// No description provided for @gpaChange.
  ///
  /// In en, this message translates to:
  /// **'Cumulative GPA change {value}'**
  String gpaChange(String value);

  /// No description provided for @simulatedCourses.
  ///
  /// In en, this message translates to:
  /// **'Projected courses'**
  String get simulatedCourses;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// No description provided for @removeSimulatedCourse.
  ///
  /// In en, this message translates to:
  /// **'Remove projected course'**
  String get removeSimulatedCourse;

  /// No description provided for @retakeUsesHighest.
  ///
  /// In en, this message translates to:
  /// **'Use the highest retake grade'**
  String get retakeUsesHighest;

  /// No description provided for @simulationDoesNotChange.
  ///
  /// In en, this message translates to:
  /// **'Projection does not change synchronized grades.'**
  String get simulationDoesNotChange;

  /// No description provided for @simulationIncludesBoth.
  ///
  /// In en, this message translates to:
  /// **'This projection counts both the original and retake grades instead of applying the school\'s highest-grade rule.'**
  String get simulationIncludesBoth;

  /// No description provided for @addProjectedCourse.
  ///
  /// In en, this message translates to:
  /// **'Add projected course'**
  String get addProjectedCourse;

  /// No description provided for @editProjectedCourse.
  ///
  /// In en, this message translates to:
  /// **'Edit projected course'**
  String get editProjectedCourse;

  /// No description provided for @selectCourseOptional.
  ///
  /// In en, this message translates to:
  /// **'Select course (optional)'**
  String get selectCourseOptional;

  /// No description provided for @manualEntry.
  ///
  /// In en, this message translates to:
  /// **'Enter manually'**
  String get manualEntry;

  /// No description provided for @retakeSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (retake)'**
  String retakeSuffix(String name);

  /// No description provided for @courseName.
  ///
  /// In en, this message translates to:
  /// **'Course name'**
  String get courseName;

  /// No description provided for @enterCourseName.
  ///
  /// In en, this message translates to:
  /// **'Enter a course name'**
  String get enterCourseName;

  /// No description provided for @enterPositiveCredits.
  ///
  /// In en, this message translates to:
  /// **'Enter credits greater than 0'**
  String get enterPositiveCredits;

  /// No description provided for @expectedScore.
  ///
  /// In en, this message translates to:
  /// **'Expected score'**
  String get expectedScore;

  /// No description provided for @enterScoreRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a score from 0 to 100'**
  String get enterScoreRange;

  /// No description provided for @loadBuildings.
  ///
  /// In en, this message translates to:
  /// **'Load buildings'**
  String get loadBuildings;

  /// No description provided for @noQueryableCampuses.
  ///
  /// In en, this message translates to:
  /// **'No campuses available to query'**
  String get noQueryableCampuses;

  /// No description provided for @reloadAction.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reloadAction;

  /// No description provided for @campus.
  ///
  /// In en, this message translates to:
  /// **'Campus'**
  String get campus;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @todayDate.
  ///
  /// In en, this message translates to:
  /// **'Today {date}'**
  String todayDate(String date);

  /// No description provided for @tomorrowDate.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow {date}'**
  String tomorrowDate(String date);

  /// No description provided for @otherDate.
  ///
  /// In en, this message translates to:
  /// **'Other date'**
  String get otherDate;

  /// No description provided for @building.
  ///
  /// In en, this message translates to:
  /// **'Building'**
  String get building;

  /// No description provided for @allBuildings.
  ///
  /// In en, this message translates to:
  /// **'All buildings'**
  String get allBuildings;

  /// No description provided for @wencuiBuildingAll.
  ///
  /// In en, this message translates to:
  /// **'Wencui Building (all)'**
  String get wencuiBuildingAll;

  /// No description provided for @classroomFreeTime.
  ///
  /// In en, this message translates to:
  /// **'Classroom availability'**
  String get classroomFreeTime;

  /// No description provided for @roomsMatchingPeriod.
  ///
  /// In en, this message translates to:
  /// **'Rooms matching the selected time'**
  String get roomsMatchingPeriod;

  /// No description provided for @querying.
  ///
  /// In en, this message translates to:
  /// **'Querying…'**
  String get querying;

  /// No description provided for @roomCount.
  ///
  /// In en, this message translates to:
  /// **'{count} rooms'**
  String roomCount(int count);

  /// No description provided for @showsFreePeriods.
  ///
  /// In en, this message translates to:
  /// **'Shows each room\'s free periods for the day'**
  String get showsFreePeriods;

  /// No description provided for @freeThroughoutPeriod.
  ///
  /// In en, this message translates to:
  /// **'Free throughout {period}'**
  String freeThroughoutPeriod(String period);

  /// No description provided for @loginToQuery.
  ///
  /// In en, this message translates to:
  /// **'Sign in to query empty classrooms'**
  String get loginToQuery;

  /// No description provided for @queryIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Query did not finish'**
  String get queryIncomplete;

  /// No description provided for @queryAgain.
  ///
  /// In en, this message translates to:
  /// **'Query again'**
  String get queryAgain;

  /// No description provided for @noBuildingInfo.
  ///
  /// In en, this message translates to:
  /// **'No building information for this campus yet'**
  String get noBuildingInfo;

  /// No description provided for @noFreeClassrooms.
  ///
  /// In en, this message translates to:
  /// **'No empty classrooms during this period'**
  String get noFreeClassrooms;

  /// No description provided for @noFreePeriods.
  ///
  /// In en, this message translates to:
  /// **'No free periods that day'**
  String get noFreePeriods;

  /// No description provided for @reloadBuildings.
  ///
  /// In en, this message translates to:
  /// **'Reload buildings'**
  String get reloadBuildings;

  /// No description provided for @viewAnyPeriod.
  ///
  /// In en, this message translates to:
  /// **'View any period'**
  String get viewAnyPeriod;

  /// No description provided for @viewAllBuildings.
  ///
  /// In en, this message translates to:
  /// **'View all buildings'**
  String get viewAllBuildings;

  /// No description provided for @changeDate.
  ///
  /// In en, this message translates to:
  /// **'Change date'**
  String get changeDate;

  /// No description provided for @freeMeansNoClass.
  ///
  /// In en, this message translates to:
  /// **'Free means no class is scheduled during that period'**
  String get freeMeansNoClass;

  /// No description provided for @busyStatus.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get busyStatus;

  /// No description provided for @freeStatus.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freeStatus;

  /// No description provided for @allPeriods.
  ///
  /// In en, this message translates to:
  /// **'Any period'**
  String get allPeriods;

  /// No description provided for @currentPeriod.
  ///
  /// In en, this message translates to:
  /// **'Current period'**
  String get currentPeriod;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @afternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get afternoon;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get evening;

  /// No description provided for @customPeriods.
  ///
  /// In en, this message translates to:
  /// **'Choose periods'**
  String get customPeriods;

  /// No description provided for @freeTime.
  ///
  /// In en, this message translates to:
  /// **'Free time'**
  String get freeTime;

  /// No description provided for @viewAllFreePeriods.
  ///
  /// In en, this message translates to:
  /// **'View all free periods for the day'**
  String get viewAllFreePeriods;

  /// No description provided for @chooseOneOrMoreSections.
  ///
  /// In en, this message translates to:
  /// **'Choose one or more consecutive periods'**
  String get chooseOneOrMoreSections;

  /// No description provided for @chooseFreePeriod.
  ///
  /// In en, this message translates to:
  /// **'Choose free periods'**
  String get chooseFreePeriod;

  /// No description provided for @periodSelectionHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the start period, then the end period. Choose one period to apply immediately.'**
  String get periodSelectionHint;

  /// No description provided for @freeThroughoutSections.
  ///
  /// In en, this message translates to:
  /// **'Free throughout {period}'**
  String freeThroughoutSections(String period);

  /// No description provided for @sectionShort.
  ///
  /// In en, this message translates to:
  /// **'Period {section}'**
  String sectionShort(int section);

  /// No description provided for @periodAndSection.
  ///
  /// In en, this message translates to:
  /// **'{time} ({section})'**
  String periodAndSection(String time, String section);

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @mapInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Map help'**
  String get mapInfoTitle;

  /// No description provided for @mapInfoBody.
  ///
  /// In en, this message translates to:
  /// **'Tap a building to zoom in, then tap a room to see its location. Use two fingers, the mouse wheel, or the zoom buttons to change scale.\n\nOn floor plans, east is up and north is left; the original aspect ratio is preserved. Floor plans 1–10 and the location index are stored locally and require no sign-in. Unindexed room numbers locate the building only.\n\nThe base maps come from a public archive of the school\'s Wencui map. Door and passage availability may differ on site.'**
  String get mapInfoBody;

  /// No description provided for @mapSource.
  ///
  /// In en, this message translates to:
  /// **'Map source'**
  String get mapSource;

  /// No description provided for @school3dNavigation.
  ///
  /// In en, this message translates to:
  /// **'School 3D map'**
  String get school3dNavigation;

  /// No description provided for @openMapSourceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the map source'**
  String get openMapSourceFailed;

  /// No description provided for @openSchoolNavigationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the school map'**
  String get openSchoolNavigationFailed;

  /// No description provided for @myWencuiCourses.
  ///
  /// In en, this message translates to:
  /// **'My Wencui courses'**
  String get myWencuiCourses;

  /// No description provided for @viewBuildingBounds.
  ///
  /// In en, this message translates to:
  /// **'View building bounds'**
  String get viewBuildingBounds;

  /// No description provided for @wencuiCourseSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Room number, course name, stairs, or lift'**
  String get wencuiCourseSearchHint;

  /// No description provided for @wencuiSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Room number or course name, e.g. F704'**
  String get wencuiSearchHint;

  /// No description provided for @noMapResults.
  ///
  /// In en, this message translates to:
  /// **'No result. Try F704, J1006, or a course name from the schedule.'**
  String get noMapResults;

  /// No description provided for @upperFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor above'**
  String get upperFloor;

  /// No description provided for @lowerFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor below'**
  String get lowerFloor;

  /// No description provided for @currentFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor {floor}'**
  String currentFloor(int floor);

  /// No description provided for @selectFloorSemantics.
  ///
  /// In en, this message translates to:
  /// **'Select floor; currently floor {floor}'**
  String selectFloorSemantics(int floor);

  /// No description provided for @tapBuildingOrSearch.
  ///
  /// In en, this message translates to:
  /// **'Tap a building to zoom in, or search for a room'**
  String get tapBuildingOrSearch;

  /// No description provided for @wencuiRoomDetails.
  ///
  /// In en, this message translates to:
  /// **'Wencui Building {wing} · {floor}'**
  String wencuiRoomDetails(String wing, String floor);

  /// No description provided for @viewingFloor.
  ///
  /// In en, this message translates to:
  /// **'{details}, viewing floor {floor}'**
  String viewingFloor(String details, int floor);

  /// No description provided for @clearDestination.
  ///
  /// In en, this message translates to:
  /// **'Clear destination'**
  String get clearDestination;

  /// No description provided for @roomNotMarked.
  ///
  /// In en, this message translates to:
  /// **'{room} is not marked on this floor plan. Showing the {wing} bounds.'**
  String roomNotMarked(String room, String wing);

  /// No description provided for @selectedFeature.
  ///
  /// In en, this message translates to:
  /// **'Selected: {title}'**
  String selectedFeature(String title);

  /// No description provided for @stairs.
  ///
  /// In en, this message translates to:
  /// **'Stairs'**
  String get stairs;

  /// No description provided for @lift.
  ///
  /// In en, this message translates to:
  /// **'Lift'**
  String get lift;

  /// No description provided for @restroom.
  ///
  /// In en, this message translates to:
  /// **'Restroom'**
  String get restroom;

  /// No description provided for @firstFloorEntrance.
  ///
  /// In en, this message translates to:
  /// **'Ground-floor entrance'**
  String get firstFloorEntrance;

  /// No description provided for @backToBuilding.
  ///
  /// In en, this message translates to:
  /// **'Back to building'**
  String get backToBuilding;

  /// No description provided for @backToRoom.
  ///
  /// In en, this message translates to:
  /// **'Back to room'**
  String get backToRoom;

  /// No description provided for @mapLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the map. Reopen it; details can be exported from Logs in Settings.'**
  String get mapLoadFailed;

  /// No description provided for @mapLegend.
  ///
  /// In en, this message translates to:
  /// **'East ↑ · North ←'**
  String get mapLegend;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @fitFloor.
  ///
  /// In en, this message translates to:
  /// **'Fit floor'**
  String get fitFloor;

  /// No description provided for @returnToSelection.
  ///
  /// In en, this message translates to:
  /// **'Return to selection'**
  String get returnToSelection;

  /// No description provided for @enlargeWing.
  ///
  /// In en, this message translates to:
  /// **'Enlarge Wencui Building {wing}'**
  String enlargeWing(String wing);

  /// No description provided for @featureSemantics.
  ///
  /// In en, this message translates to:
  /// **'{title}, floor {floor}'**
  String featureSemantics(String title, int floor);

  /// No description provided for @floorPlanSemantics.
  ///
  /// In en, this message translates to:
  /// **'Wencui Building floor {floor} plan, east up, north left'**
  String floorPlanSemantics(int floor);

  /// No description provided for @wencuiLocation.
  ///
  /// In en, this message translates to:
  /// **'Wencui Building {room}'**
  String wencuiLocation(String room);

  /// No description provided for @wencuiWingFloor.
  ///
  /// In en, this message translates to:
  /// **'{wing} · Floor {floor}'**
  String wencuiWingFloor(String wing, int floor);

  /// No description provided for @wencuiWing.
  ///
  /// In en, this message translates to:
  /// **'Wing {wing}'**
  String wencuiWing(String wing);

  /// No description provided for @wencuiFeatureLocation.
  ///
  /// In en, this message translates to:
  /// **'{place} · {feature}'**
  String wencuiFeatureLocation(String place, String feature);

  /// No description provided for @wencuiWingFloorRange.
  ///
  /// In en, this message translates to:
  /// **'{wing} · Floors {first}–{last}'**
  String wencuiWingFloorRange(String wing, int first, int last);

  /// No description provided for @viewClassroomLocation.
  ///
  /// In en, this message translates to:
  /// **'View classroom location'**
  String get viewClassroomLocation;

  /// No description provided for @latestVersion.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version'**
  String get latestVersion;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates. Check your connection and try again.'**
  String get updateCheckFailed;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailable;

  /// No description provided for @developmentBuild.
  ///
  /// In en, this message translates to:
  /// **'Beta'**
  String get developmentBuild;

  /// No description provided for @stableBuild.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get stableBuild;

  /// No description provided for @unableOpenDownload.
  ///
  /// In en, this message translates to:
  /// **'Could not open the download link'**
  String get unableOpenDownload;

  /// No description provided for @unableOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link'**
  String get unableOpenLink;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @releasePage.
  ///
  /// In en, this message translates to:
  /// **'Release page'**
  String get releasePage;

  /// No description provided for @unableOpenReleasePage.
  ///
  /// In en, this message translates to:
  /// **'Could not open the release page'**
  String get unableOpenReleasePage;

  /// No description provided for @downloadDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Download beta'**
  String get downloadDevelopment;

  /// No description provided for @downloadStable.
  ///
  /// In en, this message translates to:
  /// **'Download stable'**
  String get downloadStable;

  /// No description provided for @releaseNotesUnchanged.
  ///
  /// In en, this message translates to:
  /// **'This build has no new code changes. See the release page for full notes.'**
  String get releaseNotesUnchanged;

  /// No description provided for @releaseNotesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Release notes are temporarily unavailable. See the release page.'**
  String get releaseNotesUnavailable;

  /// No description provided for @releaseMoreChanges.
  ///
  /// In en, this message translates to:
  /// **'Plus {count} more changes. [View full changes]({url}).'**
  String releaseMoreChanges(int count, String url);

  /// No description provided for @releaseVersion.
  ///
  /// In en, this message translates to:
  /// **'{channel} {version}'**
  String releaseVersion(String channel, String version);
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
