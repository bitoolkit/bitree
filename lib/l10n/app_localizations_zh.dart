// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'BITree';

  @override
  String get appChineseName => '理枝';

  @override
  String get navHome => '首页';

  @override
  String get navAgenda => '日程';

  @override
  String get navTools => '工具';

  @override
  String get navSettings => '设置';

  @override
  String get followSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get appearance => '外观';

  @override
  String get projectDescription => '面向冰红茶的妙妙小工具';

  @override
  String get aboutIconSemantics => 'BITree 图标';

  @override
  String get aboutLicenseSummary => '由 BIToolkit 制作 ♥️，以 Unlicense 发布。';

  @override
  String get developerModeEnabled => '已开启开发者模式';

  @override
  String get widgetUsesSystemPalette => '小组件使用系统调色板';

  @override
  String get globalSystemPaletteExperimental => '全局系统调色板（实验性）';

  @override
  String get importPalette => '导入调色板';

  @override
  String get paletteImported => '已导入并应用配色。';

  @override
  String get defaultPalette => '默认';

  @override
  String get lightModePalette => '浅色模式调色板';

  @override
  String get darkModePalette => '深色模式调色板';

  @override
  String deletePalette(String name) {
    return '删除 $name';
  }

  @override
  String get github => 'GitHub';

  @override
  String get aboutOpenQQGroup => '加入 BITree 交流群';

  @override
  String get language => '语言';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get save => '保存';

  @override
  String get saving => '保存中…';

  @override
  String get delete => '删除';

  @override
  String get remove => '移除';

  @override
  String get restore => '恢复';

  @override
  String get refresh => '刷新';

  @override
  String get reload => '重新读取';

  @override
  String get confirm => '确定';

  @override
  String get operationSaveFailed => '未能保存更改，请重试。';

  @override
  String get operationDeleteFailed => '未能删除，请重试。';

  @override
  String get operationRestoreFailed => '未能恢复，请重试。';

  @override
  String get view => '查看';

  @override
  String get showAll => '显示全部';

  @override
  String get edit => '编辑';

  @override
  String get undo => '撤销';

  @override
  String get add => '添加';

  @override
  String get all => '全部';

  @override
  String get more => '更多';

  @override
  String get today => '今天';

  @override
  String get tomorrow => '明天';

  @override
  String get yesterday => '昨天';

  @override
  String get course => '课程';

  @override
  String get schedule => '课表';

  @override
  String get agenda => '日程';

  @override
  String get exam => '考试';

  @override
  String get deadline => 'DDL';

  @override
  String get activity => '活动';

  @override
  String itemCount(int count) {
    return '$count 项';
  }

  @override
  String weekNumber(int week) {
    return '第 $week 周';
  }

  @override
  String weekNumberCompact(int week) {
    return '第$week周';
  }

  @override
  String get thisWeekSuffix => '，本周';

  @override
  String get schoolWeek => '课表';

  @override
  String get chooseWeek => '选择周次';

  @override
  String weekRangeShort(int first, int last) {
    return '$first - $last 周';
  }

  @override
  String weekList(String ranges) {
    return '$ranges 周';
  }

  @override
  String get weeksPending => '周次待定';

  @override
  String get listSeparator => '、';

  @override
  String get weekdayMonday => '周一';

  @override
  String get weekdayTuesday => '周二';

  @override
  String get weekdayWednesday => '周三';

  @override
  String get weekdayThursday => '周四';

  @override
  String get weekdayFriday => '周五';

  @override
  String get weekdaySaturday => '周六';

  @override
  String get weekdaySunday => '周日';

  @override
  String get weekdayShortMonday => '周一';

  @override
  String get weekdayShortTuesday => '周二';

  @override
  String get weekdayShortWednesday => '周三';

  @override
  String get weekdayShortThursday => '周四';

  @override
  String get weekdayShortFriday => '周五';

  @override
  String get weekdayShortSaturday => '周六';

  @override
  String get weekdayShortSunday => '周日';

  @override
  String get weekdayNarrowMonday => '一';

  @override
  String get weekdayNarrowTuesday => '二';

  @override
  String get weekdayNarrowWednesday => '三';

  @override
  String get weekdayNarrowThursday => '四';

  @override
  String get weekdayNarrowFriday => '五';

  @override
  String get weekdayNarrowSaturday => '六';

  @override
  String get weekdayNarrowSunday => '日';

  @override
  String get monthNames => '1月,2月,3月,4月,5月,6月,7月,8月,9月,10月,11月,12月';

  @override
  String monthDay(String month, int day) {
    return '$month$day日';
  }

  @override
  String yearMonthDay(String month, int day, int year) {
    return '$year年$month$day日';
  }

  @override
  String dateWithWeekday(String weekday, String date) {
    return '$date $weekday';
  }

  @override
  String relativeDateWithWeekday(String relative, String weekday, String date) {
    return '$relative $date $weekday';
  }

  @override
  String termFall(String years) {
    return '$years 秋季学期';
  }

  @override
  String termSpring(String years) {
    return '$years 春季学期';
  }

  @override
  String get sectionPending => '节次待定';

  @override
  String sectionSingle(int section) {
    return '第 $section 节';
  }

  @override
  String sectionRange(int start, int end) {
    return '第 $start–$end 节';
  }

  @override
  String sectionRangeCompact(int start, int end) {
    return '第$start–$end节';
  }

  @override
  String get timePending => '时间待定';

  @override
  String get locationPending => '教室待定';

  @override
  String get allDay => '全天';

  @override
  String get allDayUntil => '全天截止';

  @override
  String dueAt(String time) {
    return '$time 截止';
  }

  @override
  String endsAt(String time) {
    return '$time 结束';
  }

  @override
  String get completed => '已完成';

  @override
  String get overdue => '已逾期';

  @override
  String get ended => '已结束';

  @override
  String get inProgress => '进行中';

  @override
  String get due => '截止';

  @override
  String get start => '开始';

  @override
  String get end => '结束';

  @override
  String get settingsDeleteScheduleQuestion => '删除本地课表？';

  @override
  String get settingsDeleteScheduleBody => '删除所有学期的课表，包括手动添加的课程。此操作无法撤销。';

  @override
  String get settingsDeleteSchedule => '删除课表';

  @override
  String get settingsTerm => '学期';

  @override
  String get settingsWeekManagement => '周数管理';

  @override
  String get settingsDeleteLocalSchedule => '删除本地课表';

  @override
  String get settingsDeleteDeadlines => '删除 DDL';

  @override
  String settingsDeleteDeadlinesBody(int count) {
    return '全部学期共 $count 条，含已完成和已删除';
  }

  @override
  String get settingsLocalSchedule => '本地课表';

  @override
  String get settingsLocalAgenda => '本地日程';

  @override
  String get settingsApplication => '应用';

  @override
  String get settingsExportLogs => '导出日志';

  @override
  String get settingsCheckUpdates => '检查更新';

  @override
  String get settingsCheckingUpdates => '正在检查更新…';

  @override
  String get settingsAbout => '关于 BITree';

  @override
  String settingsBuiltAt(String date, String time) {
    return '构建于 $date $time';
  }

  @override
  String get settingsLicenses => '查看许可';

  @override
  String get aboutOpenGitHubFailed => '无法打开 GitHub';

  @override
  String get aboutOpenQQGroupFailed => '无法打开 BITree 交流群';

  @override
  String get aboutLicenseName => 'BITree 理枝';

  @override
  String get homeTitle => '首页';

  @override
  String get backToThisWeek => '回到本周';

  @override
  String get timedCourses => '时间待定的课程';

  @override
  String get addCourse => '添加课程';

  @override
  String get chooseCourse => '选择课程';

  @override
  String coursesOverlap(int count, String summary) {
    return '$count门课程时间重叠，$summary，选择课程';
  }

  @override
  String courseOverlapCount(int count) {
    return '$count门';
  }

  @override
  String courseOngoingUntil(String time) {
    return '上课中 · $time 下课';
  }

  @override
  String minutesUntilEnd(int count) {
    return '还有 $count 分钟下课';
  }

  @override
  String get courseNext => '下一门课';

  @override
  String get sameBuilding => '同一栋楼';

  @override
  String get sameArea => '同一片区换楼';

  @override
  String get differentArea => '跨片区换楼';

  @override
  String get copyCourseNameSuccess => '已复制课程名称';

  @override
  String get copyCourseNameFailure => '复制失败，请重试';

  @override
  String get deleteCourseQuestion => '删除这门课程？';

  @override
  String deleteCourseBody(String course) {
    return '从本地课表删除“$course”。';
  }

  @override
  String get deleteCourse => '删除课程';

  @override
  String courseDetailsSemantics(
    String name,
    String time,
    String room,
    String progress,
  ) {
    return '$name，$time，$room$progress，查看详情';
  }

  @override
  String get courseIsToday => '，今天';

  @override
  String get courseIsOngoing => '，上课中';

  @override
  String get courseEditorAddTitle => '添加课程';

  @override
  String get courseEditorEditTitle => '编辑课程';

  @override
  String get courseEditorSave => '保存课程';

  @override
  String get courseEditorTerm => '学期';

  @override
  String get courseEditorTermRequired => '请输入学期';

  @override
  String courseEditorMondayLabel(String date) {
    return '第一周周一：$date';
  }

  @override
  String get courseEditorName => '课程名称';

  @override
  String get courseEditorNameRequired => '请输入课程名称';

  @override
  String get courseEditorRoom => '教室（选填）';

  @override
  String get courseEditorTeacher => '教师（选填）';

  @override
  String get courseEditorWeekday => '星期';

  @override
  String get courseEditorWeeksRequired => '至少选择一个上课周次';

  @override
  String get courseEditorWeeks => '上课周次';

  @override
  String get courseEditorPeriodStart => '开始节次';

  @override
  String get courseEditorPeriodEnd => '结束节次';

  @override
  String coursePeriodRange(
    int section,
    String linebreak,
    String start,
    String end,
  ) {
    return '第 $section 节$linebreak（$start–$end）';
  }

  @override
  String get weekSelectionSummer => '小学期';

  @override
  String get weekSelectionRegular => '非小学期';

  @override
  String get weekManagement => '周数管理';

  @override
  String get weekIntegerRequired => '请输入整数周次';

  @override
  String get weekZeroInvalid => '没有第 0 周';

  @override
  String get decreaseWeek => '减少一周';

  @override
  String get increaseWeek => '增加一周';

  @override
  String get weekOrderInvalid => '截止周不能早于开始周';

  @override
  String get weekStart => '开始周';

  @override
  String get weekEnd => '截止周';

  @override
  String get weekRangeDialogTitle => '周数管理';

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
    return '$date$weekday$today$agenda';
  }

  @override
  String get timetableTodaySuffix => '，今天';

  @override
  String timetableAgendaSuffix(int count) {
    return '，$count项日程';
  }

  @override
  String sectionSemantics(int section, String start, String end) {
    return '第 $section 节，$start–$end';
  }

  @override
  String get exportSchedule => '导出课表';

  @override
  String get exportScheduleEmpty => '没有可导出的课程';

  @override
  String get exportScheduleSuccess => '已导出课表';

  @override
  String get exportScheduleFailed => '导出课表失败，请重试。';

  @override
  String exportScheduleSkipped(int count) {
    return '已导出课表，跳过 $count 门时间待定的课程';
  }

  @override
  String get desktopAgendaWidget => '桌面日程表';

  @override
  String get exportIcs => '导出 ICS';

  @override
  String icsCalendarName(String term) {
    return 'BITree $term';
  }

  @override
  String icsEventDescription(String week, String section) {
    return '$week $section';
  }

  @override
  String icsTeacher(String teacher) {
    return '教师：$teacher';
  }

  @override
  String icsCourseNumber(String number) {
    return '课程号：$number';
  }

  @override
  String get agendaTitle => '日程';

  @override
  String get agendaReload => '重新加载日程';

  @override
  String agendaPendingTab(int count) {
    return '未完成 $count';
  }

  @override
  String agendaCompletedTab(int count) {
    return '已完成 $count';
  }

  @override
  String get agendaSwitchToList => '切换到列表';

  @override
  String get agendaSwitchToTimeline => '切换到时间轴';

  @override
  String agendaOverdueHiddenLabel(int count) {
    return '$count项逾期日程';
  }

  @override
  String get agendaNoCompleted => '还没有已完成的日程';

  @override
  String get agendaNoUpcoming => '没有即将到来的日程';

  @override
  String get agendaNoPending => '没有未完成的日程';

  @override
  String get agendaType => '日程类型';

  @override
  String get agendaPeriod => '日程时段';

  @override
  String agendaCount(int count) {
    return '$count项日程';
  }

  @override
  String get agendaNoPendingShort => '没有未完成的日程';

  @override
  String agendaCompletedCount(int count) {
    return '已完成 $count';
  }

  @override
  String get agendaDayEmpty => '这一天没有安排';

  @override
  String get agendaChooseItems => '选择安排';

  @override
  String agendaItemCount(int count) {
    return '$count 项';
  }

  @override
  String get agendaMarkDone => '标记完成';

  @override
  String get agendaMarkUndone => '标为未完成';

  @override
  String get agendaNotes => '备注';

  @override
  String get agendaOpenLink => '打开作业';

  @override
  String get agendaDueBeforeEndOfDay => '当天结束前';

  @override
  String get agendaSwipeDelete => '删除';

  @override
  String get agendaSwipeDeleteRelease => '松手删除';

  @override
  String get agendaSwipeRestore => '未完成';

  @override
  String get agendaSwipeRestoreRelease => '松手恢复';

  @override
  String get agendaSwipeDone => '完成';

  @override
  String get agendaSwipeDoneRelease => '松手完成';

  @override
  String agendaDeleteQuestion(String kind) {
    return '删除$kind？';
  }

  @override
  String agendaRestored(String title) {
    return '已恢复“$title”';
  }

  @override
  String agendaDeleted(String title) {
    return '已删除“$title”';
  }

  @override
  String agendaAddTitle(String kind) {
    return '添加$kind';
  }

  @override
  String get addAgenda => '添加日程';

  @override
  String get addDeadline => '添加 DDL';

  @override
  String agendaEditTitle(String kind) {
    return '编辑$kind';
  }

  @override
  String get agendaName => '名称';

  @override
  String get agendaNameRequired => '请输入名称';

  @override
  String get agendaAllDay => '全天';

  @override
  String get agendaLocationOptional => '地点（选填）';

  @override
  String get agendaNotesOptional => '备注（选填）';

  @override
  String get agendaEndAfterStart => '结束时间需要晚于开始时间';

  @override
  String agendaReminderOverdue(String time) {
    return '$time 已逾期';
  }

  @override
  String agendaReminderStarts(String time) {
    return '$time 开始';
  }

  @override
  String agendaReminderCount(int count) {
    return '$count项待办';
  }

  @override
  String get agendaReminderCollapse => '收起待办提醒';

  @override
  String get agendaTimelineOneDay => '1 天 / 格';

  @override
  String get agendaTimelineOneHour => '1 小时 / 格';

  @override
  String agendaTimelineHours(String hours) {
    return '$hours 小时 / 格';
  }

  @override
  String get agendaTimelineZoom => '时间轴缩放';

  @override
  String get agendaTimelineEmpty => '暂无日程';

  @override
  String agendaTimelineStarts(String time) {
    return '开始：$time';
  }

  @override
  String agendaTimelineEnds(String time) {
    return '结束：$time';
  }

  @override
  String agendaTimelineDue(String time) {
    return '截止：$time';
  }

  @override
  String agendaTimelineCourse(String course) {
    return '课程：$course';
  }

  @override
  String agendaTimelineLocation(String location) {
    return '地点：$location';
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
    return '$kind，$title，$time$course$location$status';
  }

  @override
  String get agendaTimelineStatusCompleted => '状态：已完成';

  @override
  String get agendaTimelineStatusOverdue => '状态：已逾期';

  @override
  String get agendaTimelineStatusEnded => '状态：已结束';

  @override
  String get clearDeadlinesTitle => '删除 DDL';

  @override
  String clearDeadlinesSourceCount(String source, int count) {
    return '$source（$count 条）';
  }

  @override
  String clearDeadlinesSelection(int categories, int count) {
    return '已选 $categories 类，共 $count 条';
  }

  @override
  String get clearDeadlinesWarning => '删除后不会进入“已删除的 DDL”；平台和大物实验 DDL 可重新生成。';

  @override
  String clearDeadlinesDeleteCount(int count) {
    return '删除 $count 条 DDL';
  }

  @override
  String get clearDeadlinesDeleting => '正在删除…';

  @override
  String get clearDeadlinesUnavailable => '日程未加载或正在保存，请稍后重试';

  @override
  String clearDeadlinesDeleted(int count) {
    return '已删除 $count 条 DDL';
  }

  @override
  String get deletedDeadlinesTitle => '已删除的 DDL';

  @override
  String get deletedDeadlinesRecycleBin => 'DDL 回收站';

  @override
  String get deletedDeadlinesSearchHint => '搜索标题、课程或来源';

  @override
  String get deletedDeadlinesNoMatches => '没有匹配的 DDL';

  @override
  String deletedDeadlinesSelectionCount(int selected, int total) {
    return '已选 $selected / $total';
  }

  @override
  String get deletedDeadlinesNone => '没有已删除的 DDL';

  @override
  String get deletedDeadlinesRestoreAll => '全部恢复';

  @override
  String get deletedDeadlinesRestoreAction => '恢复';

  @override
  String get deletedDeadlinesRestoreSelected => '恢复所选';

  @override
  String deletedDeadlinesRestored(String title) {
    return '已恢复“$title”';
  }

  @override
  String get deletedDeadlinesRestoredAll => '已恢复全部 DDL';

  @override
  String deletedDeadlinesRestoredCount(int count) {
    return '已恢复 $count 条 DDL';
  }

  @override
  String get deletedDeadlinesEmptyAction => '清空回收站';

  @override
  String get deletedDeadlinesEmptyTitle => '清空回收站？';

  @override
  String deletedDeadlinesEmptyConfirm(int count) {
    return '将永久删除 $count 条 DDL，无法恢复。';
  }

  @override
  String get deletedDeadlinesDeleteForever => '永久删除';

  @override
  String deletedDeadlinesEmptied(int count) {
    return '已清空 $count 条 DDL';
  }

  @override
  String get deadlineManual => '手动添加';

  @override
  String get deadlineManualScope => '手动创建的 DDL';

  @override
  String get deadlinePhysicsLab => '大物实验 DDL';

  @override
  String get deadlineLexue => '乐学 DDL';

  @override
  String get deadlineEclass => '新延河课堂 DDL';

  @override
  String get deadlineMooc => '中国大学MOOC DDL';

  @override
  String get deadlineSourceLexue => '乐学';

  @override
  String get deadlineSourceEclass => '新延河课堂';

  @override
  String get deadlineSourceMooc => '中国大学MOOC';

  @override
  String get agendaKindEvent => '活动';

  @override
  String get agendaKindDeadline => 'DDL';

  @override
  String get agendaKindExam => '考试';

  @override
  String examSeat(String seat) {
    return '座位号：$seat';
  }

  @override
  String examTeacher(String teacher) {
    return '教师：$teacher';
  }

  @override
  String timeRange(String start, String end) {
    return '$start–$end';
  }

  @override
  String get syncAll => '同步全部';

  @override
  String get customSync => '自定义同步';

  @override
  String get syncTerm => '同步学期';

  @override
  String get syncSchoolData => '学校数据';

  @override
  String get syncDeadlineData => 'DDL 来源';

  @override
  String get syncTooltip => '同步';

  @override
  String get viewSyncProgress => '查看同步进度';

  @override
  String get syncComplete => '同步完成';

  @override
  String get syncPartial => '部分内容未同步';

  @override
  String selectedItems(int count) {
    return '已选 $count 项';
  }

  @override
  String get selectAll => '全选';

  @override
  String get clearSelection => '清空';

  @override
  String get loginAfterSelection => '未登录，选择后登录';

  @override
  String get syncSelected => '同步所选内容';

  @override
  String get syncProgress => '同步进度';

  @override
  String get collapse => '收起';

  @override
  String syncProcessed(int done, int total) {
    return '已处理 $done / $total 项';
  }

  @override
  String get syncCancelled => '同步已取消';

  @override
  String get continueAfterCollapse => '收起后继续同步';

  @override
  String get cancelSync => '取消同步';

  @override
  String get cancelling => '正在取消…';

  @override
  String get verifying => '正在验证…';

  @override
  String get retryIncomplete => '重试未完成的内容';

  @override
  String get syncTargetSchedule => '课表';

  @override
  String get syncTargetExams => '考试安排';

  @override
  String get syncTargetGrades => '成绩';

  @override
  String get syncTargetStudyPlan => '学分进度';

  @override
  String get syncTargetLexue => '乐学 DDL';

  @override
  String get syncTargetEclass => '新延河课堂 DDL';

  @override
  String get syncTargetMooc => '中国大学MOOC DDL';

  @override
  String get syncTargetPhysicsLab => '大物实验 DDL';

  @override
  String get syncActionSchedule => '同步课表';

  @override
  String get syncActionExams => '同步考试安排';

  @override
  String get syncActionGrades => '同步成绩';

  @override
  String get syncActionStudyPlan => '同步学分进度';

  @override
  String get syncActionLexue => '同步乐学 DDL';

  @override
  String get syncActionEclass => '同步新延河课堂 DDL';

  @override
  String get syncActionMooc => '同步中国大学MOOC DDL';

  @override
  String get syncActionPhysicsLab => '更新大物实验 DDL';

  @override
  String get syncing => '正在同步…';

  @override
  String get waitingForSchool => '等待学校请求完成';

  @override
  String get waitingToSync => '等待同步';

  @override
  String get cancelled => '已取消';

  @override
  String get synced => '已同步';

  @override
  String get syncNotFinished => '同步未完成，请重试';

  @override
  String get noScheduleAvailable => '暂无可用课表';

  @override
  String get physicsLabSaveFailed => '未能保存大物实验 DDL';

  @override
  String physicsLabPreviewReport(String course) {
    return '预习报告 $course';
  }

  @override
  String physicsLabReport(String course) {
    return '实验报告 $course';
  }

  @override
  String physicsLabGeneratedNotes(String term, String date, String time) {
    return '由$term课表生成\n上课：$date $time';
  }

  @override
  String updatedDdlCount(int count) {
    return '已更新 $count 条 DDL';
  }

  @override
  String get syncResultSaveFailed => '未能保存同步结果';

  @override
  String syncedDdlCount(int count) {
    return '已同步 $count 条 DDL';
  }

  @override
  String get syncFailed => '同步失败，请重试';

  @override
  String get schoolLoginRequired => '需要登录学校账号';

  @override
  String get syncVerificationRequired => '需要完成学校登录验证';

  @override
  String get accountUnverified => '未连接';

  @override
  String get accountSignedIn => '已登录';

  @override
  String get accountSignedOut => '未登录';

  @override
  String get accountExpired => '需要重新登录';

  @override
  String get accountSmsRequired => '需要短信验证';

  @override
  String get accountImageRequired => '需要图形验证';

  @override
  String get moocName => '中国大学MOOC';

  @override
  String get moocSignOutQuestion => '退出中国大学MOOC？';

  @override
  String get moocSignOutBody => '退出后保留已导入的 DDL。';

  @override
  String get exitAction => '退出';

  @override
  String get webLogin => '网页登录';

  @override
  String get relogin => '重新登录';

  @override
  String get moocLoginMethods => '手机号、邮箱、验证码或扫码';

  @override
  String get useCookie => '使用 Cookie';

  @override
  String get backupLogin => '备用登录方式';

  @override
  String get moocSignOutAccount => '退出账号';

  @override
  String get moocConnectionCancelled => '已取消连接';

  @override
  String get moocConnecting => '连接中…';

  @override
  String get connect => '连接';

  @override
  String get moocCookieInstructions => '从已登录网页的开发者工具中复制 Cookie。仅在网页登录不可用时使用。';

  @override
  String get moocPasteCookie => '请粘贴 Cookie';

  @override
  String get openMoocFailed => '无法打开 MOOC';

  @override
  String get openOfficialLogin => '打开官方登录页';

  @override
  String get moocLoginTitle => '登录中国大学MOOC';

  @override
  String get refreshLoginPage => '刷新登录页';

  @override
  String get completeLogin => '完成登录';

  @override
  String get moocLoginPageLoadFailed => '登录页加载失败，请检查网络后刷新。';

  @override
  String get moocLoginPageOpenFailed => '无法打开登录页，请重试。';

  @override
  String get moocOpenAppFailed => '无法打开对应应用，请选择页面中的其他登录方式。';

  @override
  String get moocCompleteLoginFirst => '请先在页面中完成登录。';

  @override
  String get moocAccountReadFailed => '无法读取 MOOC 账号信息，请刷新登录页。';

  @override
  String get moocSessionNotReady => '登录会话尚未就绪，请稍后重试。';

  @override
  String get moocSavingLogin => '正在保存登录…';

  @override
  String get moocLoginStateReadFailed => '无法读取登录状态，请刷新或点击“完成登录”重试。';

  @override
  String get moocConnected => '已连接';

  @override
  String get moocNeedsLogin => '需要重新登录';

  @override
  String get moocSignedOut => '未登录';

  @override
  String get moocLoginRequired => '需要登录中国大学MOOC账号';

  @override
  String get moocReadingCourses => '正在读取 MOOC 课程…';

  @override
  String get moocReadingSpocCourses => '正在读取 SPOC 课程…';

  @override
  String moocReadingCourse(int done, int total, String course) {
    return '正在读取 $done/$total：《$course》';
  }

  @override
  String get moocNoSession => '没有读取到中国大学MOOC 会话，请先完成登录。';

  @override
  String get moocLoginExpired => '中国大学MOOC 登录已失效，请重新登录。';

  @override
  String get moocRequestBusy => 'MOOC 正在处理请求，请稍后重试。';

  @override
  String get moocReadAccountFailed => '无法读取 MOOC 登录信息，请重新登录。';

  @override
  String get moocSaveResultFailed => '未能保存同步结果，请稍后重试。';

  @override
  String get moocCourseTypeMooc => 'MOOC';

  @override
  String get moocCourseTypeSpoc => 'SPOC';

  @override
  String get moocTaskHomework => '作业';

  @override
  String get moocTaskQuiz => '测验';

  @override
  String get moocTaskExam => '考试';

  @override
  String get moocTaskPeerReview => '互评';

  @override
  String moocPeerReviewTitle(String title) {
    return '互评：$title';
  }

  @override
  String moocOpenedAt(String time) {
    return '开放：$time';
  }

  @override
  String moocStartedAt(String time) {
    return '开始：$time';
  }

  @override
  String moocSubmissionDueAt(String time) {
    return '提交截止：$time';
  }

  @override
  String get schoolLogin => '登录学校账号';

  @override
  String get schoolStudentId => '学号';

  @override
  String get schoolEnterStudentId => '请输入学号';

  @override
  String get schoolPassword => '密码';

  @override
  String get schoolEnterPassword => '请输入密码';

  @override
  String get schoolShowPassword => '显示密码';

  @override
  String get schoolHidePassword => '隐藏密码';

  @override
  String get schoolLoggingIn => '登录中…';

  @override
  String get schoolSignOutQuestion => '退出学校账号？';

  @override
  String get schoolSignOutBody => '退出后保留本地课表和日程。';

  @override
  String get schoolSignOutAction => '退出登录';

  @override
  String get verifyAction => '验证';

  @override
  String get schoolVerified => '学校账号验证完成';

  @override
  String get schoolSmsVerification => '短信验证';

  @override
  String get schoolImageVerification => '图形验证';

  @override
  String schoolSentToPhone(String phone) {
    return '发送至 $phone';
  }

  @override
  String get schoolVerificationCode => '验证码';

  @override
  String get schoolEnterVerificationCode => '请输入验证码';

  @override
  String get schoolRefreshImage => '换一张';

  @override
  String schoolResendIn(int seconds) {
    return '$seconds 秒后重发';
  }

  @override
  String get schoolResend => '重新发送';

  @override
  String get schoolVerifying => '验证中…';

  @override
  String get toolsTitle => '工具';

  @override
  String get academicTools => '学业与规划';

  @override
  String get campusTools => '校园查询';

  @override
  String get gradesAndAcademics => '成绩与学业';

  @override
  String get gradeSimulation => '成绩试算';

  @override
  String get creditProgress => '毕业学分进度';

  @override
  String get examScheduleTool => '考试安排与冲突检查';

  @override
  String get emptyClassroomQuery => '空教室查询';

  @override
  String get wencuiMap => '文萃导航';

  @override
  String get logsTitle => '日志';

  @override
  String get logsRecent => '最近 100 行，本地保留七天';

  @override
  String get exportingLogs => '导出中…';

  @override
  String get exportLogs => '导出日志';

  @override
  String get reloadLogs => '重新读取日志';

  @override
  String get logsReadFailed => '日志读取失败，请重试。';

  @override
  String get logsExportFailed => '日志导出失败，请重试。';

  @override
  String get noLogs => '暂无日志';

  @override
  String get logsExported => '已导出日志';

  @override
  String get widgetGuideTitle => '桌面日程表';

  @override
  String get widgetSingleColumn => '2×2 单列';

  @override
  String get widgetDoubleColumn => '2×4 双列';

  @override
  String get widgetStepOpen => '长按桌面空白处，打开“小组件”。';

  @override
  String get widgetStepFind => '找到 BITree 日程表，选择单列或双列样式，拖到桌面。';

  @override
  String get widgetStepScroll => '上下滑动，查看课程、考试、DDL 和活动。';

  @override
  String get widgetGuideTomorrow => '当天安排结束后，21:00 起显示明天的日程。';

  @override
  String get gotIt => '知道了';

  @override
  String openInBrowser(String url) {
    return '请在浏览器中打开：\n$url';
  }

  @override
  String get takeBack => '收回';

  @override
  String viewHidden(String label) {
    return '查看$label';
  }

  @override
  String releaseToView(String label) {
    return '松开查看$label';
  }

  @override
  String pullToView(String label) {
    return '下拉查看$label';
  }

  @override
  String get gpaRules => '绩点计算规则';

  @override
  String get gpaRulesTitle => '绩点计算规则';

  @override
  String get gpaRuleIntro => '采用北京理工大学本科生绩点计算方法（试行）。';

  @override
  String get gpaRulePercent =>
      '百分制：60 分及以上按 4 − 3 × (100 − 成绩)² ÷ 1600 计算，课程绩点四舍五入至一位小数；60 分以下为 0。';

  @override
  String get gpaRuleFive => '五级制：优秀 4.0，良好 3.6，中等 2.8，及格 1.7，不及格 0。';

  @override
  String get gpaRuleWeighting =>
      '按学分加权。同一课程取最高成绩；校公选课的不及格成绩不计入绩点。合格制课程只统计学分，加权平均分仅统计百分制成绩。';

  @override
  String get gpaRuleScoreScope => '80 分及以上统计以百分制课程数为分母，不包含五级制和合格制课程。';

  @override
  String get openGpaRulesFailed => '无法打开计分规则';

  @override
  String get schoolSource => '学校原文';

  @override
  String syncedAt(String date, String time) {
    return '同步于 $date $time';
  }

  @override
  String get failedCourse => '未通过';

  @override
  String get noSyncedGrades => '还没有同步成绩';

  @override
  String get allSemesters => '全部学期';

  @override
  String get averageGpa => '平均绩点';

  @override
  String get weightedAverageScore => '加权平均分';

  @override
  String get earnedCredits => '获得学分';

  @override
  String get gradeScope => '统计范围';

  @override
  String get gradeScopeFiltered => '统计范围（已筛选）';

  @override
  String get scoredCourses => '计分课程';

  @override
  String get coursesAtLeast80 => '80 分及以上';

  @override
  String get atLeast80Ratio => '80 分及以上占比';

  @override
  String courseCount(int count) {
    return '$count 门';
  }

  @override
  String get allCourses => '全部课程';

  @override
  String get searchCourses => '搜索课程';

  @override
  String get noCoursesInScope => '当前范围暂无课程';

  @override
  String get noMatchingCourses => '没有匹配的课程';

  @override
  String get courseGrades => '课程成绩';

  @override
  String get termPerformance => '学期表现';

  @override
  String get onlyFailedCourses => '只显示未通过课程';

  @override
  String coursesNotPassed(int count) {
    return '$count 门课程尚未通过';
  }

  @override
  String termCoursesNotPassed(int count) {
    return '这个学期有 $count 门课程未通过';
  }

  @override
  String get noGradesThisTerm => '当前范围暂无成绩';

  @override
  String weightedAverageValue(String value) {
    return '加权平均 $value 分';
  }

  @override
  String get creditProgressTitle => '毕业学分进度';

  @override
  String get reviewCreditTargets => '核对学分目标';

  @override
  String get academicReadFailed => '学业数据暂时无法读取';

  @override
  String get noCreditRecords => '还没有学分记录';

  @override
  String get creditsFromGrades => '成绩中已获学分';

  @override
  String get completedCreditsSchool => '学校记录已修学分';

  @override
  String get schoolRequiredCredits => '学校要求学分';

  @override
  String get reviewTargetCredits => '核对目标学分';

  @override
  String get creditsRemaining => '尚缺学分';

  @override
  String get notAvailable => '未获取';

  @override
  String requiredCoursesPending(int count) {
    return '$count 门必修课待通过';
  }

  @override
  String get pendingRequiredCourses => '待通过的必修课';

  @override
  String get reviewByCategory => '按课程类别核对';

  @override
  String get setTargets => '设置目标';

  @override
  String get syncGradesForCredit => '同步成绩，查看分类学分';

  @override
  String get creditCategoryNote => '分类学分按已同步成绩计算，每门课只计一次。不统计在修学分，最终以学校审核为准。';

  @override
  String get noCategoryGrades => '这个类别还没有课程成绩';

  @override
  String credits(String count) {
    return '$count 学分';
  }

  @override
  String creditProgressValue(String earned, String target) {
    return '$earned / $target';
  }

  @override
  String get creditTargetNotSet => '尚未设置分类要求';

  @override
  String creditsStillNeeded(String count) {
    return '还需 $count 学分';
  }

  @override
  String get totalCreditTarget => '总学分目标';

  @override
  String get leaveBlankSchoolRequirement => '留空使用学校要求';

  @override
  String categoryCreditTarget(String category) {
    return '$category要求学分';
  }

  @override
  String get leaveBlankCancelTarget => '留空取消这个分类的目标';

  @override
  String get addCourseCategory => '添加课程类别';

  @override
  String get addCategory => '添加类别';

  @override
  String get enterNonNegativeCredits => '请输入非负学分';

  @override
  String get examScheduleAndConflicts => '考试安排与冲突检查';

  @override
  String get checkLocalSchedule => '同时检查本地课表';

  @override
  String get syncScheduleConflictHint => '同步课表后可检查冲突。';

  @override
  String timeConflictsFound(int count) {
    return '发现 $count 处时间冲突';
  }

  @override
  String get noUpcomingExams => '没有即将到来的考试';

  @override
  String get noExams => '暂无考试安排';

  @override
  String get hideFinishedExams => '隐藏已结束考试';

  @override
  String get showFinishedExams => '查看已结束考试';

  @override
  String get examAgendaSharedNote => '考试与日程共用记录，修改或删除会同时生效。';

  @override
  String overlapsClass(String title) {
    return '与$title上课时间重叠';
  }

  @override
  String overlapsExam(String title) {
    return '与$title考试时间重叠';
  }

  @override
  String get timeConflict => '时间冲突';

  @override
  String get noTimeConflict => '没有时间冲突';

  @override
  String overlapMinutes(String date, int minutes) {
    return '$date  重叠 $minutes 分钟';
  }

  @override
  String get courseGradeTitle => '课程成绩';

  @override
  String get courseNumber => '课程编号';

  @override
  String get courseCredits => '课程学分';

  @override
  String get courseAttribute => '课程属性';

  @override
  String get courseCategory => '课程类别';

  @override
  String get examType => '考试性质';

  @override
  String get courseGpa => '课程绩点';

  @override
  String get notCounted => '不计入';

  @override
  String get creditReviewCategory => '学分核对分类';

  @override
  String get simulateRetake => '试算重修成绩';

  @override
  String get removeSimulatedCourseQuestion => '移除试算课程？';

  @override
  String get removeAction => '移除';

  @override
  String currentGpaCredits(String credits, String gpa) {
    return '当前计绩学分 $credits，平均绩点 $gpa';
  }

  @override
  String get simulateByCourse => '按课程试算';

  @override
  String get targetBackCalculation => '目标倒推';

  @override
  String get targetCumulativeGpa => '目标累计绩点';

  @override
  String get enterGpaRange => '请输入 0～4 之间的绩点';

  @override
  String get requiredPerCourse => '每门试算课程至少需要达到';

  @override
  String get projectedCumulativeGpa => '预计累计绩点';

  @override
  String get addSimulatedCourseFirst => '先添加试算课程';

  @override
  String get targetUnreachable => '满分也无法达到目标';

  @override
  String scoreValue(String score) {
    return '$score 分';
  }

  @override
  String gpaChange(String value) {
    return '累计绩点变化 $value';
  }

  @override
  String get simulatedCourses => '试算课程';

  @override
  String get retake => '重修';

  @override
  String get editAction => '修改';

  @override
  String get removeSimulatedCourse => '移除试算课程';

  @override
  String get retakeUsesHighest => '重修取最高成绩';

  @override
  String get simulationDoesNotChange => '试算不会修改成绩。';

  @override
  String get simulationIncludesBoth => '试算同时计入原成绩和重修成绩，与学校取最高分规则不同。';

  @override
  String get addProjectedCourse => '添加试算课程';

  @override
  String get editProjectedCourse => '修改试算课程';

  @override
  String get selectCourseOptional => '选择课程（选填）';

  @override
  String get manualEntry => '手动填写';

  @override
  String retakeSuffix(String name) {
    return '$name（重修）';
  }

  @override
  String get courseName => '课程名称';

  @override
  String get enterCourseName => '请输入课程名称';

  @override
  String get enterPositiveCredits => '请输入大于 0 的学分';

  @override
  String get expectedScore => '预计成绩';

  @override
  String get enterScoreRange => '请输入 0～100 之间的成绩';

  @override
  String get loadBuildings => '加载教学楼';

  @override
  String get noQueryableCampuses => '暂无可查询的校区';

  @override
  String get reloadAction => '重新加载';

  @override
  String get campus => '校区';

  @override
  String get date => '日期';

  @override
  String todayDate(String date) {
    return '今天 $date';
  }

  @override
  String tomorrowDate(String date) {
    return '明天 $date';
  }

  @override
  String get otherDate => '其他日期';

  @override
  String get building => '教学楼';

  @override
  String get allBuildings => '全部教学楼';

  @override
  String get wencuiBuildingAll => '文萃楼（全部）';

  @override
  String get classroomFreeTime => '教室空闲时间';

  @override
  String get roomsMatchingPeriod => '符合时段的教室';

  @override
  String get querying => '查询中…';

  @override
  String roomCount(int count) {
    return '$count间';
  }

  @override
  String get showsFreePeriods => '显示各教室当天的空闲时段';

  @override
  String freeThroughoutPeriod(String period) {
    return '$period内全程空闲';
  }

  @override
  String get loginToQuery => '登录后可查询空教室';

  @override
  String get queryIncomplete => '查询未完成';

  @override
  String get queryAgain => '重新查询';

  @override
  String get noBuildingInfo => '这个校区还没有教学楼信息';

  @override
  String get noFreeClassrooms => '这段时间没有空教室';

  @override
  String get noFreePeriods => '当天没有空闲时段';

  @override
  String get reloadBuildings => '重新加载教学楼';

  @override
  String get viewAnyPeriod => '不限时段查看';

  @override
  String get viewAllBuildings => '查看全部教学楼';

  @override
  String get changeDate => '换个日期';

  @override
  String get freeMeansNoClass => '空闲表示该时段没有排课';

  @override
  String get busyStatus => '有课';

  @override
  String get freeStatus => '空闲';

  @override
  String get allPeriods => '不限时段';

  @override
  String get currentPeriod => '当前这节';

  @override
  String get morning => '上午';

  @override
  String get afternoon => '下午';

  @override
  String get evening => '晚上';

  @override
  String get customPeriods => '自选课次';

  @override
  String get freeTime => '空闲时段';

  @override
  String get viewAllFreePeriods => '查看当天所有空闲时段';

  @override
  String get chooseOneOrMoreSections => '选择一节或连续几节';

  @override
  String get chooseFreePeriod => '选择空闲时段';

  @override
  String get periodSelectionHint => '选择开始和结束节次；单节可直接应用。';

  @override
  String freeThroughoutSections(String period) {
    return '$period内全程空闲';
  }

  @override
  String sectionShort(int section) {
    return '第$section节';
  }

  @override
  String periodAndSection(String time, String section) {
    return '$time（$section）';
  }

  @override
  String get apply => '应用';

  @override
  String get mapInfoTitle => '地图说明';

  @override
  String get mapInfoBody =>
      '点楼栋放大，点教室查看位置。可双指、滚轮或按钮缩放。\n\n平面图上东、左北。教室号未收录时只显示楼栋。\n\n底图来自学校文萃导航，现场通道以实际情况为准。';

  @override
  String get mapSource => '地图来源';

  @override
  String get school3dNavigation => '学校3D导航';

  @override
  String get openMapSourceFailed => '无法打开地图来源';

  @override
  String get openSchoolNavigationFailed => '无法打开学校导航';

  @override
  String get myWencuiCourses => '我的文萃课程';

  @override
  String get viewBuildingBounds => '查看楼栋范围';

  @override
  String get wencuiCourseSearchHint => '教室号、课程名、楼梯或电梯';

  @override
  String get wencuiSearchHint => '教室号或课程名，如 F704';

  @override
  String get noMapResults => '没有找到。试试 F704、J1006，或课表里的课程名。';

  @override
  String get upperFloor => '上一层';

  @override
  String get lowerFloor => '下一层';

  @override
  String currentFloor(int floor) {
    return '$floor层';
  }

  @override
  String selectFloorSemantics(int floor) {
    return '选择楼层，当前$floor层';
  }

  @override
  String get tapBuildingOrSearch => '点楼栋放大，或搜索教室号';

  @override
  String viewingFloor(String details, int floor) {
    return '$details，正在查看$floor层';
  }

  @override
  String get clearDestination => '清除目的地';

  @override
  String roomNotMarked(String room, String wing) {
    return '图中未找到$room的标注，已显示$wing范围。';
  }

  @override
  String selectedFeature(String title) {
    return '已选：$title';
  }

  @override
  String get stairs => '楼梯';

  @override
  String get lift => '电梯';

  @override
  String get restroom => '卫生间';

  @override
  String get maleRestroom => '男卫生间';

  @override
  String get femaleRestroom => '女卫生间';

  @override
  String get firstFloorEntrance => '一层入口';

  @override
  String get backToBuilding => '回到楼栋';

  @override
  String get backToRoom => '回到教室';

  @override
  String get mapLoadFailed => '地图加载失败，请重试。可在设置中导出日志。';

  @override
  String get mapLegend => '上东 · 左北';

  @override
  String get zoomOut => '缩小地图';

  @override
  String get zoomIn => '放大地图';

  @override
  String get fitFloor => '查看整层';

  @override
  String get returnToSelection => '回到选中位置';

  @override
  String enlargeWing(String wing) {
    return '放大文萃楼$wing';
  }

  @override
  String featureSemantics(String title, int floor) {
    return '$title，$floor层';
  }

  @override
  String floorPlanSemantics(int floor) {
    return '文萃楼$floor层平面图，上东、左北';
  }

  @override
  String wencuiLocation(String room) {
    return '文萃楼 $room';
  }

  @override
  String wencuiWingFloor(String wing, int floor) {
    return '$wing · $floor层';
  }

  @override
  String wencuiWing(String wing) {
    return '$wing栋';
  }

  @override
  String wencuiFeatureLocation(String place, String feature) {
    return '$place $feature';
  }

  @override
  String wencuiWingFloorRange(String wing, int first, int last) {
    return '$wing · $first–$last层';
  }

  @override
  String get viewClassroomLocation => '查看教室位置';

  @override
  String get latestVersion => '已是最新版本';

  @override
  String get updateCheckFailed => '检查更新失败，请检查网络后重试。';

  @override
  String get updateAvailable => '发现可用更新';

  @override
  String get developmentBuild => '测试版';

  @override
  String get stableBuild => '正式版';

  @override
  String get unableOpenDownload => '无法打开下载链接';

  @override
  String get unableOpenLink => '无法打开链接';

  @override
  String get later => '稍后';

  @override
  String get releasePage => '发布页';

  @override
  String get unableOpenReleasePage => '无法打开发布页';

  @override
  String get downloadDevelopment => '下载测试版';

  @override
  String get downloadStable => '下载正式版';

  @override
  String get releaseNotesUnchanged => '此版本没有代码变更。';

  @override
  String get releaseNotesUnavailable => '暂时无法读取更新说明。';

  @override
  String releaseMoreChanges(int count, String url) {
    return '另有 $count 项变更，[查看完整变更]($url)。';
  }

  @override
  String get timetableHeight => '课表高度';

  @override
  String get timetableHeightNormal => '正常高度';

  @override
  String get timetableHeightFit => '适应屏幕';

  @override
  String get timetableHeightHint => '适应屏幕可一屏总览全部节次；正常高度保留舒适行高和纵向滚动。';

  @override
  String releaseVersion(String channel, String version) {
    return '$channel $version';
  }
}
