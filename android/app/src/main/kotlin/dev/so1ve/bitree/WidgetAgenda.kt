package dev.so1ve.bitree

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.floor

private val sectionTimes = listOf(
    480 to 525, 530 to 575, 595 to 640, 645 to 690, 695 to 740,
    800 to 845, 850 to 895, 915 to 960, 965 to 1010, 1015 to 1060,
    1110 to 1155, 1160 to 1205, 1210 to 1255,
)
private val weekdays = listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")
private val campusZone = TimeZone.getTimeZone("Asia/Shanghai")
private const val MILLIS_PER_DAY = 86400000L

internal enum class WidgetEntryKind(val label: String) {
    COURSE("课程"), EXAM("考试"), DEADLINE("DDL"), EVENT("活动"),
}

internal data class WidgetEntry(
    val title: String,
    val kind: WidgetEntryKind,
    val location: String,
    val startsAt: Long,
    val endsAt: Long,
    val allDay: Boolean = false,
    val campus: String = "",
) {
    val titleLabel: String
        get() = if (kind == WidgetEntryKind.COURSE) title else "${kind.label} $title"

    val startTimeLabel: String
        get() = when {
            allDay -> "全天"
            kind == WidgetEntryKind.DEADLINE -> "${clockTime(startsAt)} 截止"
            dayStart(startsAt).timeInMillis != dayStart(endsAt).timeInMillis ->
                dateFormatter("M/d HH:mm").format(Date(startsAt))
            else -> clockTime(startsAt)
        }

    val timeLabel: String
        get() = when {
            allDay || kind == WidgetEntryKind.DEADLINE -> startTimeLabel
            dayStart(startsAt).timeInMillis != dayStart(endsAt).timeInMillis ->
                "$startTimeLabel–${dateFormatter("M/d HH:mm").format(Date(endsAt))}"
            else -> "${clockTime(startsAt)}–${clockTime(endsAt)}"
        }

    fun occursOn(date: Calendar): Boolean {
        val start = date.timeInMillis
        val end = start + MILLIS_PER_DAY
        return if (kind == WidgetEntryKind.DEADLINE) {
            startsAt >= start && startsAt < end
        } else {
            startsAt < end && endsAt > start
        }
    }
}

internal data class WidgetContent(
    val heading: String,
    val entries: List<WidgetEntry>,
    val emptyMessage: String,
    val nextUpdate: Long,
)

internal fun readWidgetContent(
    context: Context,
    nowMillis: Long = System.currentTimeMillis(),
): WidgetContent {
    val now = Calendar.getInstance(campusZone).apply { timeInMillis = nowMillis }
    val today = dayStart(now.timeInMillis)
    val tomorrow = (today.clone() as Calendar).apply { add(Calendar.DATE, 1) }
    val evening = (today.clone() as Calendar).apply { set(Calendar.HOUR_OF_DAY, 21) }
    var nextUpdate = tomorrow.timeInMillis
    if (evening.after(now)) nextUpdate = evening.timeInMillis
    val todayHeading = "今天${weekdays[weekday(today) - 1]}"

    try {
        val data = readWidgetData(context)
        val entries = readWidgetEntries(
            data.optJSONObject("schedule"), data.getJSONArray("entries"), listOf(today, tomorrow),
        )
        fun entriesOn(date: Calendar) = entries.filter { it.occursOn(date) }
            .sortedWith(compareBy({ !it.allDay }, { it.startsAt }, { it.kind }, { it.title }))

        val todayEntries = entriesOn(today)
        val minute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val remaining = todayEntries.filter { it.endsAt > now.timeInMillis }
        for (entry in remaining) {
            if (entry.endsAt < nextUpdate) nextUpdate = entry.endsAt
        }
        val showTomorrow = minute >= 21 * 60 && remaining.isEmpty()
        val displayed = if (showTomorrow) entriesOn(tomorrow) else remaining
        val emptyMessage = when {
            showTomorrow -> R.string.widget_tomorrow_empty
            todayEntries.isEmpty() -> R.string.widget_today_empty
            else -> R.string.widget_finished
        }
        return WidgetContent(
            if (showTomorrow) "明天${weekdays[weekday(tomorrow) - 1]}" else todayHeading,
            displayed,
            context.getString(emptyMessage),
            nextUpdate,
        )
    } catch (error: Exception) {
        Log.w("BITree", "无法读取桌面组件的本地日程", error)
        return WidgetContent(
            todayHeading, emptyList(), context.getString(R.string.widget_read_error),
            nextUpdate,
        )
    }
}

private fun readWidgetData(context: Context): JSONObject {
    val file = File(context.filesDir, "widget.json")
    if (file.exists()) return JSONObject(file.readText())

    val scheduleFile = File(context.filesDir, "schedule.json")
    val agendaFile = File(context.filesDir, "agenda.json")
    val library = if (scheduleFile.exists()) JSONObject(scheduleFile.readText()) else null
    val schedule = if (library == null || library.isNull("selectedTerm")) null else
        library.getJSONObject("semesters").getJSONObject(library.getString("selectedTerm"))
    val agenda = if (agendaFile.exists())
        JSONObject(agendaFile.readText()).getJSONArray("entries") else JSONArray()
    return JSONObject().put("schedule", schedule ?: JSONObject.NULL).put("entries", agenda)
}

internal fun readWidgetEntries(
    schedule: JSONObject?,
    agenda: JSONArray,
    dates: List<Calendar>,
): List<WidgetEntry> = readCourseEntries(schedule, dates) + readAgendaEntries(agenda)

private fun readCourseEntries(
    schedule: JSONObject?,
    dates: List<Calendar>,
): List<WidgetEntry> {
    if (schedule == null) return emptyList()
    val firstMonday = dateFormatter("yyyy-MM-dd").parse(schedule.getString("firstMonday"))!!
    val rows = schedule.getJSONArray("courses")
    val courses = (0 until rows.length()).map { rows.getJSONObject(it) }

    return dates.flatMap { date ->
        val offset = floor(
            (date.timeInMillis - firstMonday.time).toDouble() / (7 * MILLIS_PER_DAY),
        ).toInt()
        val week = if (offset >= 0) offset + 1 else offset
        courses.filter { course ->
            val weeks = course.getJSONArray("weeks")
            !course.isNull("startSection") &&
                !course.isNull("endSection") &&
                course.optInt("weekday") == weekday(date) &&
                (0 until weeks.length()).any { weeks.getInt(it) == week }
        }.map { course ->
            val startMinute = sectionTimes[course.getInt("startSection") - 1].first
            val endMinute = sectionTimes[course.getInt("endSection") - 1].second
            WidgetEntry(
                title = course.getString("name"),
                kind = WidgetEntryKind.COURSE,
                location = course.getString("room"),
                campus = course.getString("campus"),
                startsAt = date.timeInMillis + startMinute * 60000L,
                endsAt = date.timeInMillis + endMinute * 60000L,
            )
        }
    }
}

private fun readAgendaEntries(rows: JSONArray): List<WidgetEntry> {
    val formatter = dateFormatter("yyyy-MM-dd'T'HH:mm:ss")
    // Dart stores Beijing wall-clock fields with a UTC suffix; do not shift them by eight hours.
    fun timestamp(value: String) = formatter.parse(value.substring(0, 19))!!.time

    return (0 until rows.length()).map { rows.getJSONObject(it) }
        .filter { !it.getBoolean("done") && !it.optBoolean("deleted") }
        .map { row ->
            val kind = WidgetEntryKind.valueOf(row.getString("kind").uppercase(Locale.ROOT))
            val start = timestamp(row.getString("startsAt"))
            val allDay = row.getBoolean("allDay")
            val end = when {
                kind != WidgetEntryKind.DEADLINE -> timestamp(row.getString("endsAt"))
                allDay -> dayStart(start).apply { add(Calendar.DATE, 1) }.timeInMillis
                else -> start
            }
            WidgetEntry(
                title = row.getString("title"),
                kind = kind,
                location = row.getString("location"),
                startsAt = start,
                endsAt = end,
                allDay = allDay,
            )
        }
}

private fun weekday(date: Calendar): Int = (date.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1

private fun dayStart(timestamp: Long) = Calendar.getInstance(campusZone).apply {
    timeInMillis = timestamp
    set(Calendar.HOUR_OF_DAY, 0)
    set(Calendar.MINUTE, 0)
    set(Calendar.SECOND, 0)
    set(Calendar.MILLISECOND, 0)
}

private fun dateFormatter(pattern: String) = SimpleDateFormat(pattern, Locale.ROOT).apply {
    timeZone = campusZone
    isLenient = false
}

private fun clockTime(timestamp: Long): String = dateFormatter("HH:mm").format(Date(timestamp))
